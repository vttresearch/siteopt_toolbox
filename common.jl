# creates the "unit_param" sheet for the unit input excel file for importer
# used for hp, pv and storage units
function add_unit_param2(c0, paramcols)
    
    # candidate units when not specified
    default_candi_units = 40

    # Check if required columns exist in c0 and select what is present
    requested_cols = vcat(paramcols, [:alternative_name])
    existing_columns = intersect(requested_cols, Symbol.(names(c0)))
    c1 = select(c0, :unit, existing_columns)            
    
    # add candidate units if not present
    if !hasproperty(c1, :candidate_units)
        insertcols!(c1, :candidate_units => missings(Float64, nrow(c1)))
        c1[(!ismissing).(c1.unit_investment_cost), :candidate_units] .= default_candi_units
    end
    # add alternative name if not present
    if !hasproperty(c1, :alternative_name)
        insertcols!(c1, :alternative_name => "Base")
    end

    c1 = stack(c1, Not([:unit, :alternative_name]))
    c1 = subset(c1, :value => ByRow(!ismissing))

    insertcols!(c1, 1, :Objectclass1 => "unit")
    rename!(c1, :variable => :parameter_name)
    #insertcols!(c1, 4, :alternative_name => "Base")
    c1 = select(c1, :Objectclass1, :unit, :parameter_name, :alternative_name, :value)
    return c1
end

function readcf(folder, types)

    cf0 = nothing

    for type in types
        cf_file = joinpath(folder, "ts_" * type * ".csv")
        if !isfile(cf_file)
            println("The file $cf_file does not exist.")
        end
        cf = DataFrame(CSV.File(cf_file, dateformat="yyyy-mm-ddTHH:MM", missingstring = "NA") )
        insertcols!(cf, :type => type)
        if isnothing(cf0)
            cf0 = copy(cf)
        else
            cf0 = vcat(cf0,cf)
        end
    end

    if isnothing(cf0)
        return DataFrame(time = [], value = [], type = [])
    else
        return cf0
    end
end