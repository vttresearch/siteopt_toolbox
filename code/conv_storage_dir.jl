using DataFrames, CSV, XLSX, Dates
using ArgParse
using Sines_additional

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: storages input table"
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
    add_storages(parsed_args["arg1"],  parsed_args["arg3"], model_length)
end


# just the storage node
function add_stornode(c0)
    c1 = select(c0, :stornode => :Object1)
    insertcols!(c1, 1, :Objectclass1 => "node")
    return c1
end


# the unit-node relationships 
function add_unit_to_node_storage(c0)
    vcat(add_unit_to_node(c0, "unit__to_node", :stornode),
        add_unit_to_node(c0, "unit__to_node", :basenode),
        add_unit_to_node(c0, "unit__to_node", :emissionnode),
        add_unit_to_node(c0, "unit__from_node", :stornode),
        add_unit_to_node(c0, "unit__from_node", :basenode)
    )
end


"""
    Adding the unit-node relationship parameters for storage units
"""
function add_unit_node_param_storage(c0; directory = "")

    c1 = select(c0, Not(:basenode))
    c1 = add_unit_node_param(rename(c1, :stornode => :basenode, :max_charging => :unit_capacity),
             [:unit_capacity]; directory = directory)
    
    c2 = add_unit_node_param(rename(c0, :max_discharging => :unit_capacity), [:unit_capacity]; directory = directory)
    
    # emissions parameters (emitted to :emissionnode)
    c3 = add_unit_node_param_emission(c0, Dict(:investment_emission => :minimum_operating_point,
                                                :emission_cost => :vom_cost,
                                                :emission_flow_capacity => :unit_capacity))

    vcat(c1,c2,c3)
end


# the unit-node-node relationships
function add_unit_node_node_storage(c0)
    vcat(add_unit_node_node(c0, :stornode, :basenode),
        add_unit_node_node(c0, :basenode, :stornode))
end

function add_unit_node_node_param_storage(c0)
    c1 = add_unit_node_node_storage(c0)
    insertcols!(c1, 8, :parameter_name => "fix_ratio_out_in_unit_flow")
    insertcols!(c1, 9, :alternative_name => "Base")
    insertcols!(c1, 10, :value => 0.95)

    return c1
end

function add_storage_node_param3(c0, paramcols; directory="")

    c1 = insertcols(c0, :has_state => true)
    c2 = add_object_param(c1, :stornode, [paramcols; :has_state], directory = directory)
    return insertcols(c2, 1, :Objectclass1 => "node")
end


function add_storage_node_param_timeser(c1_str, directory)
    
    # define time series file names
    prefix = "ts:"

    # Remove the substring from the beginning of each string
    c1_str[:,:value] = [startswith(x, prefix) ? x[length(prefix)+1:end] : x for x in c1_str[:,:value]]
    rename!(c1_str, :value => :tstype)
    types = unique(c1_str[:,:tstype])

    #load timeseries
    timeser = readcf2(directory, types)

    # assign the time series for parameters
    c1_str = transform(c1_str, :tstype => ByRow(x -> timeser[x] ) =>  :value )

    # create the final object parameter timeseries table
    c1_str = select(c1_str, :Objectclass1, :stornode => :Object1, :parameter_name, :alternative_name, :value)

end

"""
    add_storages(stor_file, url_in, model_length::Period)

    Overall function for adding energy storages.

    stor_file: storages input table file path (excel)
    url_in: DB url
    model_length: model horizon length
    
"""
function add_storages(stor_file, url_in, model_length::Period)

    #read basic info
    c0 = DataFrame(XLSX.readtable(stor_file, "Sheet1") )
   
    c0 = transform(c0, [:type, :block_identifier] => 
        ByRow((a,b) -> ifelse(a=="elec", "u_"*string(b)*"_stocharger", "u_"*string(b)*"_heatstocharger")) => :unit )

    c0 = transform(c0, [:type, :block_identifier] => 
        ByRow((a,b) -> ifelse(a=="elec", "n_"*string(b)*"_elecstor", "n_"*string(b)*"_heatstor")) => :stornode )

    c0 = transform(c0, [:type, :block_identifier] => 
        ByRow((a,b) -> ifelse(a=="elec", "n_"*string(b)*"_elec", "n_"*string(b)*"_dheat")) => :basenode )

    c0 = transform(c0, [:emissionnode] => ByRow(x -> ismissing(x) ?  missing : "n_" * string(x) ) 
            => :emissionnode )

    # add alternative name if not present
    if !hasproperty(c0, :alternative_name)
        insertcols!(c0, :alternative_name => "Base")
    end

    # adjust investment costs 
    c0.unit_investment_cost =  c0.unit_investment_cost * (model_length / Hour(8760) )
    c0.storage_investment_cost = c0.storage_investment_cost * (model_length / Hour(8760) )

    # add min share of online units for emissions to work
    # see also add_unit_node_param_storage()
    insertcols!(c0, :min_units_on_share => 1.0)

    # object parameters
    c1 =  add_unit_param2(c0, [:unit_investment_cost, :candidate_units, :min_units_on_share])
    c1_sto = add_storage_node_param3(c0, [:node_state_cap, 
                    :demand,
                    :storage_investment_cost,
                    :candidate_storages,
                    :storage_investment_variable_type],
                    directory=dirname(stor_file)) 

    import_objects(url_in, add_unit(c0))
    import_object_param(url_in, c1)
    import_objects(url_in, add_stornode(c0))
    import_object_param(url_in, c1_sto)

    import_relations_2dim(url_in, add_unit_to_node_storage(c0))
    import_rel_param_2dim(url_in, 
        add_unit_node_param_storage(c0, directory=dirname(stor_file)))

    # required for emissions to work
    #c5 = add_units_on_temporal_block(c0, "myinvestmentblock")
    #import_relations_2dim(url_in, c5)

    #unit-node-node relationships
    import_relations_3dim(url_in, add_unit_node_node_storage(c0))
    import_rel_param_3dim(url_in, add_unit_node_node_param_storage(c0))

end

main()