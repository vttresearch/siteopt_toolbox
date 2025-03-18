
using ArgParse
using SpineInterface, JSON


# script for creating hp units
#
# Try from command line with
# julia --project=@. conv_hp_units.jl sqlite:///dname.sqlite 


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: input db"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()

    remove_entity(parsed_args["arg1"], ("myblock",))
    return nothing
end


function remove_entity(db_url, entities::Tuple{Vararg{String}})

	e = run_request(db_url, "query", ("entity_sq",))["entity_sq"]
    
    entity_id_by_name = Dict(x["name"] => x["id"] for x in e)
	to_rm_entity_ids = unique(entity_id_by_name[name] for name in intersect(entities, keys(entity_id_by_name)))
	
    println(to_rm_entity_ids)

    if !isempty(to_rm_entity_ids)
		a = run_request(db_url, "call_method", ("remove_items", "entity", to_rm_entity_ids...))
        #run_request(db_url, "call_method", ("commit_session", "removed item"))
        #b = run_request(db_url, "call_method", ("add_entity_item",), Dict("entity_class_name" => "representative_period", "name" => "temp"))
        #e2 = run_request(db_url, "call_method", ("get_entity_item",),
        #    Dict("entity_class_name" => "representative_period")
        #    )
        run_request(db_url, "call_method", ("commit_session", "added item"))
      
    end
end

main()