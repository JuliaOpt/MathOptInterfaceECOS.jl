const ZeroCones = Union{MOI.EqualTo, MOI.Zeros}
const LPCones = Union{MOI.GreaterThan, MOI.LessThan, MOI.Nonnegatives, MOI.Nonpositives}

_dim(s::MOI.AbstractScalarSet) = 1
_dim(s::MOI.AbstractVectorSet) = MOI.dimension(s)

mutable struct Cone
    f::Int # number of linear equality constraints
    fcur::Int
    l::Int # length of LP cone
    lcur::Int
    q::Int # length of SOC cone
    qcur::Int
    qa::Vector{Int} # array of second-order cone constraints
    function Cone()
        new(0, 0, 0, 0, 0, 0, Int[])
    end
end

# Computes cone dimensions
constrcall(cone::Cone, ci, f, s::ZeroCones) = cone.f += _dim(s)
constrcall(cone::Cone, ci, f, s::LPCones) = cone.l += _dim(s)
function constrcall(cone::Cone, ci, f, s::MOI.SecondOrderCone)
    push!(cone.qa, s.dimension)
    cone.q += _dim(s)
end

# Fill constrmap
function constrcall(cone::Cone, constrmap::Dict, ci, f, s::ZeroCones)
    constrmap[ci.value] = cone.fcur
    cone.fcur += _dim(s)
end
function constrcall(cone::Cone, constrmap::Dict, ci, f, s::LPCones)
    constrmap[ci.value] = cone.lcur
    cone.lcur += _dim(s)
end
function constrcall(cone::Cone, constrmap::Dict, ci, f, s::MOI.SecondOrderCone)
    constrmap[ci.value] = cone.l + cone.qcur
    cone.qcur += _dim(s)
end

# Vectorized length for matrix dimension n

# Build constraint matrix
scalecoef(rows, coef, minus, s, rev) = minus ? -coef : coef
scalecoef(rows, coef, minus, s::Union{MOI.LessThan, MOI.Nonpositives}, rev) = minus ? coef : -coef
_varmap(varmap, f) = map(vi -> varmap[vi], f.variables)
_constant(s::MOI.EqualTo) = s.value
_constant(s::MOI.GreaterThan) = s.lower
_constant(s::MOI.LessThan) = s.upper
constrrows(::MOI.AbstractScalarSet) = 1
constrrows(s::MOI.AbstractVectorSet) = 1:MOI.dimension(s)
relevantmatrix(eq::Type{Val{false}}, s::ZeroCones) = false
relevantmatrix(eq::Type{Val{true}}, s::ZeroCones) = true
relevantmatrix(eq::Type{Val{false}}, s::Union{LPCones, MOI.SecondOrderCone}) = true
relevantmatrix(eq::Type{Val{true}}, s::Union{LPCones, MOI.SecondOrderCone}) = false
constrcall(eq, I, J, V, b, varmap, constrmap, ci, f::MOI.SingleVariable, s) = constrcall(eq, I, J, V, b, varmap, constrmap, ci, MOI.ScalarAffineFunction{Float64}(f), s)
function constrcall(eq, I, J, V, b, varmap::Dict, constrmap::Dict, ci, f::MOI.ScalarAffineFunction, s)
    relevantmatrix(eq, s) || return
    a = sparsevec(_varmap(varmap, f), f.coefficients)
    # sparsevec combines duplicates with + but does not remove zeros created so we call dropzeros!
    dropzeros!(a)
    offset = constrmap[ci.value]
    row = constrrows(s)
    i = offset + row
    # The ECOS format is b - Ax ∈ cone
    # so minus=false for b and minus=true for A
    constant = f.constant - _constant(s)
    b[i] = scalecoef(row, constant, false, s, false)
    append!(I, fill(i, length(a.nzind)))
    append!(J, a.nzind)
    append!(V, scalecoef(row, a.nzval, true, s, false))
