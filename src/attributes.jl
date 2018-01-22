MOI.canget(instance::ECOSInstance, ::MOI.TerminationStatus) = true
function MOI.get(instance::ECOSInstance, ::MOI.TerminationStatus)
    flag = instance.sol.ret_val
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

MOI.canget(instance::ECOSInstance, ::MOI.ObjectiveValue) = true
MOI.get(instance::ECOSInstance, ::MOI.ObjectiveValue) = instance.sol.objval

function MOI.canget(instance::ECOSInstance, ::MOI.PrimalStatus)
    instance.sol.ret_val != ECOS.ECOS_PINF
end
function MOI.get(instance::ECOSInstance, ::MOI.PrimalStatus)
    flag = instance.sol.ret_val
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
function MOI.canget(instance::ECOSInstance, ::Union{MOI.VariablePrimal, MOI.ConstraintPrimal}, ::Type{<:MOI.Index})
    instance.sol.ret_val != ECOS.ECOS_PINF
end
function MOI.get(instance::ECOSInstance, ::MOI.VariablePrimal, vi::VI)
    instance.sol.primal[vi.value]
end
MOI.get(instance::ECOSInstance, a::MOI.VariablePrimal, vi::Vector{VI}) = MOI.get.(instance, a, vi)
setconstant(instance::ECOSInstance, offset, ::CI{<:MOI.AbstractFunction, <:MOI.EqualTo}) = instance.cone.eqsetconstant[offset]
setconstant(instance::ECOSInstance, offset, ::CI) = instance.cone.ineqsetconstant[offset]
_unshift(instance::ECOSInstance, offset, value, ::CI) = value
_unshift(instance::ECOSInstance, offset, value, ci::CI{<:MOI.AbstractScalarFunction, <:MOI.AbstractScalarSet}) = value + setconstant(instance, offset, ci)
function MOI.get(instance::ECOSInstance, ::MOI.ConstraintPrimal, ci::CI{<:MOI.AbstractFunction, MOI.Zeros})
    rows = constrrows(instance, ci)
    zeros(length(rows))
end
function MOI.get(instance::ECOSInstance, ::MOI.ConstraintPrimal, ci::CI{<:MOI.AbstractFunction, <:MOI.EqualTo})
    offset = constroffset(instance, ci)
    setconstant(instance, offset, ci)
end
function MOI.get(instance::ECOSInstance, ::MOI.ConstraintPrimal, ci::CI{<:MOI.AbstractFunction, S}) where S <: MOI.AbstractSet
    offset = constroffset(instance, ci)
    rows = constrrows(instance, ci)
    _unshift(instance, offset, scalecoef(rows, reorderval(instance.sol.slack[offset + rows], S), false, S), ci)
end

function MOI.canget(instance::ECOSInstance, ::MOI.DualStatus)
    instance.sol.ret_val != ECOS.ECOS_DINF
end
function MOI.get(instance::ECOSInstance, ::MOI.DualStatus)
    flag = instance.sol.ret_val
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
function MOI.canget(instance::ECOSInstance, ::MOI.ConstraintDual, ::Type{<:CI})
    instance.sol.ret_val != ECOS.ECOS_DINF
end
_dual(instance, ci::CI{<:MOI.AbstractFunction, <:ZeroCones}) = instance.sol.dual_eq
_dual(instance, ci::CI) = instance.sol.dual_ineq
function MOI.get(instance::ECOSInstance, ::MOI.ConstraintDual, ci::CI{<:MOI.AbstractFunction, S}) where S <: MOI.AbstractSet
    offset = constroffset(instance, ci)
    rows = constrrows(instance, ci)
    scalecoef(rows, reorderval(_dual(instance, ci)[offset + rows], S), false, S)
end

MOI.canget(instance::ECOSInstance, ::MOI.ResultCount) = true
MOI.get(instance::ECOSInstance, ::MOI.ResultCount) = 1
