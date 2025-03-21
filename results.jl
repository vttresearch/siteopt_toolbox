using JSON


function summarizeresults(url_in::Union{String, Nothing}, 
                        url_out::String, 
                        recipe_file::String, 
                        scenario::Union{Vector{String}, Nothing})
  
    # load recipe
    recipe = JSON.parsefile(recipe_file)

    println(get_entities(url_out, "stochastic_scenario") )

    #load output DB to memory
    db_out = export_data(url_out)

    df = DataFrame(summary = [], costitem = [], scenario = [], entity = [], value = [])

    for (key0, val0) in recipe
        for (key1, val1) in val0
            for val2 in val1
                if val2["type"] == "unit_flow_cost"
                    a = result_unit_flow_costs(url_in, url_out, val2["unit"], val2["node"], scenario)
                elseif val2["type"] == "unit_flow"
                    a = result_unit_flow(db_out, val2["unit"], val2["node"], "parent", scenario)
                elseif val2["type"] == "unit_flow_ts"
                    a = result_unit_flow(url_out, val2["unit"], val2["node"], "parent", scenario, _sum=false)
                elseif val2["type"] == "connection_flow_cost"
                    a = result_connection_flow_costs(url_in, url_out, val2["connection"], val2["node"], scenario)
                elseif val2["type"] == "unit_investment_cost"
                    a = result_unit_investment_costs(url_in, url_out, val2["unit"], scenario)
                elseif val2["type"] == "connection_investment_cost"
                    a = result_connection_investment_costs(url_in, url_out, val2["connection"], scenario)
                elseif val2["type"] == "node_investment_cost"
                    a = result_node_investment_costs(url_in, url_out, val2["node"], scenario)
                elseif val2["type"] == "unit_investment"
                    a = result_unit_investment(db_out, val2["unit"], "parent", scenario)
                elseif val2["type"] == "node_investment"
                    a = result_node_investment(url_out, val2["node"], scenario)
                else
                    println("Unknown value type $(val2["type"])")
                end
                scaler = get(val2, "scaling", 1)
                transform!(a, :value => (x -> x .* scaler) => :value)
                insertcols!(a, :costitem => key1)
                insertcols!(a, :summary => key0)
                df = vcat(df, a, cols = :union)
            end
        end
    end

    if nrow(df) > 0
        #combine different entities
        df = combine(groupby(df, [:summary, :costitem, :scenario]), :value => sum => :value)
    end

    return df
end


"""
    function result_connection_flow_costs(url_in::String, url_out::String, 
    con::String, node::String, scenario::String)

    Calculate the total connection flow cost of a certain connection__to_node relationship
    using model results and parameters for certain scenario. 
"""
function result_connection_flow_costs(url_in::String, url_out::String, 
    con::String, node::String, scenario::String)
    a = get_parameter_values_scenario(url_in, "connection__to_node", 
        [con, node], "connection_flow_cost", scenario)
    b = get_parameter_values(url_out, "report__connection__node__direction__stochastic_scenario", 
        ["report1", con, node, "to_node", "realization"], "connection_flow")
    b = subset(b, :alternative => ByRow(==(scenario)))
    
   
    return tssum(a.value[1] * b.value[1])
end

function result_connection_flow_costs(url_in::String, url_out::String, 
    con::String, node::String, scenario::Vector{String})

    a = DataFrame(scenario = [], value= [])

    for s in scenario
        v = get_parameter_values_scenario(url_in, "connection__to_node", 
            [con, node], "connection_flow_cost", s)
        select!(v, :value)
        insertcols!(v, :scenario => s)
        a = vcat(a,v)
    end
        
    rename!(a, :value => :value_a)

    b = get_parameter_values(url_out, "report__connection__node__direction__stochastic_scenario", 
        ["report1", con, node, "to_node", "realization"], "connection_flow")
    
    ab = innerjoin(a,b, on = :scenario => :alternative)
    transform!(ab, [:value_a, :value] => ByRow((a, b) -> tssum(a * b)) => :value)
    
    return select(ab, :scenario, :entity, :value)
end

function result_unit_flow_costs(url_in::String, url_out::String, 
    u::String, node::String, scenario::String)
    a = get_parameter_values_scenario(url_in, "unit__to_node", 
        [u, node], "vom_cost", scenario)
    b = get_parameter_values(url_out, "report__unit__node__direction__stochastic_scenario", 
        ["report1", u, node, "to_node", "realization"], "unit_flow")
    b = subset(b, :alternative => ByRow(==(scenario)))
    

    return tssum(a.value[1] * b.value[1])
end

function result_unit_flow_costs(url_in::String, url_out::String, 
    u::String, node::String, scenario::Vector{String})

    a = DataFrame(scenario = [], value= [])

    for s in scenario
        v = get_parameter_values_scenario(url_in, "unit__to_node", 
            [u, node], "vom_cost", s)
        select!(v, :value)
        insertcols!(v, :scenario => s)
        a = vcat(a,v)
    end
        
    rename!(a, :value => :value_a)

    b = get_parameter_values(url_out, "report__unit__node__direction__stochastic_scenario", 
        ["report1", u, node, "to_node", "realization"], "unit_flow")
    
    ab = innerjoin(a,b, on = :scenario => :alternative)
    transform!(ab, [:value_a, :value] => ByRow((a, b) -> tssum(a * b)) => :value)
    
    return select(ab, :scenario, :entity, :value)
