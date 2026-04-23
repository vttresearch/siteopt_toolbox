using DataFrames, CSV, XLSX, Dates
using ArgParse
using Sines_additional

# script for creating hp units
#
# Try from command line with
# julia --project=@. conv_hp_units.jl testinputs/hp-input.xlsx 

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: hp units input table"
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
    add_hp_units(parsed_args["arg1"], parsed_args["arg3"], model_length)
end


"""
    add_hp_units(hp_file, url_in, model_length::Period)

    Overall function for adding hp units. Loads the HP and chiller units to DB.
"""
function add_hp_units(hp_file, url_in, model_length::Period)

    #read basic info
    c0 = DataFrame(XLSX.readtable(hp_file, "Sheet1") )

    # add source grid if not present
    if !hasproperty(c0, :sourcegrid)
        insertcols!(c0, :sourcegrid => missing)
    end

    # fetch timeseries values
    c0 = load_table_timeser_values(c0, dirname(hp_file), col = [:cop_profile])

    # create unit and node names
    c0 = transform(c0, [:type, :block_identifier] => 
        #ByRow((a,b) -> ifelse(a=="cool", "u_" * string(b) * "_chiller","u_"*string(b)*"_hp")) => :unit )
        ByRow((a,b) -> "u_" * string(b) * "_" * string(a) * "unit") => :unit )
    # input node is electrical    
    c0 = transform(c0, [:block_identifier] => ByRow(x-> "n_" * string(x) * "_elec") => :inputnode )
    c0 = transform(c0, [:type, :block_identifier] => 
        ByRow((a,b) -> "n_" * string(b) * "_" * string(a)) => :basenode )
    c0 = transform(c0, [:sourcegrid, :block_identifier] => 
        ByRow(passmissing((a,b) -> "n_" * string(b) * "_" * string(a)) ) => :sourcenode )    
    # emission node name
        c0 = transform(c0, [:emissionnode] => ByRow(x -> ismissing(x) ?  missing : "n_" * string(x) ) 
        => :emissionnode )
    # default groups
    c0 = transform(c0, :type => ByRow(a -> ifelse(a=="cool","chillers","heat_pumps")) => :group )

    # adjust investment costs 
    c0.unit_investment_cost .=  c0.unit_investment_cost * (model_length / Hour(8760) )
     
    # add input ratio for source node
    c0 = transform(c0, :cop_profile => ByRow(passmissing(x -> x / (x-1))) => :source_ratio)
    println(c0)
    # add min share of online units for emissions to work
    addedparams = Dict(:min_units_on_share => 1.0, :emission_flow_capacity => 1.0)
    c0 = augment_basetable(c0, addedparams)

    # object parameters 
    import_objects(url_in, add_unit(c0))
    import_object_param(url_in, 
        add_unit_param2(c0, [:unit_investment_cost, :candidate_units, :min_units_on_share, :group]))

    # unit-node relationship parameters
    import_relations_2dim(url_in,  
        vcat(add_unit_to_node(c0, "unit__to_node", :basenode),
            add_unit_to_node(c0, "unit__from_node", :inputnode),
            add_unit_to_node(c0, "unit__from_node", :sourcenode),
            add_unit_to_node(c0, "unit__to_node", :emissionnode)
        )
    )
    import_rel_param_2dim(url_in, add_unit_node_param(c0, [:unit_capacity], directory = dirname(hp_file) ) )

    #emissions
    c0 = augment_basetable(c0, Dict(:emission_type => "co2"))
    import_rel_param_2dim(url_in, add_unit_node_param_emission(c0, Dict(:investment_emission => :minimum_operating_point,
                                                :emission_cost => :vom_cost,
                                                :emission_type => :group,
                                                :emission_flow_capacity => :unit_capacity))
                        )

    #unit-node-node relationships for electrical input
    import_relations_3dim(url_in, add_unit_node_node(c0, :basenode, :inputnode))
    import_rel_param_3dim(url_in, 
                        add_unit_node_node_param(rename(c0, :cop_profile => :fix_ratio_out_in_unit_flow), 
                        :inputnode, [:fix_ratio_out_in_unit_flow], directory = dirname(hp_file))
                        )
    #unit-node-node relationships for source
    import_relations_3dim(url_in, add_unit_node_node(c0, :basenode, :sourcenode))
    import_rel_param_3dim(url_in, 
                        add_unit_node_node_param(rename(c0, :source_ratio => :fix_ratio_out_in_unit_flow), 
                        :sourcenode, [:fix_ratio_out_in_unit_flow], directory = dirname(hp_file))
                        )
end

main()

