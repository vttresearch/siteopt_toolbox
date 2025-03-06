using DataFrames, CSV, XLSX
using ArgParse

include("common.jl")
include("db.jl")

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: connections input table"
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
    add_connections(parsed_args["arg1"], parsed_args["arg3"], model_length)
end

# just the object
function add_connection(c0)
    c1 = select(c0, :connection => :Object1)
    insertcols!(c1, 1, :Objectclass1 => "connection")
    return c1
end

# object parameters
function add_param_connection(c0, paramcols)
    
    c1 = copy(c0)
    # candidate connections when not specified
    default_candi_conn = 100

    # add parameter "candidate_connections"
    # TBC if this is needed
    if !hasproperty(c1, :candidate_connections)
        insertcols!(c1, :candidate_connections => missings(Float64, nrow(c1)))
        c1[(!ismissing).(c1.connection_investment_cost), :candidate_connections] .= default_candi_conn
    end

    c1 = add_object_param(c1, :connection, paramcols)
    
    insertcols!(c1, 1, :Objectclass1 => "connection")
    c1 = select(c1, :Objectclass1, :Object1, :parameter_name, :alternative_name, :value)

    return c1
end

"""
    add_to_from_node(c0)

    Adds the relationships connection__from_node and connection__to_node
"""
function add_to_from_node(c0)
    c1 = add_object_object(c0, "connection__from_node", "connection", "node", :connection, :node1)
    c11 = add_object_object(c0, "connection__to_node", "connection", "node", :connection, :node2)
    
    #reverse direction (from node)
    c2 = add_object_object(c0, "connection__from_node", "connection", "node", :connection, :node2)
    #reverse direction (to node)
    c22 = add_object_object(c0, "connection__to_node", "connection", "node", :connection, :node1)
    
    vcat(c1,c11,c2,c22)
end

"""
    add_to_from_node(c0)

    Adds the relationships connection__node__node
"""
function add_conn_node_node(c0)

    c1 = select(c0, :connection => :Object1, :node1 => :Object2, :node2 => :Object3)
    # reverse direction
    c2 = select(c0, :connection => :Object1, :node2 => :Object2, :node1 => :Object3)
    
    c1 = vcat(c1,c2)
    insertcols!(c1, 1, :relationshipclass => "connection__node__node")

    # insert also the entity classes
    insertcols!(c1, 2, :Objectclass1 => "connection")
    insertcols!(c1, 3, :Objectclass2 => "node")
    insertcols!(c1, 4, :Objectclass3 => "node")

end

"""
    c0: dataframe with connections and their parameters
    paramcols: column titles which are taken from c0
"""
function add_param_from_node(c0, paramcols; directory = "")

    c1 = add_object_object_param_wmuls(c0, :connection, :node1, paramcols; directory = directory)

    insertcols!(c1, 1, :relationshipclass => "connection__from_node")
    insertcols!(c1, 2, :Objectclass1 => "connection")
    insertcols!(c1, 3, :Objectclass2 => "node")
    c1 = select(c1, :relationshipclass, :Objectclass1, :Objectclass2, 
                :Object1, :Object2, :parameter_name, :alternative_name, :value)
end

function add_param_connection_node(c0::DataFrame, nodecol, paramcols::Array{Symbol, 1}; directory = "")

    c1 = add_object_object_param_wmuls(c0, :connection, nodecol, paramcols; directory = directory)

    insertcols!(c1, 1, :relationshipclass => "connection__from_node")
    insertcols!(c1, 2, :Objectclass1 => "connection")
    insertcols!(c1, 3, :Objectclass2 => "node")
    c1 = select(c1, :relationshipclass, :Objectclass1, :Objectclass2, 
                :Object1, :Object2, :parameter_name, :alternative_name, :value)
end

function add_param_connection_node(c0::DataFrame, nodecol, paramcols::Dict; directory = "")

    c1 = rename_columns(c0, paramcols)
    paramcols2 = collect(values(paramcols))
   
    add_param_connection_node(c1, nodecol, paramcols2; directory = directory)
end


function add_param_node_node2(c0, c_rels, paramcols)
 
    c1 = add_object_param(c0, :connection, paramcols)

    c1 = innerjoin(c1, c_rels, on = :Object1)
    c1 = select(c1, :relationshipclass, :Objectclass1, :Objectclass2, :Objectclass3, 
                :Object1, :Object2, :Object3, 
                :parameter_name, :alternative_name, :value)
end


function add_connections(conn_file, url_in, model_length::Period)

    #output file
    outfile = "connections.xlsx"

    #definitions for reverse connection flow cost
    reverse_cost_names_mapping = Dict(:connection_flow_cost_reverse => :connection_flow_cost,
        Symbol("connection_flow_cost_reverse.mul") => Symbol("connection_flow_cost.mul"))

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

    import_objects(url_in, add_connection(c0))
    import_relations_2dim(url_in, c2)
    import_object_param(url_in, c1)
    import_relations_3dim(url_in, c3)
    
    # relationship parameters
    #c4 = add_param_from_node(c0, [:connection_flow_cost, :connection_capacity], 
     #                       directory = dirname(conn_file)),

    c4 = vcat(add_param_connection_node(c0, :node1, 
                            [:connection_flow_cost, :connection_capacity], 
                            directory = dirname(conn_file)),
            add_param_connection_node(c0, :node2, 
                            reverse_cost_names_mapping, directory = dirname(conn_file) )
    )
    
    
    import_rel_param_2dim(url_in, c4)

    c5 = add_param_node_node2(c0, c3, [:fix_ratio_out_in_connection_flow] )
    import_rel_param_3dim(url_in, c5)
  
end

main()