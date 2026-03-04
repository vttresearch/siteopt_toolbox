
using SpineOpt, JSON
using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: template file"
            required = true
        "arg2"
            help = "model database url"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
	mydata = JSON.parsefile(parsed_args["arg1"])
	SpineOpt.import_data(parsed_args["arg2"], mydata, "Load template")
end

main()
