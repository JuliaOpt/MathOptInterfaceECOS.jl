MOI.canget(instance::ECOSSolverInstance, ::MOI.TerminationStatus) = true
function MOI.get(instance::ECOSSolverInstance, ::MOI.TerminationStatus)
    flag = instance.ret_val
    if flag == ECOS.ECOS_OPTIMAL
        MOI.Success
    elseif flag == ECOS.ECOS_PINF
        MOI.Success
    elseif flag == ECOS.ECOS_DINF  # Dual infeasible = primal unbounded, probably
        MOI.Success
    elseif flag == ECOS.ECOS_MAXIT
        MOI.IterationLimit
    elseif flag == ECOS.ECOS_OPTIMAL + ECOS.ECOS_INACC_OFFSET
        m.solve_stat = MOI.AlmostSuccess
    else
        m.solve_stat = MOI.OtherError
    end
end

MOI.canget(instance::ECOSSolverInstance, ::MOI.ObjectiveValue) = true
MOI.get(instance::ECOSSolverInstance, ::MOI.ObjectiveValue) = instance.objval

function MOI.canget(instance::ECOSSolverInstance, ::MOI.PrimalStatus)
    instance.ret_val != ECOS.ECOS_PINF
end
function MOI.get(instance::ECOSSolverInstance, ::MOI.PrimalStatus)
    flag = instance.ret_val
    if flag == ECOS.ECOS_OPTIMAL
        MOI.FeasiblePoint
    elseif flag == ECOS.ECOS_PINF
        MOI.InfeasiblePoint
    elseif flag == ECOS.ECOS_DINF  # Dual infeasible = primal unbounded, probably
        MOI.InfeasibilityCertificate
    elseif flag == ECOS.ECOS_MAXIT
        MOI.UnknownResultStatus
    elseif flag == ECOS.ECOS_OPTIMAL + ECOS.ECOS_INACC_OFFSET
        m.solve_stat = MOI.NearlyFeasiblePoint
    else
        m.solve_stat = MOI.OtherResultStatus
    end
end
# Swapping indices 2 <-> 3 is an involution (it is its own inverse)
const reorderval = orderval
function MOI.canget(instance::ECOSSolverInstance, ::Union{MOI.VariablePrimal, MOI.ConstraintPrimal}, ::MOI.Index)
    instance.ret_val != ECOS.ECOS_PINF
end
function MOI.canget(instance::ECOSSolverInstance, ::Union{MOI.VariablePrimal, MOI.ConstraintPrimal}, ::Vector{<:MOI.Index})
    instance.ret_val != ECOS.ECOS_PINF
end
function MOI.get(instance::ECOSSolverInstance, ::MOI.VariablePrimal, vi::VI)
    instance.primal[instance.varmap[vi]]
end
MOI.get(instance::ECOSSolverInstance, a::MOI.VariablePrimal, vi::Vector{VI}) = MOI.get.(instance, a, vi)
_unshift(value, s) = value
_unshift(value, s::MOI.EqualTo) = value + s.value
_unshift(value, s::MOI.GreaterThan) = value + s.lower
_unshift(value, s::MOI.LessThan) = value + s.upper
function MOI.get(instance::ECOSSolverInstance, ::MOI.ConstraintPrimal, ci::CI{<:MOI.AbstractFunction, MOI.Zeros})
    s = MOI.get(instance, MOI.ConstraintSet(), ci)
    zeros(MOI.dimension(s))
end
function MOI.get(instance::ECOSSolverInstance, ::MOI.ConstraintPrimal, ci::CI{<:MOI.AbstractFunction, <:MOI.EqualTo})
    s = MOI.get(instance, MOI.ConstraintSet(), ci)
    s.value
end
function MOI.get(instance::ECOSSolverInstance, ::MOI.ConstraintPrimal, ci::CI)
    offset = instance.constrmap[ci.value]
    s = MOI.get(instance, MOI.ConstraintSet(), ci)
    rows = constrrows(s)
    _unshift(scalecoef(rows, reorderval(instance.slack[offset + rows], s), false, s, true), s)
end

function MOI.canget(instance::ECOSSolverInstance, ::MOI.DualStatus)
    instance.ret_val != ECOS.ECOS_DINF
end
function MOI.get(instance::ECOSSolverInstance, ::MOI.DualStatus)
    flag = instance.ret_val
    if flag == ECOS.ECOS_OPTIMAL
        MOI.FeasiblePoint
    elseif flag == ECOS.ECOS_PINF
        MOI.InfeasibilityCertificate
    elseif flag == ECOS.ECOS_DINF  # Dual infeasible = primal unbounded, probably
        MOI.InfeasiblePoint
    elseif flag == ECOS.ECOS_MAXIT
        MOI.UnknownResultStatus
    elseif flag == ECOS.ECOS_OPTIMAL + ECOS.ECOS_INACC_OFFSET
        m.solve_stat = MOI.NearlyFeasiblePoint
    else
        m.solve_stat = MOI.OtherResultStatus
    end
end
function MOI.canget(instance::ECOSSolverInstance, ::MOI.ConstraintDual, ::CI)
    instance.ret_val != ECOS.ECOS_DINF
end
_dual(instance, ci::CI{<:MOI.AbstractFunction, <:ZeroCones}) = instance.dual_eq
_dual(instance, ci::CI) = instance.dual_ineq
function MOI.get(instance::ECOSSolverInstance, ::MOI.ConstraintDual, ci::CI)
    offset = instance.constrmap[ci.value]
    s = MOI.get(instance, MOI.ConstraintSet(), ci)
    rows = constrrows(s)
    scalecoef(rows, reorderval(_dual(instance, ci)[offset + rows], s), false, s, true)
end

MOI.canget(instance::ECOSSolverInstance, ::MOI.ResultCount) = true
MOI.get(instance::ECOSSolverInstance, ::MOI.ResultCount) = 1
