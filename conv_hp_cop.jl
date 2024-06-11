using DataFrames, CSV, XLSX
using ArgParse

# script for creating PV units
#
# Try from command line with
# julia --project=@. conv_hp_cop.jl testinputs/hp-input.xlsx testinputs/hp-cop-toolbox.xlsx 


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
            help = "a positional argument: hp units table"
            required = true
        "arg2"
            help = "a positional argument: cop time series"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()

    add_hp_cop_timeseries(parsed_args["arg1"], parsed_args["arg2"])
end

function add_hp_cop_timeseries(hp_file, cop_file)

    #read basic info
    c0 = DataFrame(XLSX.readtable(hp_file, "Sheet1") )
    c0 = subset(c0, :cop_profile => ByRow(!ismissing))

    # prepare unit and node names
    c0 = transform(c0, [:block_identifier] => ByRow(x->"u_"*string(x)*"_hp") => :unit )
    c0 = transform(c0, [:block_identifier] => ByRow(x->"n_"*string(x)*"_elec") => :inputnode )
    c0 = transform(c0, [:block_identifier] => ByRow(x->"n_"*string(x)*"_dheat") => :outputnode )

    c1 = select(c0, :unit => :Object1, 
                    :outputnode => :Object2, 
                    :inputnode => :Object3,
                    :cop_profile)

    #read HP cop estimates
    cf = DataFrame(XLSX.readtable(cop_file, "Sheet1") )

    # join COP with unit table
    c1 = innerjoin(c1, cf, on = :cop_profile)

    insertcols!(c1, 1, :relationshipclass => "unit__node__node")
    insertcols!(c1, 2, :Objectclass1 => "unit")
    insertcols!(c1, 3, :Objectclass2 => "node")
    insertcols!(c1, 4, :Objectclass3 => "node")

    insertcols!(c1, 9, :parameter_name => "fix_ratio_out_in_unit_flow")
    insertcols!(c1, 10, :alternative_name => "Base")

    # remove the cop profile field
    select!(c1, Not(:cop_profile))

    CSV.write("hp_cop.csv", c1, dateformat="yyyy-mm-ddTHH:MM")

end


main()

