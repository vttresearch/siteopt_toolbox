using DataFrames, CSV, XLSX
using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--opt1"
            help = "an option with an argument"
        "--opt2", "-o"
            help = "another option with an argument"
            arg_type = Int
            default = 0
        "--flag1"
            help = "an option without argument, i.e. a flag"
            action = :store_true
        "arg1"
            help = "a positional argument: pv units table"
            required = true
    
    end

    return parse_args(s)
end

"""
arg1: PV units input file
arg2: PV capa factor timeseries as CSV file
"""
function main()
    parsed_args = parse_commandline()

    add_pv_availability(parsed_args["arg1"])
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

    return cf0
end

function add_pv_availability(pv_file)

    #read basic info
    c0 = DataFrame(XLSX.readtable(pv_file, "Sheet1") )
    c0 = transform(c0, [:block_identifier, :type] => ByRow((x,y)->"u_"*string(x)*"_"*string(y)) => :unit )
    
    c1 = select!(c0, :unit => :Object1, :type)

    #read PV CF
    types = unique(c0[:,:type])
    cf = readcf(dirname(pv_file), types)

    # assign the cf time series for all units
    c1 = innerjoin(c1, cf, on = :type)
    c1 = select(c1, :Object1, :time, :value)
    println(first(c1,6))

    #nomen = unstack(nomen, [:Object1, :time], :Object2, :value)

    insertcols!(c1, 1, :Objectclass1 => "unit")
    insertcols!(c1, 3, :parameter_name => "unit_availability_factor")
    insertcols!(c1, 4, :alternative_name => "Base")

    CSV.write("PV_unit_availability.csv", c1, dateformat="yyyy-mm-ddTHH:MM")
end

#add_pv_availability("testinputs/nomenclature.xlsx", 
#                    "testinputs/pv_dokken.csv")

#from command line run using
#julia --project=@. conv_pv_cf.jl ../inputs/dokken/production/pv-input.xlsx

main()

