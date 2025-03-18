
using SpineInterface

function _db_url(dbname::String)
    file_path =  abspath(joinpath("dbs", dbname))
    url = "sqlite:///$file_path"
end


function close_db(url_in)
    SpineInterface.close_connection(url_in)
end


function replace_timeseries(d::Vector, dirname)
    for i in 1:length(d)
        for j in findall(x -> x isa Dict, d[i])
            if get(d[i][j], "type", 0) == "timeseries"
                # reading data from a csv file
                a = read_timeseries(dirname, 
                                    get(d[i][j], "data", nothing),
                                    get(d[i][j], "column", nothing))
                # if expression was provided
                e = get(d[i][j], "expression", nothing)
                if !isnothing(e)
                    f = create_function_from_string("x->" * e)
                    a = Base.invokelatest(f,a)
                end
                d[i][j] = unparse_db_value(a)
            end
        end
    end 
    return d
end

function loadmodel_nofilter(url_in, filename)
    # load data 
    mdict = JSON.parsefile(filename)
    SpineInterface.import_data(url_in, mdict, "loadmodel_nofilter")
    return url_in
end

function loadmodel(url_in, filename)
    # load model definition
    mdict = JSON.parsefile(filename)
    data1 = Dict{Symbol,Any}()

    # check where timeseries are found in model data
    if haskey(mdict, "parameter_values")
        data1[:parameter_values] = replace_timeseries(mdict["parameter_values"],
                                    dirname(filename))
    end
   
    if haskey(mdict, "entities")
        data1[:entities] = mdict["entities"]
    end
    
    if haskey(mdict, "alternatives")
        data1[:alternatives] = mdict["alternatives"]
    end
    if haskey(mdict, "scenario_alternatives")
        data1[:scenario_alternatives] = mdict["scenario_alternatives"]
    end
    if haskey(mdict, "scenarios")
        data1[:scenarios] = mdict["scenarios"]
    end
    SpineInterface.import_data(url_in, data1, "testing")
    return url_in

end

function import_objects(url_in, df)

    if isnothing(df) 
        return
    end

    a = [[r[:Objectclass1], 
        r[:Object1]]
        for r in eachrow(df)
    ]

    SpineInterface.import_data(url_in, Dict(:entities => a), "testing")
end

function import_relations_2dim(url_in, df)
    		
    a = [
            [r[:relationshipclass], 
            [r[:Object1], r[:Object2]],
            ]
        for r in eachrow(df)
    ]
 
    SpineInterface.import_data(url_in, Dict(:entities => a), "testing")
end

function import_relations_3dim(url_in, df)
    		
    a = [
            [r[:relationshipclass], 
            [r[:Object1], r[:Object2], r[:Object3]],
            ]
        for r in eachrow(df)
    ]
 
    SpineInterface.import_data(url_in, Dict(:entities => a), "testing")
end



function import_object_param(url_in, df)
    
    # Convert values column to type Any
    df.value = convert(Vector{Any}, df.value)
   
    # check for value types and convert if needed
    # Find parameter values which are DateTime
    ind = findall(x -> x isa DateTime, df[:, :value])
    df[ind, :value] = unparse_db_value.(df[ind, :value])

    # Find parameter values which are TimeSeries
    ind = findall(x -> x isa TimeSeries, df[:, :value])
    for i in ind
        df[i,:value] = unparse_db_value(df[i, :value])
    end

    a = [
            [r[:Objectclass1], 
            r[:Object1], 
            r[:parameter_name],
            r[:value],
            r[:alternative_name]
        ]
        for r in eachrow(df)
    ]
    SpineInterface.import_data(url_in, Dict(:parameter_values => a), "testing")
    	
end

function import_rel_param_2dim(url_in, df)
    
    # Convert values column to type Any
    df.value = convert(Vector{Any}, df.value)
   
    unparse_some_value_types(@view df[:, :value])
    
    #=
    # check for value types and convert if needed
    # Find parameter values which are DateTime
    ind = findall(x -> x isa DateTime, df[:, :value])
    df[ind, :value] = unparse_db_value.(df[ind, :value])

    # Find parameter values which are TimeSeries
    ind = findall(x -> x isa TimeSeries, df[:, :value])
    for i in ind
        df[i,:value] = unparse_db_value(df[i, :value])
    end
    =#
    a = [
            [
                r[:relationshipclass],
                [r[:Object1], r[:Object2]], 
                r[:parameter_name],
                r[:value],
                r[:alternative_name]
            ]
        for r in eachrow(df)
    ]

    SpineInterface.import_data(url_in, Dict(:parameter_values => a), "testing")
