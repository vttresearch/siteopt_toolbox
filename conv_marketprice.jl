using DataFrames, CSV, XLSX
using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: connections input table"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()

    add_connection_flow_cost(parsed_args["arg1"])
end

"""
function readprices(folder, types)

    The function reads price time series from several files and concatenates them.
"""
function readprices(folder, types)

    cf0 = nothing

    for type in types
        price_file = joinpath(folder, "ts_price_" * type * ".csv")
        if !isfile(price_file)
            println("The file $price_file does not exist.")
        end
        cf = DataFrame(CSV.File(price_file, dateformat="yyyy-mm-dd HH:MM:SS", missingstring = "NA") )
        insertcols!(cf, :type => type)
        if isnothing(cf0)
            cf0 = copy(cf)
        else
            cf0 = vcat(cf0,cf)
        end
    end

    # assume that prices must be divided by 1000 e.g. from €/MWh to €/kWh
    cf0[:,:value] = cf0[:,:value] * 0.001
    
    return cf0
end


function add_connection_flow_cost(conn_file)

    #output file
    outfile = "connection_flow_cost_toolbox.xlsx"

    #read basic connection info
    c0 = DataFrame(XLSX.readtable(conn_file, "Sheet1") )
    c0 = subset(c0, :market_priced_connection => ByRow(!ismissing))
    c0 = transform(c0, [:node1, :node2] => ByRow((x,y)->"c_"*x*"__"*y) => :connection )

    #read prices
    c2 = readprices(dirname(conn_file), unique(c0[:,:market_priced_connection]) )

    #c2 = DataFrame(CSV.File(price_file, dateformat = "yyyy-mm-dd hh:MM:ss"))
    #c2 = crossjoin(c0, c2)

    c2 = innerjoin(c0, c2, on = :market_priced_connection => :type)

    c2 = select(c2, :connection, :node1, :time, :value)
    insertcols!(c2, 1, :entityclass => "connection__from_node")
    insertcols!(c2, 2, :Objectclass1 => "connection")
    insertcols!(c2, 3, :Objectclass2 => "node")
    insertcols!(c2, 6, :parameter_name => "connection_flow_cost")
    insertcols!(c2, 7, :alternative_name => "Base")

    XLSX.writetable(outfile, "connection_node_parameter" => c2, 
                           overwrite = true )
end

main()