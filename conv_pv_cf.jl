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
        "arg2"
            help = "a positional argument: capacity factor time series"
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

    add_pv_availability(parsed_args["arg1"], parsed_args["arg2"])
end

function add_pv_availability(pv_file, cf_file)

    #read basic info
    c0 = DataFrame(XLSX.readtable(pv_file, "Sheet1") )
    c0 = transform(c0, [:block_identifier] => ByRow(x->"u_"*string(x)*"_PV") => :unit )

    c1 = select!(c0, :unit => :Object1)

    #read PV CF
    cf = DataFrame(CSV.File(cf_file, dateformat="yyyy-mm-ddTHH:MM", missingstring = "NA") )

    c1 = crossjoin(c1, cf)
    #nomen = unstack(nomen, [:Object1, :time], :Object2, :value)

    insertcols!(c1, 1, :Objectclass1 => "unit")
    insertcols!(c1, 3, :parameter_name => "unit_availability_factor")
    insertcols!(c1, 4, :alternative_name => "Base")

    CSV.write("PV_unit_availability.csv", c1, dateformat="yyyy-mm-ddTHH:MM")

end

#add_pv_availability("testinputs/nomenclature.xlsx", 
#                    "testinputs/pv_dokken.csv")

#from command line run using
#julia --project=@. conv_pv.jl testinputs/nomenclature.xlsx testinputs/pv_dokken.csv

main()

