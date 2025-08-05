using XLSX
using Dates, TimeZones
using SpineInterface #for TimeSeries

"""
    add_unit_node_param(c0, paramcols; directory = "")

    Produces the unit-node parameters table
"""
function add_unit_node_param(c0, paramcols; directory = "")

    c1 = add_object_object_param(c0, :unit, :basenode, paramcols, directory = directory)

    # final dataframe
    insertcols!(c1, 1, :relationshipclass => "unit__to_node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")
    c1 = select(c1, :relationshipclass, :Objectclass1, :Objectclass2, 
                :Object1, :Object2, :parameter_name, :alternative_name, :value)
end


function add_object_object_param_wmuls(c0, object1, object2, paramcols; directory = "")

    c1 = add_object_object_param(c0, object1, object2, paramcols, directory = directory)

    # select the multiplier columns of input and rename them
    a = Dict(Symbol(name) => col for col in paramcols for name in names(c0)
            if isequal(name, String(col) * ".mul")
        )
    
    if length(a) > 0
        c2 = select(c0, object1 => :Object1, object2 => :Object2, :alternative_name, collect(keys(a)))
        rename!(c2, a)
        
        # stack multipliers and join
        c2 = stack(c2, Not([:Object1, :Object2, :alternative_name]))
        c2 = subset(c2, :value => ByRow(!ismissing))
        rename!(c2, :variable => :parameter_name, :value => :multiplier)           
        
        c1 = leftjoin(c1, c2, on = [:Object1, :Object2, :alternative_name, :parameter_name])
        c1 = transform(c1, [:value, :multiplier] => ByRow((a,b) -> ismissing(b) ? a : a * b) => :value)
    end

    return c1
end

"""
    add_object_object_param(c0, object1, object2, paramcols; directory = "")

    Add 2-dim object parameters from the dataframe c0
"""
function add_object_object_param(c0, object1, object2, paramcols; directory = "")

    # Check if required columns exist in c0 and select what is present
    requested_cols = vcat(paramcols, [:alternative_name])
    existing_columns = intersect(requested_cols, Symbol.(names(c0)))
    c1 = select(c0, object1, object2, existing_columns)

    # add alternative name if not present
    if !hasproperty(c1, :alternative_name)
        insertcols!(c1, :alternative_name => "Base")
    end

    c1 = stack(c1, Not([object1, object2, :alternative_name]))
    c1 = subset(c1, :value => ByRow(!ismissing))

    rename!(c1, :variable => :parameter_name)

    # text values which start with ts: indicating a timeseries
    # load the corresponding timeseries into value clumn
    c1_str = subset(c1, :value => ByRow(x -> isa(x, String) && startswith(x, "ts:")))
    c1_str = load_table_timeser_values(c1_str, directory)

    # only numeric or string values; combine with timeseries
    c1 = subset(c1, :value => ByRow(x -> !(isa(x, String) && startswith(x, "ts:")) ))
    c1 = vcat(c1, c1_str)

    rename!(c1, object1 => :Object1, object2 => :Object2)
   
    return c1
end

function load_table_timeser_values(c1_str, directory)
    
    # define time series file names prefix
    prefix = "ts:"

    # Remove the substring from the beginning of each string
    c1_str[:,:value] = [startswith(x, prefix) ? x[length(prefix)+1:end] : x for x in c1_str[:,:value]]
    rename!(c1_str, :value => :tstype)
    types = unique(c1_str[:,:tstype])

    #load timeseries from disk as Dict
    timeser = readcf2(directory, types)

    # assign the time series for parameters
    c1_str = transform(c1_str, :tstype => ByRow(x -> timeser[x] ) =>  :value )

    select!(c1_str, Not(:tstype))
    return c1_str

end

