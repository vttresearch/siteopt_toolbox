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
        "arg3"
            help = "model database url"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    model_length = calc_model_len(parsed_args["arg2"])
    add_pv_units(parsed_args["arg1"], parsed_args["arg3"], model_length)
end

#=
# just the unit
function add_unit(c0)
    c1 = select(c0, :unit => :Object1)
    insertcols!(c1, 1, :Objectclass1 => "unit")
    return c1
end
=#


# the unit-node relationships
function add_unit_to_node(c0)

    c1 = select(c0, :unit => :Object1)
    c1.Object2 = c0.basenode
    c2 = select(c0, :unit => :Object1)
    c2.Object2 = c0.emissionnode

    c1 = vcat(c1,c2)
    c1 = unique(dropmissing(c1))

    insertcols!(c1, 1, :relationshipclass => "unit__to_node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")

end


"""
Overall function for adding pv units

    Output: excel tables of pv units
"""
function add_pv_units(pv_file::String, url_in, model_length::Period)

    #output file names
    outfile1 = "pv_units.xlsx"

    #read basic info
    c0 = DataFrame(XLSX.readtable(pv_file, "Sheet1") )

    # unit and node names
    c0 = transform(c0, [:block_identifier, :type] => ByRow((x,y)->"u_"*string(x)*"_"*string(y)) => :unit )
    c0 = transform(c0, [:block_identifier] => ByRow(x->"n_"*string(x)*"_elec") => :basenode )
    c0 = transform(c0, [:emissionnode] => ByRow(x -> ismissing(x) ?  missing : "n_" * string(x) ) 
                        => :emissionnode )

    # adjust investment costs 
    c0.unit_investment_cost .=  c0.unit_investment_cost * (model_length / Hour(8760) )
     
      # add min share of online units for emissions to work
    insertcols!(c0, :min_units_on_share => 1.0)

    c1 = add_unit_param2(c0, [:unit_investment_cost, :candidate_units, :min_units_on_share])

    import_objects(url_in, add_unit(c0))
    import_relations_2dim(url_in, add_unit_to_node(c0))
    import_object_param(url_in, c1)
    
    c3 = add_unit_node_param(c0, [:unit_capacity, :vom_cost], directory = dirname(pv_file) )
    import_rel_param_2dim(url_in, c3)
    
    #emissions
    c4 = add_unit_node_param_emission(c0, Dict(:investment_emission => :minimum_operating_point,
                                                :emission_cost => :vom_cost,
                                                :emission_flow_capacity => :unit_capacity))
    
    import_rel_param_2dim(url_in, c4)
    
    #c5 = add_units_on_temporal_block(c0, "myinvestmentblock")
    #import_relations_2dim(url_in, c5)

end

main()

