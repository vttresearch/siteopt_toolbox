using DataFrames, CSV, XLSX, Dates
using ArgParse
using Sines_additional

# script for creating diverting units
#
# Try from command line with
# julia --project=@. conv_divert_units_dir.jl diverting_units.xlsx modespec.xlsx sqlite:///inputdb.sqlite


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


# the unit-node relationships 
function add_unit_to_node_divunits(c0)
    vcat(add_unit_to_node(c0, "unit__to_node", :outputnode),
        add_unit_to_node(c0, "unit__to_node", :inputnode),
        add_unit_to_node(c0, "unit__to_node", :divertingnode),
        add_unit_to_node(c0, "unit__from_node", :outputnode),
        add_unit_to_node(c0, "unit__from_node", :inputnode)
    )
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
    add_diverting_units(filename, url_in, model_length::Period)

    Overall function for adding diverting units, i.e. units which create a sidestream flow
    which is proportional to the main flow passing through the unit. Reverse flow is allowed but
    does not create a sidestream.
    
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
    import_relations_2dim(url_in,  add_unit_to_node_divunits(c0))
    import_relations_3dim(url_in, c1)

    c2  =  add_object_object_param(c0, :unit, :divertingnode, [:vom_cost],
        directory = dirname(filename))
    insertcols!(c2, 1, :relationshipclass => "unit__to_node")
    insertcols!(c2, 2, :Objectclass1 => "unit")
    insertcols!(c2, 3, :Objectclass2 => "node")

    import_rel_param_2dim(url_in, c2)
    import_rel_param_3dim(url_in, add_unit_node_node_param_divunits(c0))
end

main()

