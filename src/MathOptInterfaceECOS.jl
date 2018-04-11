module MathOptInterfaceECOS

export ECOSOptimizer

using MathOptInterface
const MOI = MathOptInterface
const CI = MOI.ConstraintIndex
const VI = MOI.VariableIndex

const MOIU = MOI.Utilities

const SF = Union{MOI.SingleVariable, MOI.ScalarAffineFunction{Float64}, MOI.VectorOfVariables, MOI.VectorAffineFunction{Float64}}
const SS = Union{MOI.EqualTo{Float64}, MOI.GreaterThan{Float64}, MOI.LessThan{Float64}, MOI.Zeros, MOI.Nonnegatives, MOI.Nonpositives, MOI.SecondOrderCone, MOI.ExponentialCone}

using ECOS

include("types.jl")

mutable struct ECOSOptimizer <: MOI.AbstractOptimizer
    cone::Cone
    maxsense::Bool
    data::Union{Void, Data} # only non-Void between MOI.copy! and MOI.optimize!
    sol::Solution
    function ECOSOptimizer()
        new(Cone(), false, nothing, Solution())
    end
end

function MOI.isempty(instance::ECOSOptimizer)
    !instance.maxsense && instance.data === nothing
end

function MOI.empty!(instance::ECOSOptimizer)
    instance.maxsense = false
    instance.data = nothing # It should already be nothing except if an error is thrown inside copy!
end

MOI.canaddvariable(instance::ECOSOptimizer) = false
MOIU.needsallocateload(instance::ECOSOptimizer) = true
MOI.supports(::ECOSOptimizer, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}) = true
MOI.supportsconstraint(::ECOSOptimizer, ::Type{<:SF}, ::Type{<:SS}) = true
MOI.copy!(dest::ECOSOptimizer, src::MOI.ModelLike; copynames=true) = MOIU.allocateload!(dest, src, copynames)

# Implements optimize! : translate data to ECOSData and call ECOS_solve
include("solve.jl")

# Implements getter for result value and statuses
include("attributes.jl")

end # module
