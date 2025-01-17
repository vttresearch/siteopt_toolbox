using ArgParse
using SpineInterface, JSON
using SpinePeriods
using PyCall

# script for creating hp units
#
# Try from command line with
# julia --project=@. conv_hp_units.jl testinputs/hp-input.xlsx 


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "arg1"
            help = "a positional argument: input db"
            required = true
        "arg2"
            help = "a positional argument: repr periods template"
            required = true
        "arg3"
            help = "a positional argument: repr periods settings"
            required = true
        "arg4"
            help = "a positional argument: output db"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()

    select_repr_periods(parsed_args["arg1"], parsed_args["arg2"], parsed_args["arg3"], parsed_args["arg4"])
    return nothing
end

function select_repr_periods(url_in, repr_template, repr_settings, url_out)

    json_out = "output.json" 

     @info "creating augmented DB..."
    loadmodel(url_in, repr_template)
    loadmodel(url_in, repr_settings)
    create_copy_db(url_in, url_out)

    # run SpinePeriods to get the actual repr periods mapping
    run_spine_periods(url_out, json_out, alternative="Base")
    loadmodel(url_out, json_out)
end

function loadmodel(url_in, filename)
    # load data 
    mdict = JSON.parsefile(filename)

    SpineInterface.import_data(url_in, mdict, "testing")
    return url_in
end

function create_copy_db(url_in, url_out)
    input_data = SpineInterface.export_data(url_in)
    SpineInterface.import_data(url_out, input_data, "Copy input db")
    @info "new database copied to $url_out"
end

function remove_entity(db_url)

    py"""
    import spinedb_api as api
    from spinedb_api import DatabaseMapping

    url = "sqlite:///first.sqlite"

    with DatabaseMapping(url, create=True) as db_map:
        # Do something with db_map
        pass
    """
end

main()