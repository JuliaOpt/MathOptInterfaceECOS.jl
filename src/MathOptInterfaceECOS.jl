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

MOIU.@instance ECOSInstanceData () (EqualTo, GreaterThan, LessThan) (Zeros, Nonnegatives, Nonpositives, SecondOrderCone, ExponentialCone) () (SingleVariable,) (ScalarAffineFunction,) (VectorOfVariables,) (VectorAffineFunction,)

using ECOS

include("types.jl")

mutable struct ECOSSolverInstance <: MOI.AbstractSolverInstance
    instancedata::ECOSInstanceData{Float64} # Will be removed when
    idxmap::MOIU.IndexMap                   # InstanceManager is ready
    cone::Cone
    maxsense::Bool
    data::Union{Void, Data} # only non-Void between MOI.copy! and MOI.optimize!
    sol::Solution
    function ECOSSolverInstance()
        new(ECOSInstanceData{Float64}(), MOIU.IndexMap(), Cone(), false, nothing, Solution())
    end
end

function MOI.empty!(instance::ECOSSolverInstance)
    instance.maxsense = false
    instance.data = nothing # It should already be nothing except if an error is thrown inside copy!
end

@bridge SplitInterval MOIU.SplitIntervalBridge () (Interval,) () () () (ScalarAffineFunction,) () ()
@bridge GeoMean MOIU.GeoMeanBridge () () (GeometricMeanCone,) () () () (VectorOfVariables,) (VectorAffineFunction,)

ECOSInstance() = GeoMean{Float64}(SplitInterval{Float64}(ECOSSolverInstance()))

MOI.copy!(dest::ECOSSolverInstance, src::MOI.AbstractInstance) = MOIU.allocateload!(dest, src)

# Redirect data modification calls to data
include("data.jl")

# Implements optimize! : translate data to ECOSData and call ECOS_solve
include("solve.jl")

# Implements getter for result value and statuses
include("attributes.jl")

end # module
