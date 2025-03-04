using DataFrames, CSV, XLSX
using ArgParse


# script for creating hp units
#
# Try from command line with
# julia --project=@. conv_hp_units.jl testinputs/hp-input.xlsx 

include("common.jl")
include("db.jl")

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: diverting units input table"
            required = true
        "arg2"
            help = "a positional argument: model spec input table filename"
            required = true
        "arg3"
            help = "model database url"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    model_length = calc_model_len(parsed_args["arg2"])
    add_diverting_units(parsed_args["arg1"], parsed_args["arg3"], model_length)
end

#=
function add_unit(c0)
    c1 = select(c0, :unit)
    insertcols!(c1, 1, :Objectclass1 => "unit")
    return unique(c1)
end
=#

# the unit-node relationships 
function add_unit_to_node(c0)
    vcat(add_unit_to_node(c0, "unit__to_node", :outputnode),
        add_unit_to_node(c0, "unit__to_node", :inputnode),
        add_unit_to_node(c0, "unit__to_node", :divertingnode),
        add_unit_to_node(c0, "unit__from_node", :outputnode),
        add_unit_to_node(c0, "unit__from_node", :inputnode)
    )
end




function add_unit_node_param(c0, nodecol, paramcols)

    # Check if required columns exist in c0 and select what is present
    requested_cols = vcat(paramcols, [:alternative_name])
    existing_columns = intersect(requested_cols, Symbol.(names(c0)))
    c1 = select(c0, :unit, nodecol, existing_columns)

    # add alternative name if not present
    if !hasproperty(c1, :alternative_name)
        insertcols!(c1, :alternative_name => "Base")
    end

    c1 = stack(c1, Not([:unit, nodecol, :alternative_name]))
    c1 = subset(c1, :value => ByRow(!ismissing))

    rename!(c1, :variable => :parameter_name)

    # final dataframe
    insertcols!(c1, 1, :relationshipclass => "unit__to_node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")
    c1 = select(c1, :relationshipclass, :Objectclass1, :Objectclass2, 
                :unit => :Object1, nodecol => :Object2, :parameter_name, 
                :alternative_name, :value)
    return c1
end


# the unit-node-node relationship parameters
function add_unit_node_node_param_divunits(c0)

    c1 = add_unit_node_node(c0, :outputnode, :inputnode)
    insertcols!(c1, :parameter_name => "fix_ratio_out_in_unit_flow")
    insertcols!(c1, :alternative_name => c0[:, :alternative_name])
    insertcols!(c1, :value => 1.0)

    c2 = add_unit_node_node(c0, :inputnode, :outputnode)
    insertcols!(c2, :parameter_name => "fix_ratio_out_in_unit_flow")
    insertcols!(c2, :alternative_name => c0[:, :alternative_name])
    insertcols!(c2, :value => 1.0)

    c3 = add_unit_node_node(c0, :divertingnode, :inputnode)
    insertcols!(c3, :parameter_name => "fix_ratio_out_in_unit_flow")
    insertcols!(c3, :alternative_name => c0[:, :alternative_name])
    insertcols!(c3, :value => c0[:, :diversionfactor])
    
    return vcat(c1,c2,c3)
end

"""
Overall function for adding 

    Output: excel tables of 
"""
function add_diverting_units(filename, url_in, model_length::Period)

    #output file names
    outfile1 = "diverting_units.xlsx"

    #read basic info
    c0 = DataFrame(XLSX.readtable(filename, "Sheet1") )
   
    # create unit names
    c0 = transform(c0, [:name] => ByRow((b)->"u_"*string(b)*"_div") => :unit )

    # unit-node-node relships
    c1 = vcat(add_unit_node_node(c0, :outputnode, :inputnode),
            add_unit_node_node(c0, :inputnode, :outputnode),
            add_unit_node_node(c0, :divertingnode, :inputnode)
        )

    import_objects(url_in, add_unit(c0))
    import_relations_2dim(url_in,  add_unit_to_node(c0))
    import_relations_3dim(url_in, c1)

    c2  =  add_object_object_param(c0, :unit, :divertingnode, [:vom_cost],
        directory = dirname(filename))
    insertcols!(c2, 1, :relationshipclass => "unit__to_node")
    insertcols!(c2, 2, :Objectclass1 => "unit")
    insertcols!(c2, 3, :Objectclass2 => "node")

    import_rel_param_2dim(url_in, c2       )

    import_rel_param_3dim(url_in, add_unit_node_node_param_divunits(c0))

    #=
    # units excel file
    XLSX.writetable(outfile1, 
                "unit" => add_unit(c0), 
                "unit_param" =>  DataFrame(no_data = []),
                "unit__to_node" => add_unit_to_node(c0),
                "unit__node_param" => add_unit_node_param(c0, :divertingnode, [:vom_cost]),
                "unit__node__node" => c1,
                "unit__node__node_parameter" =>  add_unit_node_node_param_divunits(c0),
                overwrite = true
    )
                =#
end

main()

