using DataFrames, CSV
using ArgParse


# script for creating PV units
#
# Try from command line with
# julia --project=@. conv_wide_objpar.jl testinputs/wide-load.csv testinputs/wide-load2.csv 


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            nargs = '*'  # eats up as many arguments as possible 
            default = Any["no_arg_given"]
            help = "the parameter data files in wide format"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    for filename in parsed_args["arg1"]
        add_wide_objpar(filename)
    end
end

function add_wide_objpar(filename::String)

        
    if !isfile(filename)
        println("The file $filenamedoes not exist.")
    end
    cf = DataFrame(CSV.File(filename, dateformat="yyyy-mm-ddTHH:MM", missingstring = "NA") )

    #TBA

end

main()