"""
    add_unit_node_node_param(c0, node2, paramcols; directory = "")

    Produces the unit-node-node parameters table assuming that there is an
    unique second node for every unit. Assumes that the first node is "basenode".
"""
function add_unit_node_node_param(c0, node2, paramcols; directory = "")

    c1 = add_unit_node_param(c0, paramcols, directory = directory)
    c1[:, :relationshipclass] .= "unit__node__node"
    c2 = select(c0, :unit => :Object1, node2 => :Object3)
    c1 = innerjoin(c1, c2, on = :Object1)
    insertcols!(c1, 4, :Objectclass3 => "node")
    c1 = select(c1, :relationshipclass, :Objectclass1, :Objectclass2, :Objectclass3,
                :Object1, :Object2, :Object3, :parameter_name, 
                :alternative_name, :value)

    return c1
end

# TBC: replace by add_object_param
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
    c1 = select(c1, :Objectclass1, :unit => :Object1, :parameter_name, :alternative_name, :value)
    return c1
end

function add_object_param(c0, object1, paramcols; directory = "")
    
    # Check if required columns exist in c0 and select what is present
    requested_cols = vcat(paramcols, [:alternative_name])
    existing_columns = intersect(requested_cols, Symbol.(names(c0)))
    c1 = select(c0, object1, existing_columns)

    # add alternative name if not present
    if !hasproperty(c1, :alternative_name)
        insertcols!(c1, :alternative_name => "Base")
    end

    c1 = stack(c1, Not([object1, :alternative_name]))
    c1 = subset(c1, :value => ByRow(!ismissing))

    rename!(c1, :variable => :parameter_name)

    # text values which start with ts: indicating a timeseries
    # load the corresponding timeseries into value clumn
    c1_str = subset(c1, :value => ByRow(x -> isa(x, String) && startswith(x, "ts:")))
    c1_str = load_table_timeser_values(c1_str, directory)

    # only numeric or string values; combine with timeseries
    c1 = subset(c1, :value => ByRow(x -> !(isa(x, String) && startswith(x, "ts:")) ))
    c1 = vcat(c1, c1_str)

    rename!(c1, object1 => :Object1)
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


function readcf2(folder, types)

    cfs = Dict()
    for type in types
        cfs[type] = read_timeseries(folder, type)
    end
    return cfs
end

""""
    Reads a timeseries from CSV as SpineInterface.TimeSeries. The CSV must have a
    "time" column. Several non-timezone-aware formats are accepted. 
    id: timeseries name
    col: column name to be used. default is "value"
"""
function read_timeseries(folder, id, col=nothing)

    #formats = ["yyyy-mm-dd HH:MM:SS", "yyyy-mm-ddTHH:MM:SS"]
    formats = Dict{String, Union{Function, Type}}("yyyy-mm-dd HH:MM:SS" => DateTime, 
        "yyyy-mm-ddTHH:MM:SS" => DateTime,
        "yyyy-mm-ddTHH:MM:SSz" => ZonedDateTime)

    cf_file = joinpath(folder, "ts_" * id * ".csv")
    if !isfile(cf_file)
        println("The file $cf_file does not exist.")
    end

    # read file
    cf = DataFrame(CSV.File(cf_file, missingstring = "NA", types = Dict(:time => String))) 
    
    # convert time column
    for (fmt, fun) in formats
        try
            #cf.time = DateTime.(cf.time, DateFormat(fmt))
            cf.time = fun.(cf.time, DateFormat(fmt))
            break   # if success, exit the loop
        catch e
            if isa(e, ArgumentError) || isa(e, MethodError)
                continue
            else
                rethrow(e)  # Re-throw the exception if it's not the type I expected
            end
        end
    end
    
    #convert to unzoned datetime if needed
    if eltype(cf.time) == ZonedDateTime
        # convert to UTC+1
        cf.time = DateTime.(astimezone.(cf.time, TimeZone("UTC+1")))
    end

    if !isnothing(col)
        return convert_timeseries(cf, col)
    else
        return convert_timeseries(cf)
    end
end