end

function import_rel_param_3dim(url_in, df)
    
    # Convert values column to type Any
    df.value = convert(Vector{Any}, df.value)

    unparse_some_value_types(@view df[:, :value])
    
    a = [
            [
                r[:relationshipclass],
                [r[:Object1], r[:Object2], r[:Object3]], 
                r[:parameter_name],
                r[:value],
                r[:alternative_name]
            ]
        for r in eachrow(df)
    ]

    SpineInterface.import_data(url_in, Dict(:parameter_values => a), "testing")
end

function unparse_some_value_types(v::AbstractVector)

    # check for value types and convert if needed
    # Find parameter values which are DateTime
    ind = findall(x -> x isa DateTime, v)
    v[ind] = unparse_db_value.(v[ind])

    # Find parameter values which are TimeSeries
    ind = findall(x -> x isa TimeSeries, v)
    for i in ind
        v[i] = unparse_db_value(v[i])
    end
end


function get_entities(db_url::String, entityclass::String)

    entities = SpineInterface.run_request(db_url, "call_method", ("get_items","entity"),
        Dict("entity_class_name" => entityclass)
    )

    a = [r["name"] for r in entities] 
    
end


"""
    get_parameter_value(db_url, entityclass, entityelements, paramname)

    Read parameter value from the Spine DB for certain entity.
"""
function get_parameter_values(db_url::String, entityclass::String, entityelements, paramname::String)

    if entityelements isa Vector{String}
        entityelements2 = tuple(entityelements...)
    else
        entityelements2 = tuple(entityelements,)
    end

    a = DataFrame(entity = [], alternative=[], value=[])
	
	pval = SpineInterface.run_request(db_url, "call_method", ("get_parameter_value_items",), Dict(
				"entity_class_name" => entityclass,
				"parameter_definition_name" => paramname)
			)  
    
    if length(pval) > 0
        if length(entityelements2) == 1
            a = DataFrame( [(entity=r["entity_byname"], alternative=r["alternative_name"], 
                    value=parse_db_value(r["value"], r["type"]) ) for r in pval] )
        else
            a = DataFrame( [(entity=r["element_name_list"], alternative=r["alternative_name"], 
                    value=parse_db_value(r["value"], r["type"]) ) for r in pval] )
        end

        # filter according to the entity
        a = subset(a, :entity => ByRow(==(collect(entityelements2) )))
    end
        
    return a
end

function get_parameter_values_scenario(db_url::String, entityclass::String, 
        entityelements, paramname::String, scenario::String)

    if entityelements isa Vector{String}
        entityelements2 = tuple(entityelements...)
    else
        entityelements2 = tuple(entityelements,)
    end

    a = DataFrame(entity = [], alternative=[], value=[])
	filters = Dict("scenario" => scenario)

    pval = SpineInterface._db(db_url) do db
        old_filters = SpineInterface._current_filters(db)
        SpineInterface._run_server_request(db, "clear_filters")
        SpineInterface._run_server_request(db, "apply_filters", (filters,))
        data = SpineInterface._run_server_request(db, "call_method", 
                ("get_parameter_value_items",), 
                Dict("entity_class_name" => entityclass, 
				"parameter_definition_name" => paramname)
			)
        SpineInterface._run_server_request(db, "clear_filters")
        SpineInterface._run_server_request(db, "apply_filters", (old_filters,))
        data
    end
    
    if length(pval) > 0
        if length(entityelements2) == 1
            a = DataFrame( [(entity=r["entity_byname"], alternative=r["alternative_name"], 
                    value=parse_db_value(r["value"], r["type"]) ) for r in pval] )
        else
            a = DataFrame( [(entity=r["element_name_list"], alternative=r["alternative_name"], 
                    value=parse_db_value(r["value"], r["type"]) ) for r in pval] )
        end

        # filter according to the entity
        a = subset(a, :entity => ByRow(==(collect(entityelements2) )))
    end
        
    return a
end

function get_parameter_values2(db_url::String, entityclass::String, entityelements, paramname::String)

    a = Dict()
    if entityelements isa Vector{String}
        entityelements2 = tuple(entityelements...)
    else
        entityelements2 = tuple(entityelements,)
    end
   
    alternative_items = run_request(db_url, "call_method", ("get_alternative_items",))
		for alternative in alternative_items
			# Get the param value for certain alternative
			pval = SpineInterface.run_request(db_url, "call_method", ("get_parameter_value_item",), Dict(
				"entity_class_name" => entityclass, 
				"parameter_definition_name" => paramname, 
				"entity_byname" => entityelements2, 
				"alternative_name" => alternative["name"])
			)     
            if length(pval) > 0
                a[alternative["name"]] = parse_db_value(pval["value"], pval["type"])
            end
    end

    return a
