using DataFrames, CSV, XLSX
using ArgParse

include("common.jl")

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: storages input table"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    add_storages(parsed_args["arg1"])
end

# just the yunit
function add_unit(c0)
    c1 = select(c0, :unit)
    insertcols!(c1, 1, :Objectclass1 => "unit")
    return c1
end

# just the storage node
function add_stornode(c0)
    c1 = select(c0, :stornode => :node)
    insertcols!(c1, 1, :Objectclass1 => "node")
    return c1
end

# the unit-node relationships
function add_unit_to_node(c0)

    c1  = select(c0, :unit)
    c11 = copy(c1)
    c1.node = c0.stornode
    c11.node = c0.basenode 
    c1 = vcat(c1,c11)

    insertcols!(c1, 1, :relationshipclass => "unit__to_node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")

    c2 =  select(c0, :unit)
    c21 = copy(c2)
    c2.node = c0.basenode
    c21.node = c0.stornode
    c2 = vcat(c2,c21)

    insertcols!(c2, 1, :relationshipclass => "unit__from_node")
    insertcols!(c2, 2, :Objectclass1 => "unit")
    insertcols!(c2, 3, :Objectclass2 => "node")

    vcat(c1,c2)
end

# the unit-node relationship parameters
function add_unit_node_param(c0)

    c01 = subset(c0, :max_charging => ByRow(!ismissing))
    c1 = select(c01, :unit)
    c1.node = c01.stornode
    
    insertcols!(c1, 1, :relationshipclass => "unit__to_node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")
    insertcols!(c1, 6, :parameter_name => "unit_capacity")
    insertcols!(c1, 7, :alternative_name => "Base")
    insertcols!(c1, 8, :parameter_value => c01[:, :max_charging])

    c2 = copy(c1)
    c2.node = c01.basenode

    vcat(c1,c2)
end

# the unit-node-node relationships
function add_unit_node_node(c0)

    c1 = select(c0, :unit)
    c1.node1 = c0.stornode
    c1.node2 = c0.basenode

    insertcols!(c1, 1, :relationshipclass => "unit__node__node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")
    insertcols!(c1, 4, :Objectclass3 => "node")

    c2 = select(c0, :unit)
    c2.node1 = c0.basenode
    c2.node2 = c0.stornode

    insertcols!(c2, 1, :relationshipclass => "unit__node__node")
    insertcols!(c2, 2, :Objectclass1 => "unit")
    insertcols!(c2, 3, :Objectclass2 => "node")
    insertcols!(c2, 4, :Objectclass3 => "node")

    vcat(c1,c2)
end

function add_unit_node_node_param(c0)

    c1 = add_unit_node_node(c0)
    insertcols!(c1, 8, :parameter_name => "fix_ratio_out_in_unit_flow")
    insertcols!(c1, 9, :alternative_name => "Base")
    insertcols!(c1, 10, :parameter_value => 0.95)

    return c1
end

"""
The function adds object parameter table for storage nodes
"""
function add_storage_node_param(c0)

    c1 = select(c0, :stornode => :object)
    insertcols!(c1, 1, :objectclass => "node")
    insertcols!(c1, 3, :parameter_name => "has_state")
    insertcols!(c1, 4, :alternative_name => "Base")
    insertcols!(c1, 5, :parameter_value => "true")
    c11 = c1

    # node state cap
    c1 = select(c0, :stornode => :object, :node_state_cap => :parameter_value)
    insertcols!(c1, :objectclass => "node")
    insertcols!(c1, :parameter_name => "node_state_cap")
    insertcols!(c1, :alternative_name => "Base")
    select!(c1, :objectclass, :object, :parameter_name, :alternative_name, :parameter_value)

    vcat(c11,c1)

end

function add_storage_node_param2(c0, paramcols)

    c1 = select(c0, :stornode, paramcols)

     # add candidate storages
     insertcols!(c1, :candidate_storages => missings(Float64, nrow(c1)))
     c1[(!ismissing).(c1.storage_investment_cost), :candidate_storages] .= 40
     
     insertcols!(c1, :has_state => "true")

     c1 = stack(c1, Not(:stornode))
     c1 = subset(c1, :value => ByRow(!ismissing))

    insertcols!(c1, :objectclass => "node")
    rename!(c1, :variable => :parameter_name)
    insertcols!(c1, :alternative_name => "Base")

    c1 = select(c1, :objectclass, :stornode, :parameter_name, :alternative_name, :value)

end

"""
Overall function for adding electrical storages

    Output: excel tables of electrical storage units and electrical storage nodes
"""
function add_storages(stor_file)

    #output file names
    outfile1 = "storage_units.xlsx"
    outfile2 = "storage_nodes.xlsx"
    
    #read basic info
    c0 = DataFrame(XLSX.readtable(stor_file, "Sheet1") )
   
    c0 = transform(c0, [:block_identifier] => ByRow(x->"u_"*string(x)*"_stor") => :unit )
    c0 = transform(c0, [:block_identifier] => ByRow(x->"n_"*string(x)*"_elecstor") => :stornode )
    c0 = transform(c0, [:block_identifier] => ByRow(x->"n_"*string(x)*"_elec") => :basenode )

    c1 =  add_unit_param2(c0, [:unit_investment_cost])

    # units excel file
    XLSX.writetable(outfile1, 
                "unit" => add_unit(c0), 
                "unit_param" => c1,
                "unit__to_node" => add_unit_to_node(c0),
                "unit__node_param" => add_unit_node_param(c0),
                "unit__node__node" => add_unit_node_node(c0), 
                "unit__node__node_parameter" => add_unit_node_node_param(c0),
                overwrite = true
    )

    c1 = add_storage_node_param2(c0, [:node_state_cap, 
                                    :storage_investment_cost,
                                    :storage_investment_variable_type]) 

    # Storage nodes excel file
    XLSX.writetable(outfile2, 
        "object" => add_stornode(c0), 
        "object_parameter" => c1,
        overwrite = true
    )

end

main()