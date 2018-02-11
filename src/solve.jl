using Compat.SparseArrays

const ZeroCones = Union{MOI.EqualTo, MOI.Zeros}
const LPCones = Union{MOI.GreaterThan, MOI.LessThan, MOI.Nonnegatives, MOI.Nonpositives}

_dim(s::MOI.AbstractScalarSet) = 1
_dim(s::MOI.AbstractVectorSet) = MOI.dimension(s)

# Computes cone dimensions
constroffset(cone::Cone, ci::CI{<:MOI.AbstractFunction, <:ZeroCones}) = ci.value
function _allocateconstraint!(cone::Cone, f, s::ZeroCones)
    ci = cone.f
    cone.f += _dim(s)
    ci
end
constroffset(cone::Cone, ci::CI{<:MOI.AbstractFunction, <:LPCones}) = ci.value
function _allocateconstraint!(cone::Cone, f, s::LPCones)
    ci = cone.l
    cone.l += _dim(s)
    ci
end
constroffset(cone::Cone, ci::CI{<:MOI.AbstractFunction, <:MOI.SecondOrderCone}) = cone.l + ci.value
function _allocateconstraint!(cone::Cone, f, s::MOI.SecondOrderCone)
    push!(cone.qa, s.dimension)
    ci = cone.q
    cone.q += _dim(s)
    ci
end
constroffset(cone::Cone, ci::CI{<:MOI.AbstractFunction, <:MOI.ExponentialCone}) = cone.l + cone.q + ci.value
function _allocateconstraint!(cone::Cone, f, s::MOI.ExponentialCone)
    ci = 3cone.ep
    cone.ep += 1
    ci
end
constroffset(instance::ECOSInstance, ci::CI) = constroffset(instance.cone, ci::CI)
MOIU.canallocateconstraint(::ECOSInstance, ::Type{<:SF}, ::Type{<:SS}) = true
function MOIU.allocateconstraint!(instance::ECOSInstance, f::F, s::S) where {F <: MOI.AbstractFunction, S <: MOI.AbstractSet}
    CI{F, S}(_allocateconstraint!(instance.cone, f, s))
end


# Build constraint matrix
scalecoef(rows, coef, minus, s) = minus ? -coef : coef
scalecoef(rows, coef, minus, s::Union{MOI.LessThan, Type{<:MOI.LessThan}, MOI.Nonpositives, Type{MOI.Nonpositives}}) = minus ? coef : -coef
_varmap(f) = map(vi -> vi.value, f.variables)
_constant(s::MOI.EqualTo) = s.value
_constant(s::MOI.GreaterThan) = s.lower
_constant(s::MOI.LessThan) = s.upper
constrrows(::MOI.AbstractScalarSet) = 1
constrrows(s::MOI.AbstractVectorSet) = 1:MOI.dimension(s)
constrrows(instance::ECOSInstance, ci::CI{<:MOI.AbstractScalarFunction, <:MOI.AbstractScalarSet}) = 1
constrrows(instance::ECOSInstance, ci::CI{<:MOI.AbstractVectorFunction, MOI.Zeros}) = 1:instance.cone.eqnrows[constroffset(instance, ci)]
constrrows(instance::ECOSInstance, ci::CI{<:MOI.AbstractVectorFunction, <:MOI.AbstractVectorSet}) = 1:instance.cone.ineqnrows[constroffset(instance, ci)]
matrix(data::Data, s::ZeroCones) = data.b, data.IA, data.JA, data.VA
matrix(data::Data, s::Union{LPCones, MOI.SecondOrderCone, MOI.ExponentialCone}) = data.h, data.IG, data.JG, data.VG
matrix(instance::ECOSInstance, s) = matrix(instance.data, s)
MOIU.canloadconstraint(::ECOSInstance, ::Type{<:SF}, ::Type{<:SS}) = true
MOIU.loadconstraint!(instance::ECOSInstance, ci, f::MOI.SingleVariable, s) = MOIU.loadconstraint!(instance, ci, MOI.ScalarAffineFunction{Float64}(f), s)
function MOIU.loadconstraint!(instance::ECOSInstance, ci, f::MOI.ScalarAffineFunction, s::MOI.AbstractScalarSet)
    a = sparsevec(_varmap(f), f.coefficients)
    # sparsevec combines duplicates with + but does not remove zeros created so we call dropzeros!
    dropzeros!(a)
    offset = constroffset(instance, ci)
    row = constrrows(s)
    i = offset + row
    # The ECOS format is b - Ax ∈ cone
    # so minus=false for b and minus=true for A
    setconstant = _constant(s)
    if s isa MOI.EqualTo
        instance.cone.eqsetconstant[offset] = setconstant
    else
        instance.cone.ineqsetconstant[offset] = setconstant
    end
    constant = f.constant - setconstant
    b, I, J, V = matrix(instance, s)
    b[i] = scalecoef(row, constant, false, s)
    append!(I, fill(i, length(a.nzind)))
    append!(J, a.nzind)
    append!(V, scalecoef(row, a.nzval, true, s))
