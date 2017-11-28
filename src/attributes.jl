MOI.canget(instance::ECOSSolverInstance, ::MOI.TerminationStatus) = true
function MOI.get(instance::ECOSSolverInstance, ::MOI.TerminationStatus)
    flag = instance.ret_val
    if flag == ECOS_OPTIMAL
        MOI.Success
    elseif flag == ECOS_PINF
        MOI.Success
    elseif flag == ECOS_DINF  # Dual infeasible = primal unbounded, probably
        MOI.Success
    elseif flag == ECOS_MAXIT
        MOI.IterationLimit
    elseif flag == ECOS_OPTIMAL + ECOS_INACC_OFFSET
        m.solve_stat = MOI.AlmostSuccess
    else
        m.solve_stat = MOI.OtherError
    end
end

MOI.canget(instance::ECOSSolverInstance, ::MOI.ObjectiveValue) = true
MOI.get(instance::ECOSSolverInstance, ::MOI.ObjectiveValue) = instance.objval

function MOI.canget(instance::ECOSSolverInstance, ::MOI.PrimalStatus)
    instance.ret_val != ECOS_PINF
end
function MOI.get(instance::ECOSSolverInstance, ::MOI.PrimalStatus)
    flag = instance.ret_val
    if flag == ECOS_OPTIMAL
        MOI.FeasiblePoint
    elseif flag == ECOS_PINF
        MOI.InfeasiblePoint
    elseif flag == ECOS_DINF  # Dual infeasible = primal unbounded, probably
        MOI.InfeasibilityCertificate
    elseif flag == ECOS_MAXIT
        MOI.UnknownResultStatus
    elseif flag == ECOS_OPTIMAL + ECOS_INACC_OFFSET
        m.solve_stat = MOI.NearlyFeasiblePoint
    else
        m.solve_stat = MOI.OtherResultStatus
    end
end
function MOI.canget(instance::ECOSSolverInstance, ::Union{MOI.VariablePrimal, MOI.ConstraintPrimal}, r::MOI.AnyReference)
    instance.ret_val != ECOS_PINF
end
function MOI.canget(instance::ECOSSolverInstance, ::Union{MOI.VariablePrimal, MOI.ConstraintPrimal}, r::Vector{<:MOI.AnyReference})
    instance.ret_val != ECOS_PINF
end
function MOI.get(instance::ECOSSolverInstance, ::MOI.VariablePrimal, vr::VR)
    instance.primal[instance.varmap[vr]]
end
MOI.get(instance::ECOSSolverInstance, a::MOI.VariablePrimal, vr::Vector{VR}) = MOI.get.(instance, a, vr)
_unshift(value, s) = value
_unshift(value, s::MOI.EqualTo) = value + s.value
_unshift(value, s::MOI.GreaterThan) = value + s.lower
_unshift(value, s::MOI.LessThan) = value + s.upper
function MOI.get(instance::ECOSSolverInstance, ::MOI.ConstraintPrimal, cr::CR{<:MOI.AbstractFunction, <:ZeroCones})
    s = MOI.get(instance, MOI.ConstraintSet(), cr)
    zeros(_dimension(s))
end
function MOI.get(instance::ECOSSolverInstance, ::MOI.ConstraintPrimal, cr::CR)
    offset = instance.constrmap[cr.value]
    s = MOI.get(instance, MOI.ConstraintSet(), cr)
    rows = constrrows(s)
    _unshift(scalecoef(rows, instance.slack[offset + rows], false, s, true), s)
end

function MOI.canget(instance::ECOSSolverInstance, ::MOI.DualStatus)
    instance.ret_val != ECOS_DINF
end
function MOI.get(instance::ECOSSolverInstance, ::MOI.DualStatus)
    flag = instance.ret_val
    if flag == ECOS_OPTIMAL
        MOI.FeasiblePoint
    elseif flag == ECOS_PINF
        MOI.InfeasibilityCertificate
    elseif flag == ECOS_DINF  # Dual infeasible = primal unbounded, probably
        MOI.InfeasiblePoint
    elseif flag == ECOS_MAXIT
        MOI.UnknownResultStatus
    elseif flag == ECOS_OPTIMAL + ECOS_INACC_OFFSET
        m.solve_stat = MOI.NearlyFeasiblePoint
    else
        m.solve_stat = MOI.OtherResultStatus
    end
end
function MOI.canget(instance::ECOSSolverInstance, ::MOI.ConstraintDual, ::CR)
    instance.ret_val != ECOS_DINF
end
_dual(instance, cr::CR{<:MOI.AbstractFunction, <:ZeroCones}) = instance.dual_eq
_dual(instance, cr::CR) = instance.dual_ineq
function MOI.get(instance::ECOSSolverInstance, ::MOI.ConstraintDual, cr::CR)
    offset = instance.constrmap[cr.value]
    s = MOI.get(instance, MOI.ConstraintSet(), cr)
    rows = constrrows(s)
    scalecoef(rows, _dual(instance, cr)[offset + rows], false, s, true)
end

MOI.canget(instance::ECOSSolverInstance, ::MOI.ResultCount) = true
MOI.get(instance::ECOSSolverInstance, ::MOI.ResultCount) = 1