end

"""
    get_parameter_values(db_url, entityclass, paramname)

    Read parameter values from the Spine DB for all entities in the entityclass `entityclass`.
"""
function get_parameter_values(db_url::String, entityclass::String, paramname::String)

    a = DataFrame(entity = [], alternative=[], value=[])
	
	pval = SpineInterface.run_request(db_url, "call_method", ("get_parameter_value_items",), Dict(
				"entity_class_name" => entityclass, 
				"parameter_definition_name" => paramname)
			)  

    if length(pval) > 0
        a = DataFrame( [(entity=r["element_name_list"], alternative=r["alternative_name"], 
                    value=parse_db_value(r["value"], r["type"]) ) for r in pval] )
    end
        
    return a
end
function get_parameter_values2(db_url::String, entityclass::String, paramname::String)

    a = DataFrame(entity = [], alternative=[], value=[])

    entities = SpineInterface.run_request(db_url, "call_method", ("get_items","entity"),
        Dict("entity_class_name" => entityclass)
    )

    alternative_items = run_request(db_url, "call_method", ("get_alternative_items",))
	for ent in entities
        for alternative in alternative_items
			# Get the parameter value for certain alternative and entity
			pval = SpineInterface.run_request(db_url, "call_method", ("get_parameter_value_item",), Dict(
				"entity_class_name" => entityclass, 
				"parameter_definition_name" => paramname, 
                "entity_byname" => ent["element_name_list"], 
				"alternative_name" => alternative["name"])
			)    
            if length(pval) > 0
                push!(a, (entity=ent["element_name_list"], alternative=alternative["name"], 
                    value=parse_db_value(pval["value"], pval["type"]) ) )
            end
        end
    end

    return a
end
function get_parameter_values_scenario(db_url::String, entityclass::String, paramname::String,
                scenario::String)

    a = DataFrame(entity = [], alternative=[], value=[])
	filters = Dict("scenario" => scenario)

    pval = SpineInterface._db(db_url) do db
        old_filters = SpineInterface._current_filters(db)
        SpineInterface._run_server_request(db, "apply_filters", (filters,))
        data = SpineInterface._run_server_request(db, "call_method", 
                ("get_parameter_value_items",), 
                Dict("entity_class_name" => entityclass, 
				"parameter_definition_name" => paramname)
			)
        SpineInterface._run_server_request(db, "clear_filters")
        SpineInterface._run_server_request(db, "apply_filters", (old_filters,))
        data
    end

    if length(pval) > 0
        a = DataFrame( [(entity=r["element_name_list"], alternative=r["alternative_name"], 
                    value=parse_db_value(r["value"], r["type"]) ) for r in pval] )
    end
        
    return a
end

function export_data(db_url; filters=Dict(), kwargs::Dict=Dict())
    SpineInterface._db(db_url) do db
        isempty(filters) && return SpineInterface._run_server_request(db, "export_data", kwargs...)
        old_filters = SpineInterface._current_filters(db)
        SpineInterface._run_server_request(db, "apply_filters", (filters,))
        #data = SpineInterface._run_server_request(db, "export_data", kwargs...)
        data = SpineInterface._run_server_request(db, "call_method", ("get_parameter_value_items",), Dict(
				"entity_class_name" => "connection__to_node", 
				"parameter_definition_name" => "connection_flow_cost")
			)  
        SpineInterface._run_server_request(db, "clear_filters")
        isempty(old_filters) || SpineInterface._run_server_request(db, "apply_filters", (old_filters,))
        data
    end
end

function remove_entity(db_url, entities::Tuple{Vararg{String}})

	e = run_request(db_url, "query", ("entity_sq",))["entity_sq"]
    
    entity_id_by_name = Dict(x["name"] => x["id"] for x in e)
	to_rm_entity_ids = unique(entity_id_by_name[name] for name in intersect(entities, keys(entity_id_by_name)))
	
    println(to_rm_entity_ids)

    if !isempty(to_rm_entity_ids)
		a = run_request(db_url, "call_method", ("remove_items", "entity", to_rm_entity_ids...))
        run_request(db_url, "call_method", ("commit_session", "removed item"))
    end
end
