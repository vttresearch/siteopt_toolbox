using DataFrames, CSV, XLSX
using ArgParse


# script for creating PV units
#
# Try from command line with
# julia --project=@. conv_pv_units.jl testinputs/pv-input.xlsx 

include("common.jl")
include("db.jl")

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: pv units input table filename"
            required = true
        "arg2"
            help = "a positional argument: model spec input table filename"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    model_length = calc_model_len(parsed_args["arg2"])
    add_pv_units(parsed_args["arg1"], model_length)
end

# just the unit
function add_unit(c0)

    c1 = select(c0, :unit)
    insertcols!(c1, 1, :Objectclass1 => "unit")
    return c1
end

# the object parameters
function add_unit_param_old(c0)

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
    c1.node = c0.basenode
 
    insertcols!(c1, 1, :relationshipclass => "unit__to_node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")

end

# the unit-node relationship parameters
function add_unit_node_param(c0)

    c01 = subset(c0, :capacity => ByRow(!ismissing))
    # add alternative name if not present
    if !hasproperty(c01, :alternative_name)
        insertcols!(c01, :alternative_name => "Base")
    end

    c1 = select(c01, :unit)
    c1.node = c01.basenode

    # unit capacity
    insertcols!(c1, 1, :relationshipclass => "unit__to_node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")
    insertcols!(c1, 6, :parameter_name => "unit_capacity")
    insertcols!(c1, 7, :alternative_name => c01[:, :alternative_name])
    insertcols!(c1, 8, :parameter_value => c01[:, :capacity])

    return c1
end

"""
Overall function for adding pv units

    Output: excel tables of pv units
"""
function add_pv_units(pv_file::String, model_length::Period)

    #output file names
    outfile1 = "pv_units.xlsx"

    #read basic info
    c0 = DataFrame(XLSX.readtable(pv_file, "Sheet1") )

    # unit and node names
    c0 = transform(c0, [:block_identifier, :type] => ByRow((x,y)->"u_"*string(x)*"_"*string(y)) => :unit )
    c0 = transform(c0, [:block_identifier] => ByRow(x->"n_"*string(x)*"_elec") => :basenode )

    # adjust investment costs 
    c0.unit_investment_cost .=  c0.unit_investment_cost * (model_length / Hour(8760) )
     
    c1 = add_unit_param2(c0, [:unit_investment_cost, :candidate_units])

    # units excel file
    XLSX.writetable(outfile1, 
                "unit" => add_unit(c0), 
                "unit_param" => c1,
                "unit__to_node" => add_unit_to_node(c0),
                "unit__node_param" => add_unit_node_param(c0),
                "unit__node__node" => DataFrame(no_data = []),
                "unit__node__node_parameter" =>  DataFrame(no_data = []),
                overwrite = true
    )

end

main()