function calc_model_len(modelspecfile)
    #read model info
    df = DataFrame(XLSX.readtable(modelspecfile, "params_1d_datetimes") )
    df.parameter_value = DateTime.(df.parameter_value, DateFormat("yyyy-mm-ddTHH:MM:SS")) 
    wide_df = unstack(df, [:objectclass, :object, :alternative_name], :parameter_name, :parameter_value)
    	
    wide_df = subset(wide_df, :alternative_name => ByRow(==("Base")),
                                :model_start => ByRow(!ismissing), 
                                :model_end => ByRow(!ismissing))
    if isempty(wide_df)
        throw(ArgumentError("Base alternative for model start/end not found."))
    end
        
    wide_df = transform(wide_df, [:model_start, :model_end] => 
        ByRow((x,y) -> convert(Hour, y - x) )
        => :model_length)

    return 	wide_df[1, :model_length]
end

"""
    add_unit_node_param_emission(c0, paramcolsmapping)

    function for adding investment-based emission parameters
"""
function add_unit_node_param_emission(c0, paramcolsmapping)

    c1 = select(c0, :unit, :alternative_name, :emissionnode, collect(keys(paramcolsmapping)))
    rename!(c1, paramcolsmapping)
    rename!(c1, :emissionnode => :basenode)

    return add_unit_node_param(c1, collect(values(paramcolsmapping)) )
end

function add_units_on_temporal_block(c0, temporal_block)
    c1 = unique(select(c0, :unit => :Object1))
    insertcols!(c1, :Object2 => temporal_block)
    insertcols!(c1, 1, :relationshipclass => "units_on__temporal_block")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "temporal_block")
    return c1
end

# just the unit
function add_unit(c0)
    c1 = select(c0, :unit => :Object1)
    insertcols!(c1, 1, :Objectclass1 => "unit")
    return unique(c1)
end

function add_unit_to_node(c0, relclass::String, col::Symbol)
    c1 = select(c0, :unit => :Object1, col => :Object2)
    insertcols!(c1, 1, :relationshipclass => relclass)
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")
    return unique(c1)
end

function add_object_object(c0, relclass::String, oc1, oc2, object1::Symbol, object2::Symbol)
    c1 = select(c0, object1 => :Object1, object2 => :Object2)
    insertcols!(c1, 1, :relationshipclass => relclass)
    insertcols!(c1, 2, :Objectclass1 => oc1)
    insertcols!(c1, 3, :Objectclass2 => oc2)
    return unique(dropmissing(c1))
end

function add_object_object_object(c0, relclass::String, oc1, oc2, oc3, object1::Symbol, object2::Symbol, object3::Symbol)
    c1 = select(c0, object1 => :Object1, object2 => :Object2, object3 => :Object3)
    insertcols!(c1, 1, :relationshipclass => relclass)
    insertcols!(c1, 2, :Objectclass1 => oc1)
    insertcols!(c1, 3, :Objectclass2 => oc2)
    insertcols!(c1, 3, :Objectclass3 => oc3)
    return c1
end

function add_unit_node_node(c0, node1::Symbol, node2::Symbol)
    add_object_object_object(c0, "unit__node__node", "unit", "node", "node", :unit, node1, node2)
end

"""
    augment_basetable(c0, params::Dict{Symbol, Any})

    augment the base alternative rows with new parameters

    `c0`: the input table
    `params`: dictionary of parameter to parameter value
"""
function augment_basetable(c0::DataFrame, params::Dict{Symbol, <:Any})

    c1 = copy(c0)
    for (paramname, val) in params
        c1 = transform(c1, :alternative_name => ByRow(x -> x == "Base" ? val : missing) => paramname)
    end
    return c1
end

function convert_timeseries(x::DataFrame, valcol = :value)
    x.time = DateTime.(x.time)
    y = TimeSeries(x[:,:time], x[:,valcol], false, false)     
end

function tssum(x::TimeSeries)
    return sum(x.values)
end


# Function to rename DataFrame columns based on a dictionary
function rename_columns(df::DataFrame, rename_dict::Dict{Symbol, Symbol})
    for (old_name, new_name) in rename_dict
        if old_name in propertynames(df)
            # if new name already exists, remove it
            if new_name in propertynames(df)
                df = select(df, Not(new_name))
            end
            rename!(df, old_name => new_name)
        end
    end
    return df
end