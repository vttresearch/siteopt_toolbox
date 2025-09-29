using SpineOpt

m = run_spineopt(ARGS...)

#=
Alternatively, you can customize your run by using the form below.
Keyword arguments are described in https://spine-tools.github.io/SpineOpt.jl/latest/library/#SpineOpt.run_spineopt

m = run_spineopt(
    ARGS...;
    upgrade=false,
    mip_solver=nothing,
    lp_solver=nothing,
    add_user_variables=m -> nothing,
    add_constraints=m -> nothing,
    update_constraints=m -> nothing,
    log_level=3,
    optimize=true,
    update_names=false,
    alternative="",
    write_as_roll=0,
    use_direct_model=false,
    filters=Dict("tool" => "object_activity_control"),
    log_file_path=nothing,
    resume_file_path=nothing
)
=#
