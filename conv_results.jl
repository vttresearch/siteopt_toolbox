using DataFrames, CSV, XLSX
using ArgParse


# script for creating hp units
#
# Try from command line with
# julia --project=@. conv_hp_units.jl testinputs/hp-input.xlsx 

include("common.jl")
include("db.jl")
include("results.jl")

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "model output database url"
            required = true
        "arg2"
            help = "output recipe file"
            required = true
    end

    return parse_args(s)
end

function main()
    #output file names
    outfile1 = "res1.xlsx"

    parsed_args = parse_commandline()
    conv_results(nothing, parsed_args["arg1"], parsed_args["arg2"])
end


"""
Overall function for adding hp units

    Output: excel tables of hp units
"""
function conv_results(url_in, url_out, recipe_file, output_file = "results.xlsx")


    a = summarizeresults(url_in, url_out, recipe_file, nothing)

    # Storage nodes excel file
    XLSX.writetable(output_file, 
        "Sheet1" => a, 
        overwrite = true
    )
end

main()

