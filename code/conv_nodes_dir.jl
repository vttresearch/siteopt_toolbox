using DataFrames, CSV, XLSX
using ArgParse

include("common.jl")
include("db.jl")

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
The function adds object parameter table for storage nodes
"""
#=
function add_node_param(c0, paramcols; directory="")

    c1 = select(c0, :node, :alternative_name, paramcols)

     c1 = stack(c1, Not([:node, :alternative_name]))
     c1 = subset(c1, :value => ByRow(!ismissing))

    insertcols!(c1, :objectclass => "node")
    rename!(c1, :variable => :parameter_name)

    # use only numeric values
    c1_num = subset(c1, :value => ByRow(x -> !(isa(x, String) && startswith(x, "ts:")) ))

    c1_num = select(c1_num, :objectclass, :node, :parameter_name, :alternative_name, :value)

    # use only text values which start with ts:
    c1_str = subset(c1, :value => ByRow(x -> isa(x, String) && startswith(x, "ts:")))

    c1_str = add_node_param_timeser(c1_str, directory)

    return c1_num, c1_str
end

function add_node_param_timeser(c1_str, directory)
    
    # define time series file names
    prefix = "ts:"

    # Remove the substring from the beginning of each string
    c1_str[:,:value] = [startswith(x, prefix) ? x[length(prefix)+1:end] : x for x in c1_str[:,:value]]
    rename!(c1_str, :value => :type)
    types = unique(c1_str[:,:type])

    #load timeseries
    timeser = readcf(directory, types)

    # assign the time series for parameters
    c1_str = innerjoin(c1_str, timeser, on = :type)

    # create the final object parameter timeseries table
    c1_str = select(c1_str, :objectclass, :node, :parameter_name, :alternative_name, :time, :value)

end
=#
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