end
constrcall(eq, I, J, V, b, varmap, constrmap, ci, f::MOI.VectorOfVariables, s) = constrcall(eq, I, J, V, b, varmap, constrmap, ci, MOI.VectorAffineFunction{Float64}(f), s)
function constrcall(eq, I, J, V, b, varmap::Dict, constrmap::Dict, ci, f::MOI.VectorAffineFunction, s)
    relevantmatrix(eq, s) || return
    A = sparse(f.outputindex, _varmap(varmap, f), f.coefficients)
    # sparse combines duplicates with + but does not remove zeros created so we call dropzeros!
    dropzeros!(A)
    colval = zeros(Int, length(A.rowval))
    for col in 1:A.n
        colval[A.colptr[col]:(A.colptr[col+1]-1)] = col
    end
    @assert !any(iszero.(colval))
    offset = constrmap[ci.value]
    rows = constrrows(s)
    i = offset + rows
    # The ECOS format is b - Ax ∈ cone
    # so minus=false for b and minus=true for A
    b[i] = scalecoef(rows, f.constant, false, s, false)
    append!(I, offset + A.rowval)
    append!(J, colval)
    append!(V, scalecoef(A.rowval, A.nzval, true, s, false))
end

function constrcall(arg::Tuple, constrs::Vector)
    for constr in constrs
        constrcall(arg..., constr...)
    end
end
function MOI.optimize!(instance::ECOSSolverInstance)
    cone = Cone()
    MOIU.broadcastcall(constrs -> constrcall((cone,), constrs), instance.data)
    instance.constrmap = Dict{UInt64, Int}()
    MOIU.broadcastcall(constrs -> constrcall((cone, instance.constrmap), constrs), instance.data)
    vcur = 0
    instance.varmap = Dict{VI, Int}()
    for vi in MOI.get(instance.data, MOI.ListOfVariableIndices())
        vcur += 1
        instance.varmap[vi] = vcur
    end
    @assert vcur == MOI.get(instance.data, MOI.NumberOfVariables())
    m = cone.l + cone.q
    n = vcur
    IA = Int[]
    JA = Int[]
    VA = Float64[]
    b = zeros(cone.f)
    MOIU.broadcastcall(constrs -> constrcall((Val{true}, IA, JA, VA, b, instance.varmap, instance.constrmap), constrs), instance.data)
    A = sparse(IA, JA, VA, cone.f, n)
    IG = Int[]
    JG = Int[]
    VG = Float64[]
    h = zeros(m)
    MOIU.broadcastcall(constrs -> constrcall((Val{false}, IG, JG, VG, h, instance.varmap, instance.constrmap), constrs), instance.data)
    G = sparse(IG, JG, VG, m, n)
    f = MOI.get(instance.data, MOI.ObjectiveFunction())
    c0 = full(sparsevec(_varmap(instance.varmap, f), f.coefficients, n))
    c = MOI.get(instance.data, MOI.ObjectiveSense()) == MOI.MaxSense ? -c0 : c0
    # FIXME MPB wrapper is doing c[:]
    ecos_prob_ptr = ECOS.setup(n, m, cone.f, cone.l, length(cone.qa), cone.qa, 0, G, A, c[:], h, b)
    instance.ret_val = ECOS.solve(ecos_prob_ptr)
    ecos_prob = unsafe_wrap(Array, ecos_prob_ptr, 1)[1]
    instance.primal    = unsafe_wrap(Array, ecos_prob.x, n)[:]
    instance.dual_eq   = unsafe_wrap(Array, ecos_prob.y, cone.f)[:]
    instance.dual_ineq = unsafe_wrap(Array, ecos_prob.z, m)[:]
    instance.slack     = unsafe_wrap(Array, ecos_prob.s, m)[:]
    ECOS.cleanup(ecos_prob_ptr, 0)
    instance.objval = dot(c0, instance.primal) + f.constant
end
