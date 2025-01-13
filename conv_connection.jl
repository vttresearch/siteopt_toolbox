using DataFrames, CSV, XLSX
using ArgParse

include("common.jl")

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: connections input table"
            required = true
        "arg2"
            help = "a positional argument: model spec input table filename"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    model_length = calc_model_len(parsed_args["arg2"])
    add_connections(parsed_args["arg1"], model_length)
end


# just the object
function add_connection(c0)
    c1 = select(c0, :connection)
    insertcols!(c1, 1, :Objectclass1 => "connection")
    return c1
end

# object parameters
function add_param_connection(c0, paramcols)
    
    # candidate connections when not specified
    default_candi_conn = 100

    # Check if required columns exist in c0 and select what is present
    requested_cols = vcat(paramcols, [:alternative_name])
    existing_columns = intersect(requested_cols, Symbol.(names(c0)))
    c1 = select(c0, :connection, existing_columns)  

    #c1 = select(c0, :connection, :alternative_name, paramcols)            

    # add parameter "candidate_connections"
    if !hasproperty(c1, :candidate_connections)
        insertcols!(c1, :candidate_connections => missings(Float64, nrow(c1)))
        c1[(!ismissing).(c1.connection_investment_cost), :candidate_connections] .= default_candi_conn
    end

    c1 = stack(c1, Not([:connection, :alternative_name]))
    c1 = subset(c1, :value => ByRow(!ismissing))

    insertcols!(c1, 1, :Objectclass1 => "connection")
    rename!(c1, :variable => :parameter_name)
    c1 = select(c1, :Objectclass1, :connection, :parameter_name, :alternative_name, :value)
    
    return c1
end

function add_to_from_node(c0)
    c1 = select(c0, :connection, :node1)
    insertcols!(c1, 1, :relationshipclass => "connection__from_node")
    c1 = rename(c1, :node1 => :node)
    c11 = select(c0, :connection, :node2)
    insertcols!(c11, 1, :relationshipclass => "connection__to_node")
    c11 = rename(c11, :node2 => :node)
    
    #reverse direction (from node)
    c2 = select(c0, :connection, :node2)
    insertcols!(c2, 1, :relationshipclass => "connection__from_node")
    c2 = rename(c2, :node2 => :node)
    #reverse direction (to node)
    c22 = select(c0, :connection, :node1)
    insertcols!(c22, 1, :relationshipclass => "connection__to_node")
    c22 = rename(c22, :node1 => :node)
    
    c1 = vcat(c1,c11,c2,c22)
    insertcols!(c1, 2, :Objectclass1 => "connection")
    insertcols!(c1, 3, :Objectclass2 => "node")

    return c1

end

function add_conn_node_node(c0)
    c1 = select(c0, :connection, :node1, :node2)
    insertcols!(c1, 1, :relationshipclass => "connection__node__node")
    # reverse direction
    c2 = select(c0, :connection, :node1 => :node2, :node2 => :node1)
    insertcols!(c2, 1, :relationshipclass => "connection__node__node")

    c1 = vcat(c1,c2)
    # insert also the entity classes
    insertcols!(c1, 2, :Objectclass1 => "connection")
    insertcols!(c1, 3, :Objectclass2 => "node")
    insertcols!(c1, 4, :Objectclass3 => "node")

end

#=
function add_param_from_node(c0, c1, valcol)
    c1 = subset(c1, :relationshipclass => ByRow(==("connection__from_node")))
    c1 = innerjoin(c1, c0, on = :connection)
    insertcols!(c1, :parameter_name => String(valcol))
    insertcols!(c1, :alternative_name => "Base")
    c1 = select(c1, :relationshipclass, :connection, :node, :parameter_name, :alternative_name,
                valcol => :parameter_value)
    insertcols!(c1, 2, :Objectclass1 => "connection")
    insertcols!(c1, 3, :Objectclass2 => "node")
    
end
=#
"""
    c0: dataframe with connections and their parameters
    c1: dataframe with connection__from_node relatioships (including node)
    paramcols: column titles which are taken from c0
"""
function add_param_from_node(c0, c1, paramcols)
    c0 = select(c0, :connection, :alternative_name, paramcols)

    c0 = stack(c0, Not([:connection, :alternative_name]))
    c0 = subset(c0, :value => ByRow(!ismissing))
    rename!(c0, :variable => :parameter_name)

    c1 = subset(c1, :relationshipclass => ByRow(==("connection__from_node")))
    c1 = innerjoin(c1, c0, on = :connection)

    #insertcols!(c1, :alternative_name => "Base")
    c1 = select(c1, :relationshipclass, :Objectclass1, :Objectclass2, 
                :connection, :node, :parameter_name, :alternative_name, :value)
end

function add_param_node_node(c0, parameter_name, parameter_value)
    c1 = insertcols(c0, :parameter_name => parameter_name)
    c1 = insertcols(c1, :alternative_name => "Base")
    c1 = insertcols(c1, :parameter_value => parameter_value)
end

function add_param_node_node2(c0, c1, paramcols)
    c0 = select(c0, :connection, :alternative_name, paramcols)

    c0 = stack(c0, Not([:connection, :alternative_name]))
    c0 = subset(c0, :value => ByRow(!ismissing))
    rename!(c0, :variable => :parameter_name)

    c1 = innerjoin(c1, c0, on = :connection)

    c1 = select(c1, :relationshipclass, :Objectclass1, :Objectclass2, :Objectclass3, 
                :connection, :node1, :node2, :parameter_name, :alternative_name, :value)
end



function add_connections(conn_file, model_length::Period)

    #output file
    outfile = "connections.xlsx"

    #read basic connection info
    c0 = DataFrame(XLSX.readtable(conn_file, "Sheet1") )
    # connection object name
    c0 = transform(c0, [:node1, :node2] => ByRow((x,y)->"c_"*x*"__"*y) => :connection )

    # add alternative name if not present
    if !hasproperty(c0, :alternative_name)
        insertcols!(c0, :alternative_name => "Base")
    end

    # add alternative name if not present
    if !hasproperty(c0, :fix_ratio_out_in_connection_flow)
        insertcols!(c0, :fix_ratio_out_in_connection_flow => 1.0)
    end

    # adjust investment costs 
    c0.connection_investment_cost =  c0.connection_investment_cost * (model_length / Hour(8760) )
     
    # object parameters
    c1 = add_param_connection(c0, [:connection_investment_cost,
                                :connection_investment_variable_type,
                                :candidate_connections])

    # relationships
    c2 = add_to_from_node(c0)
    c3 = add_conn_node_node(c0)

    # relationship parameters
    #c3 = add_param_from_node(select(c0, :connection, :connection_flow_cost), c1, :connection_flow_cost)
    c4 = add_param_from_node(c0, c2, [:connection_flow_cost, :connection_capacity])
    #c5 = add_param_node_node(c3, "fix_ratio_out_in_connection_flow", 1)
    c5 = add_param_node_node2(c0, c3, [:fix_ratio_out_in_connection_flow] )

    XLSX.writetable(outfile, "unit" => add_connection(c0),
                            "unit_param" => c1,
                            "unit__to_node" => c2,
                            "unit__node__node" => c3, 
                            "unit__node_param" => c4, 
                            "unit__node__node_parameter" => c5, overwrite = true )
    
end

main()