module MathOptInterfaceECOS

export ECOSInstance

using MathOptInterface
const MOI = MathOptInterface
const CI = MOI.ConstraintIndex
const VI = MOI.VariableIndex

using MathOptInterfaceUtilities
const MOIU = MathOptInterfaceUtilities

MOIU.@instance ECOSInstanceData () (EqualTo, GreaterThan, LessThan) (Zeros, Nonnegatives, Nonpositives, SecondOrderCone) () (SingleVariable,) (ScalarAffineFunction,) (VectorOfVariables,) (VectorAffineFunction,)

using ECOS

mutable struct ECOSSolverInstance <: MOI.AbstractSolverInstance
    data::ECOSInstanceData{Float64}
    varmap::Dict{VI, Int}
    constrmap::Dict{Int64, Int}
    ret_val::Int
    primal::Vector{Float64}
    dual_eq::Vector{Float64}
    dual_ineq::Vector{Float64}
    slack::Vector{Float64}
    objval::Float64
    function ECOSSolverInstance()
        new(ECOSInstanceData{Float64}(), Dict{VI, Int}(), Dict{Int64, Int}(), 1, Float64[], Float64[], Float64[], Float64[], 0.)
    end
end

@bridge SplitInterval MOIU.SplitIntervalBridge () (Interval,) () () () (ScalarAffineFunction,) () ()
@bridge GeoMean MOIU.GeoMeanBridge () () (GeometricMeanCone,) () () () (VectorOfVariables,) (VectorAffineFunction,)

ECOSInstance() = GeoMean{Float64}(SplitInterval{Float64}(ECOSSolverInstance()))

# Redirect data modification calls to data
include("data.jl")

# Implements optimize! : translate data to ECOSData and call ECOS_solve
include("solve.jl")

# Implements getter for result value and statuses
include("attributes.jl")

end # module
