using DataFrames, CSV, XLSX
using ArgParse


# script for creating hp units
#
# Try from command line with
# julia --project=@. conv_hp_units.jl testinputs/hp-input.xlsx 

include("common.jl")

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: hp units input table"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    add_hp_units(parsed_args["arg1"])
end

function add_unit(c0)
    c1 = select(c0, :unit)
    insertcols!(c1, 1, :Objectclass1 => "unit")
    return c1
end

# the object parameters
function add_unit_param(c0)

    c01 = subset(c0, :unit_investment_cost => ByRow(!ismissing))
    c1 = select(c01, :unit)
    
    insertcols!(c1, 1, :Objectclass => "unit")
    insertcols!(c1, 3, :parameter_name => "unit_investment_cost")
    insertcols!(c1, 4, :alternative_name => "Base")
    insertcols!(c1, 5, :parameter_value => c01[:, :unit_investment_cost])

    return c1
end

# the unit-node relationships
function add_unit_to_node(c0)

    c1 = select(c0, :unit)
    c1.node = c0.outputnode
 
    insertcols!(c1, 1, :relationshipclass => "unit__to_node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")

    c2 = select(c0, :unit)
    c2.node = c0.inputnode

    insertcols!(c2, 1, :relationshipclass => "unit__from_node")
    insertcols!(c2, 2, :Objectclass1 => "unit")
    insertcols!(c2, 3, :Objectclass2 => "node")

    vcat(c1,c2)
end

# the unit-node relationship parameters
function add_unit_node_param(c0)

    c01 = subset(c0, :capacity => ByRow(!ismissing))
    # add alternative name if not present
    if !hasproperty(c01, :alternative_name)
        insertcols!(c01, :alternative_name => "Base")
    end
    c1 = select(c01, :unit)
    c1.node = c01.outputnode
    
    insertcols!(c1, 1, :relationshipclass => "unit__to_node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")
    insertcols!(c1, 6, :parameter_name => "unit_capacity")
    insertcols!(c1, 7, :alternative_name => c01[:, :alternative_name])
    insertcols!(c1, 8, :parameter_value => c01[:, :capacity])

    return c1
end

# the unit-node-node relationships for output-input relationship
function add_unit_node_node(c0)

    c1 = select(c0, :unit)
    c1.node1 = c0.outputnode
    c1.node2 = c0.inputnode

    insertcols!(c1, 1, :relationshipclass => "unit__node__node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")
    insertcols!(c1, 4, :Objectclass3 => "node")
end

"""
Overall function for adding hp units

    Output: excel tables of hp units
"""
function add_hp_units(hp_file)

    #output file names
    outfile1 = "hp_units.xlsx"

    #read basic info
    c0 = DataFrame(XLSX.readtable(hp_file, "Sheet1") )

    c0 = transform(c0, [:block_identifier] => ByRow(x->"u_"*string(x)*"_hp") => :unit )
    c0 = transform(c0, [:block_identifier] => ByRow(x->"n_"*string(x)*"_elec") => :inputnode )
    c0 = transform(c0, [:block_identifier] => ByRow(x->"n_"*string(x)*"_dheat") => :outputnode )

    c1 =  add_unit_param2(c0, [:unit_investment_cost])

    # units excel file
    XLSX.writetable(outfile1, 
                "unit" => add_unit(c0), 
                "unit_param" => c1,
                "unit__to_node" => add_unit_to_node(c0),
                "unit__node_param" => add_unit_node_param(c0),
                "unit__node__node" => add_unit_node_node(c0),
                "unit__node__node_parameter" =>  DataFrame(no_data = []),
                overwrite = true
    )
end

main()

