function add_unit_param2(c0, paramcols)
    
    c1 = select(c0, :unit, paramcols)            

    # add candidate connections
    insertcols!(c1, :candidate_units => missings(Float64, nrow(c1)))
    c1[(!ismissing).(c1.unit_investment_cost), :candidate_units] .= 40
    
    c1 = stack(c1, Not(:unit))
    c1 = subset(c1, :value => ByRow(!ismissing))

    insertcols!(c1, 1, :Objectclass1 => "unit")
    rename!(c1, :variable => :parameter_name)
    insertcols!(c1, 4, :alternative_name => "Base")
    c1 = select(c1, :Objectclass1, :unit, :parameter_name, :alternative_name, :value)
    return c1
end