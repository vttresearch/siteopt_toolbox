using DataFrames, CSV, XLSX, Dates
using ArgParse
using Sines_additional


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: nodes input table"
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
    add_nodes(parsed_args["arg1"], parsed_args["arg3"], model_length)
end


# just the storage node
function add_nodeobjects(c0)
    c1 = select(c0, :node => :Object1)
    insertcols!(c1, 1, :Objectclass1 => "node")
    return c1
end


"""
Overall function for adding nodes

   
"""
function add_nodes(stor_file, url_in, model_length::Period)

    #read basic info
    c0 = DataFrame(XLSX.readtable(stor_file, "Sheet1") )
   
    # add alternative name if not present
    if !hasproperty(c0, :alternative_name)
        insertcols!(c0, :alternative_name => "Base")
    end

    # node names
    c0 = transform(c0, [:node, :grid] => ByRow((x,y) -> ismissing(y) ? "n_" * string(x) : "n_" * string(x) * "_" * string(y) ) 
                        => :node )

    c1 = add_object_param(c0, :node, [:demand, :balance_type], directory=dirname(stor_file)) 
    insertcols!(c1, 1, :Objectclass1 => "node")

    import_objects(url_in, add_nodeobjects(c0))
    import_object_param(url_in, c1)

end

main()