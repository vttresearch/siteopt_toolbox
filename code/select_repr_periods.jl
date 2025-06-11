using Sines_additional
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

"""
    select_repr_periods(url_in, repr_template, repr_settings, url_out)

    This function makes a new database with representative temporal blocks

# Arguments
- `url_in::String`: input DB url.
- `repr_template::String`: file path of representative periods data template JSON
- `repr_settings::String`: file path of representative periods settings JSON


"""
function select_repr_periods(url_in, repr_template, repr_settings, url_out)

    json_out = "output.json" 

    @info "Purgin the old DB..."
    # Call the Python function from Julia
    purge_db = pyimport("__main__").purge_db
    purge_db(url_out)

    @info "Creating DB with representative periods data..."
    create_copy_db(url_in, url_out)

    # Add repr setting data to the DB
    loadmodel_nofilter(url_out, repr_template)
    loadmodel_nofilter(url_out, repr_settings)

    # run SpinePeriods to get the actual repr periods mapping
    run_spine_periods(url_out, json_out, alternative="Base")
    loadmodel_nofilter(url_out, json_out)

    @info "Removing the old temporal block..."
    Sines_additional.remove_entity(url_out, ("myblock",))
end

function create_copy_db(url_in, url_out)
    input_data = SpineInterface.export_data(url_in)
    SpineInterface.import_data(url_out, input_data, "Copy input db")
    @info "new database copied to $url_out"
end

py"""
def purge_db(db_url):
   
    import spinedb_api as api
    from spinedb_api import DatabaseMapping
    from spinedb_api import purge

    # Removes all items of selected types from the database at a given URL.
    purge.purge_url(db_url, None)
    
"""


main()