export _run_vstab, _run_multi_vstab, _run_vstab_limq

# mutable struct VDPowerModel <: _PM.AbstractACModel _PM.@pm_fields end

"""
run model for Voltge-Deviation objective with AC Power Flow equations
"""

function _run_vstab(file, model_type::_PM.Type, optimizer; kwargs...)
    return _PM.solve_model(file, model_type, optimizer, _build_vstab; kwargs...)
end

"""
given a JuMP model and a PowerModels network data structure,
builds an Voltge-Deviation formulation of the given data and returns the JuMP model
"""

function _build_vstab(pm::_PM.AbstractPowerModel)

    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PM.variable_dcline_power(pm, bounded = false) # TODO: why false?


    objective_vstab(pm)

    _PM.constraint_model_voltage(pm)

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        _PM.constraint_power_balance(pm, i)
    end

    for (i, branch) in _PM.ref(pm, :branch)
        _PM.constraint_ohms_yt_from(pm, i)
        _PM.constraint_ohms_yt_to(pm, i)

        _PM.constraint_thermal_limit_from(pm, i)
        _PM.constraint_thermal_limit_to(pm, i)
    end

    for i in _PM.ids(pm, :dcline)
        _PM.constraint_dcline_power_losses(pm, i)
    end
end

function objective_vstab_debug(pm::_PM.AbstractPowerModel)
    # my_case = pm.ref
    # println(pm.ref[:it])
    # println("#####################################################################")
    # println(pm.ref[:it][:pm][:nw][0][:gen])
    # println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    # open("pm_test999.json","w") do f
    #     JSON.print(f, pm.ref)
    # end
    #       sum((var(pm, :qg, i))^2 for (i, content) in pm.ref[:it][:pm][:nw][0][:gen]))
    fac1 = 0.9
    fac2 = 1-fac1
    return JuMP.@objective(pm.model, Max,
       # fac1*sum((var(pm, :vm, content["element_index"]) - content["value"])^2 for (i, content) in pm.ext[:setpoint_v]) +
       sum((var(pm, :qg, content)-0)^2 for (i, content) in pm.ext[:gen_and_controllable_sgen]))
end


function objective_vstab(pm::_PM.AbstractPowerModel)
    return JuMP.@objective(pm.model, Min,
       sum((var(pm, :vm, content["element_index"]) - content["value"])^2 for (i, content) in pm.ext[:setpoint_v]))
end

"""
run model for Voltge-Deviation objective with AC Power Flow equations
"""

function _run_multi_vstab(file, model_type::_PM.Type, optimizer; kwargs...)
    return _PM.solve_model(file, model_type, optimizer, _build_multi_vstab; multinetwork=true, kwargs...)
end

"""
given a JuMP model and a PowerModels network data structure,
builds an Voltge-Deviation formulation of the given data and returns the JuMP model
"""

function _build_multi_vstab(pm::_PM.AbstractPowerModel)
    for (n, network) in _PM.nws(pm)
            _PM.variable_bus_voltage(pm, nw=n)
            _PM.variable_gen_power(pm, nw=n)
            _PM.variable_branch_power(pm, nw=n)
            _PM.variable_dcline_power(pm, nw=n)

            _PM.constraint_model_voltage(pm, nw=n)

            for i in ids(pm, :ref_buses, nw=n)
                _PM.constraint_theta_ref(pm, i, nw=n)
            end

            for i in ids(pm, :bus, nw=n)
                _PM.constraint_power_balance(pm, i, nw=n)
            end

            for i in ids(pm, :branch, nw=n)
                _PM.constraint_ohms_yt_from(pm, i, nw=n)
                _PM.constraint_ohms_yt_to(pm, i, nw=n)

                _PM.constraint_voltage_angle_difference(pm, i, nw=n)

                _PM.constraint_thermal_limit_from(pm, i, nw=n)
                _PM.constraint_thermal_limit_to(pm, i, nw=n)
            end

            for i in ids(pm, :dcline, nw=n)
                _PM.constraint_dcline_power_losses(pm, i, nw=n)
            end
        end
        objective_multi_vstab(pm)
end

function objective_multi_vstab(pm::_PM.AbstractPowerModel)
    timestep_ids = [id for id in _PM.nw_ids(pm) if id != 0]
    return JuMP.@objective(pm.model, Min,
        sum(
        sum((var(pm, nw, :vm, content["element_index"]) - content["value"])^2 for (i, content) in pm.ext[:setpoint_v])
        for nw in timestep_ids)
            )
end


function _run_vstab_limq(file, model_type::_PM.Type, optimizer; kwargs...)
    return _PM.solve_model(file, model_type, optimizer, _build_vstab_limq; kwargs...)
end

"""
given a JuMP model and a PowerModels network data structure,
builds an "maintainig voltage setpoints" formulation with limited reactive power
based on the given data and returns the JuMP model
"""

function _build_vstab_limq(pm::_PM.AbstractPowerModel)

    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PM.variable_dcline_power(pm, bounded = false) # TODO: why false?


    objective_vstab_limq(pm)

    _PM.constraint_model_voltage(pm)

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        _PM.constraint_power_balance(pm, i)
    end

    for (i, branch) in _PM.ref(pm, :branch)
        _PM.constraint_ohms_yt_from(pm, i)
        _PM.constraint_ohms_yt_to(pm, i)

        _PM.constraint_thermal_limit_from(pm, i)
        _PM.constraint_thermal_limit_to(pm, i)
    end

    for i in _PM.ids(pm, :dcline)
        _PM.constraint_dcline_power_losses(pm, i)
    end
end

function objective_vstab_limq(pm::_PM.AbstractPowerModel)

    if haskey(pm.ext, :obj_factors)
        if length(pm.ext[:obj_factors]) == 2
            fac1 = pm.ext[:obj_factors]["fac_1"]
            fac2 = pm.ext[:obj_factors]["fac_2"]
        end
    else
        fac1 = 0.8
        fac2 = 1-fac1
    end

    return JuMP.@objective(pm.model, Min,
       fac1 * sum((var(pm, :vm, content["element_index"]) - content["value"])^2 for (i, content) in pm.ext[:setpoint_v])
       +
       fac2 * sum((var(pm, :qg, content)-0)^2 for (i, content) in pm.ext[:gen_and_controllable_sgen]))
end
