using DataFrames, CSV, XLSX, Dates
using ArgParse
using Sines_additional

# script for creating PV units
#
# Try from command line with
# julia --project=@. conv_pv_units.jl testinputs/pv-input.xlsx 

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

function add_investment_group(c0, url_in)
    c1 = dropmissing(c0, :investment_group, disallowmissing=true)
    c1 = unique(select(c1, :investment_group => :Object1))
    insertcols!(c1, 1, :Objectclass1 => "investment_group")
    import_objects(url_in, c1) 
end

function add_unit_investment_group(c0, url_in)
    c1 = dropmissing(c0, :investment_group, disallowmissing=true)
    c1[!,:investment_group] = convert.(String, c1[!,:investment_group])
    c1 = unique(select(c1, :unit => :Object1, :investment_group => :Object2))
    insertcols!(c1, 1, :relationshipclass => "unit__investment_group")
    import_relations_2dim(url_in, c1)
end

"""
    add_investment_group_capa(c0, url_in)

    Adds and imports into DB the parameter "maximum_entities_invested_available"
    based on user input.
"""
function add_investment_group_capa(c0, url_in)
    c1 = dropmissing(c0, [:investment_group, :candidate_units], disallowmissing=true)
    c1 = select(c1,:unit, :investment_group, :alternative_name, :candidate_units)
    # sum the capacity for each investment group
    c1 = combine(groupby(c1, [:investment_group, :alternative_name]), :candidate_units => (x -> isempty(x) ? 0.0 : sum(x)) => :value)
    c1 = rename(c1, :investment_group => :Object1)
    insertcols!(c1, 1, :Objectclass1 => "investment_group")
    insertcols!(c1, 3, :parameter_name => "maximum_entities_invested_available")
    import_object_param(url_in, c1)
end

"""
    read_invgroups(c_invgroups, url_in)

    Main function for reading and importing investment group related data

"""
function read_invgroups(c_invgroups, url_in)
    c_invgroups = transform(c_invgroups, [:block_identifier, :name] => ByRow((x,y)->"u_" * string(x) * "_" * string(y)) => :unit )
    c_invgroups = transform(c_invgroups, [:group] => ByRow(x -> "ig_" * string(x) ) => :investment_group )
    c_invgroups.candidate_units = convert.(Union{Missing,Float64}, c_invgroups.candidate_units)
    add_investment_group(c_invgroups, url_in)
    add_unit_investment_group(c_invgroups, url_in)
    add_investment_group_capa(c_invgroups, url_in)
end

"""
Overall function for adding VRE units

    Input:
    pv_file: vre definition file
    url_in: database URL
    model_length: investment horizon length

"""
function add_pv_units(pv_file::String, url_in, model_length::Period)

    #investment group input file resides in the same folder
    invgroupfile = joinpath(dirname(pv_file), "group_potential.xlsx")

    #read given data
    c0 = DataFrame(XLSX.readtable(pv_file, "Sheet1") )
    if isfile(invgroupfile)
        c_invgroups = DataFrame(XLSX.readtable(invgroupfile, "Sheet1") )
    else
        c_invgroups = nothing
    end

    # convert column datatypes
    c0 = transform(c0, [:representative_unit] => ByRow(x -> ismissing(x) ? false : true ) 
                        => :user_representative)

    # unit and node names
    c0 = transform(c0, [:block_identifier, :name] => ByRow((x,y)->"u_"*string(x)*"_"*string(y)) => :unit )
    c0 = transform(c0, [:block_identifier, :grid] 
         => ByRow((x,y) -> "n_" * string(x) * "_" * string(y)) => :basenode )   
    c0 = transform(c0, [:emissionnode] => ByRow(x -> ismissing(x) ?  missing : "n_" * string(x) ) 
                        => :emissionnode )
    insertcols!(c0, :group => "vre_production")


    # adjust investment costs 
    c0.unit_investment_cost .=  c0.unit_investment_cost * (model_length / Hour(8760) )
     
    # add min share of online units for emissions to work
    addedparams = Dict(:min_units_on_share => 1.0, :emission_flow_capacity => 1.0)
    c0 = augment_basetable(c0, addedparams)

    # unit parameters
    c1 = add_unit_param2(c0, [:unit_investment_cost, :candidate_units, :min_units_on_share, :group])

    # start importing data
    mdict = Dict{Symbol, Vector{Any}}()
    import_objects(url_in, add_unit(c0), mdict)
    import_object_param(url_in, c1, mdict)
    
    #unit-to-node relationships
    import_relations_2dim(url_in, 
        vcat(add_unit_to_node(c0, "unit__to_node", :basenode),
            add_unit_to_node(c0, "unit__to_node", :emissionnode)),
        mdict)

    c3 = add_unit_node_param(c0, [:unit_capacity, :vom_cost, :user_representative], directory = dirname(pv_file) )
    import_rel_param_2dim(url_in, c3, mdict)
    
    #emissions
    c4 = add_unit_node_param_emission(c0, Dict(:investment_emission => :minimum_operating_point,
                                                :emission_cost => :vom_cost,
                                                :emission_flow_capacity => :unit_capacity))
    
    import_rel_param_2dim(url_in, c4, mdict)
    
    # send to db
    import_data(url_in, mdict)

    # investment groups
    if !isnothing(c_invgroups)
        read_invgroups(c_invgroups, url_in)
    end
end

main()