end

function result_unit_flow(url_out::Union{String, Dict}, 
    u::String, node::String, stoch_scen::String, 
    scenario::Union{Vector{String}, Nothing}; _sum=true)

    b = get_parameter_values(url_out, "report__unit__node__direction__stochastic_scenario", 
        ["report1", u, node, "to_node", stoch_scen], "unit_flow")
    
    if !isnothing(scenario)
        b = subset(b, :alternative => ByRow(in(scenario)))
    end
   
  
    rename!(b, :alternative => :scenario)
    if _sum
        transform!(b, :value => ByRow((a) -> tssum(a)) => :value)
    end

    return select(b, :scenario, :entity, :value)
end

function result_unit_investment_costs(url_in::String, url_out::String, 
    unit::String, scenario::Vector{String})

    a = DataFrame(scenario = [], value= [])

    for s in scenario
        v = get_parameter_values_scenario(url_in, "unit", 
            unit, "unit_investment_cost", s)
        select!(v, :value)
        insertcols!(v, :scenario => s)
        a = vcat(a,v)
    end
        
    rename!(a, :value => :value_a)

    b = get_parameter_values(url_out, "report__unit__stochastic_scenario", 
        ["report1", unit, "realization"], "units_invested")
    
    ab = innerjoin(a,b, on = :scenario => :alternative)
    transform!(ab, [:value_a, :value] => ByRow((a, b) -> tssum(b) * a) => :value)
    
    return select(ab, :scenario, :entity, :value)
end

function result_connection_investment_costs(url_in::String, url_out::String, 
    con::String, scenario::Vector{String})

    a = DataFrame(scenario = [], value= [])

    for s in scenario
        v = get_parameter_values_scenario(url_in, "connection", 
            con, "connection_investment_cost", s)
        select!(v, :value)
        insertcols!(v, :scenario => s)
        a = vcat(a,v)
    end
        
    rename!(a, :value => :value_a)

    b = get_parameter_values(url_out, "report__connection__stochastic_scenario", 
        ["report1", con, "realization"], "connections_invested")
    
    ab = innerjoin(a,b, on = :scenario => :alternative)
    transform!(ab, [:value_a, :value] => ByRow((a, b) -> tssum(b) * a) => :value)
    
    return select(ab, :scenario, :entity, :value)
end

function result_node_investment_costs(url_in::String, url_out::String, 
    node::String, scenario::Vector{String})

    a = DataFrame(scenario = [], value= [])

    for s in scenario
        v = get_parameter_values_scenario(url_in, "node", 
            node, "storage_investment_cost", s)
        select!(v, :value)
        insertcols!(v, :scenario => s)
        a = vcat(a,v)
    end
        
    rename!(a, :value => :value_a)

    b = get_parameter_values(url_out, "report__node__stochastic_scenario", 
        ["report1", node, "realization"], "storages_invested")
    
    ab = innerjoin(a,b, on = :scenario => :alternative)
    transform!(ab, [:value_a, :value] => ByRow((a, b) -> tssum(b) * a) => :value)
    
    return select(ab, :scenario, :entity, :value)
end

"""
    result_unit_investment(db::Union{String, Dict}, 
        unit::String, stoch_scen::String, scenario::Union{Vector{String}, Nothing})

    `db` Results DB URL or in-memory dictionary
    `unit` The unit name or partial string
    `stoch_scen` Stochastic scenario name
    `scenario` output scenario name. if nothing, considers all scenarios.

    Returns: DataFrame with cols entity, alternative, value
"""
function result_unit_investment(db::Union{String, Dict}, 
    unit::String, stoch_scen::String, scenario::Union{Vector{String}, Nothing})

    units = get_entities(db, "unit")
    units = filter(x -> occursin(unit, x), units)
    println(units)
    entityelementsvec = [["report1", u, stoch_scen] for u in units]

    #b = get_parameter_values(db, "report__unit__stochastic_scenario", 
    #    ["report1", unit, stoch_scen], "units_invested")
    
    b = get_parameter_values(db, "report__unit__stochastic_scenario", "units_invested")
    b = subset(b, :entity => ByRow(x->in(x, entityelementsvec) ))

    if !isnothing(scenario)
        b = subset(b, :alternative => ByRow(in(scenario)))
    end
    transform!(b, :value => ByRow(b -> tssum(b) ) => :value)
    return select(b, :alternative => :scenario, :entity, :value)
end

function result_node_investment(url_out::String, 
    node::String, scenario::Vector{String})

    b = get_parameter_values(url_out, "report__node__stochastic_scenario", 
        ["report1", node, "realization"], "storages_invested")
    
    b = subset(b, :alternative => ByRow(in(scenario)))
    transform!(b, :value => ByRow(b -> tssum(b) ) => :value)
    return select(b, :alternative => :scenario, :entity, :value)
end
