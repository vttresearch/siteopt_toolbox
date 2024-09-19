using DataFrames, CSV, XLSX
using ArgParse

include("common.jl")

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: nodes input table"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    add_nodes(parsed_args["arg1"])
end


# just the storage node
function add_nodeobjects(c0)
    c1 = select(c0, :node)
    insertcols!(c1, 1, :Objectclass1 => "node")
    return c1
end

"""
The function adds object parameter table for storage nodes
"""

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

"""
Overall function for adding electrical storages

    Output: excel tables of electrical storage units and electrical storage nodes
"""
function add_nodes(stor_file)

    #output file names
    outfile1 = "nodes_import.xlsx"
    outfile2 = "nodes_objpar_ts.csv"
    
    #read basic info
    c0 = DataFrame(XLSX.readtable(stor_file, "Sheet1") )
   
    # add alternative name if not present
    if !hasproperty(c0, :alternative_name)
        insertcols!(c0, :alternative_name => "Base")
    end

    c1, objpar_ts = add_node_param(c0, [:demand, :balance_type],
                                directory=dirname(stor_file)) 

    # Storage nodes excel file
    XLSX.writetable(outfile1, 
        "object" => add_nodeobjects(c0), 
        "object_parameter" => c1, 
        overwrite = true
    )

    # Storage nodes object parameter timeseries file in the format which can 
    # be read by toolbox importer
    CSV.write(outfile2, objpar_ts, dateformat="yyyy-mm-ddTHH:MM")
end

main()