end
MOIU.loadconstraint!(instance::ECOSInstance, ci, f::MOI.VectorOfVariables, s) = MOIU.loadconstraint!(instance, ci, MOI.VectorAffineFunction{Float64}(f), s)
# SCS orders differently than MOI the second and third dimension of the exponential cone
orderval(val, s) = val
function orderval(val, s::Union{MOI.ExponentialCone, Type{MOI.ExponentialCone}})
    val[[1, 3, 2]]
end
orderidx(idx, s) = idx
expmap(i) = (1, 3, 2)[i]
function orderidx(idx, s::MOI.ExponentialCone)
    expmap.(idx)
end
function MOIU.loadconstraint!(instance::ECOSInstance, ci, f::MOI.VectorAffineFunction, s::MOI.AbstractVectorSet)
    A = sparse(f.outputindex, _varmap(f), f.coefficients)
    # sparse combines duplicates with + but does not remove zeros created so we call dropzeros!
    dropzeros!(A)
    colval = zeros(Int, length(A.rowval))
    for col in 1:A.n
        colval[A.colptr[col]:(A.colptr[col+1]-1)] = col
    end
    @assert !any(iszero.(colval))
    offset = constroffset(instance, ci)
    rows = constrrows(s)
    if s isa MOI.Zeros
        instance.cone.eqnrows[offset] = length(rows)
    else
        instance.cone.ineqnrows[offset] = length(rows)
    end
    i = offset + rows
    # The ECOS format is b - Ax ∈ cone
    # so minus=false for b and minus=true for A
    b, I, J, V = matrix(instance, s)
    b[i] = scalecoef(rows, orderval(f.constant, s), false, s)
    append!(I, offset + orderidx(A.rowval, s))
    append!(J, colval)
    append!(V, scalecoef(A.rowval, A.nzval, true, s))
end

function MOIU.allocatevariables!(instance::ECOSInstance, nvars::Integer)
    instance.cone = Cone()
    VI.(1:nvars)
end

function MOIU.loadvariables!(instance::ECOSInstance, nvars::Integer)
    cone = instance.cone
    m = cone.l + cone.q + 3cone.ep
    IA = Int[]
    JA = Int[]
    VA = Float64[]
    b = zeros(cone.f)
    IG = Int[]
    JG = Int[]
    VG = Float64[]
    h = zeros(m)
    c = zeros(nvars)
    instance.data = Data(m, nvars, IA, JA, VA, b, IG, JG, VG, h, 0., c)
end

MOIU.canallocate(::ECOSInstance, ::MOI.ObjectiveSense) = true
function MOIU.allocate!(instance::ECOSInstance, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    instance.maxsense = sense == MOI.MaxSense
end
MOIU.canallocate(::ECOSInstance, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}) = true
function MOIU.allocate!(::ECOSInstance, ::MOI.ObjectiveFunction, ::MOI.ScalarAffineFunction) end

MOIU.canload(::ECOSInstance, ::MOI.ObjectiveSense) = true
function MOIU.load!(::ECOSInstance, ::MOI.ObjectiveSense, ::MOI.OptimizationSense) end
MOIU.canload(::ECOSInstance, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}) = true
function MOIU.load!(instance::ECOSInstance, ::MOI.ObjectiveFunction, f::MOI.ScalarAffineFunction)
    c0 = full(sparsevec(_varmap(f), f.coefficients, instance.data.n))
    instance.data.objconstant = f.constant
    instance.data.c = instance.maxsense ? -c0 : c0
end

function MOI.optimize!(instance::ECOSInstance)
    cone = instance.cone
    m = instance.data.m
    n = instance.data.n
    A = ECOS.ECOSMatrix(sparse(instance.data.IA, instance.data.JA, instance.data.VA, cone.f, n))
    b = instance.data.b
    G = ECOS.ECOSMatrix(sparse(instance.data.IG, instance.data.JG, instance.data.VG, m, n))
    h = instance.data.h
    objconstant = instance.data.objconstant
    c = instance.data.c
    instance.data = nothing # Allows GC to free instance.data before A is loaded to ECOS
    ecos_prob_ptr = ECOS.setup(n, m, cone.f, cone.l, length(cone.qa), cone.qa, cone.ep, G, A, c, h, b)
    ret_val = ECOS.solve(ecos_prob_ptr)
    ecos_prob = unsafe_wrap(Array, ecos_prob_ptr, 1)[1]
    primal    = unsafe_wrap(Array, ecos_prob.x, n)[:]
    dual_eq   = unsafe_wrap(Array, ecos_prob.y, cone.f)[:]
    dual_ineq = unsafe_wrap(Array, ecos_prob.z, m)[:]
    slack     = unsafe_wrap(Array, ecos_prob.s, m)[:]
    ECOS.cleanup(ecos_prob_ptr, 0)
    objval = (instance.maxsense ? -1 : 1) * dot(c, primal) + objconstant
    instance.sol = Solution(ret_val, primal, dual_eq, dual_ineq, slack, objval)
end
