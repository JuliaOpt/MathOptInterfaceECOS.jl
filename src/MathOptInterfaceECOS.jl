module MathOptInterfaceECOS

export ECOSInstance

using MathOptInterface
const MOI = MathOptInterface
const CI = MOI.ConstraintIndex
const VI = MOI.VariableIndex

using MathOptInterfaceUtilities
const MOIU = MathOptInterfaceUtilities

const SF = Union{MOI.SingleVariable, MOI.ScalarAffineFunction{Float64}, MOI.VectorOfVariables, MOI.VectorAffineFunction{Float64}}
const SS = Union{MOI.EqualTo{Float64}, MOI.GreaterThan{Float64}, MOI.LessThan{Float64}, MOI.Zeros, MOI.Nonnegatives, MOI.Nonpositives, MOI.SecondOrderCone, MOI.ExponentialCone}

using ECOS

include("types.jl")

mutable struct ECOSInstance <: MOI.AbstractSolverInstance
    cone::Cone
    maxsense::Bool
    data::Union{Void, Data} # only non-Void between MOI.copy! and MOI.optimize!
    sol::Solution
    function ECOSInstance()
        new(Cone(), false, nothing, Solution())
    end
end

function MOI.isempty(instance::ECOSInstance)
    !instance.maxsense && instance.data === nothing
end

function MOI.empty!(instance::ECOSInstance)
    instance.maxsense = false
    instance.data = nothing # It should already be nothing except if an error is thrown inside copy!
end

MOI.canaddvariable(instance::ECOSInstance) = false
MOIU.needsallocateload(instance::ECOSInstance) = true
MOI.copy!(dest::ECOSInstance, src::MOI.AbstractInstance) = MOIU.allocateload!(dest, src)

# Implements optimize! : translate data to ECOSData and call ECOS_solve
include("solve.jl")

# Implements getter for result value and statuses
include("attributes.jl")

end # module
