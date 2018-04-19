using MathOptInterfaceECOS
using Base.Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

MOIU.@model ECOSModelData () (EqualTo, GreaterThan, LessThan) (Zeros, Nonnegatives, Nonpositives, SecondOrderCone, ExponentialCone) () (SingleVariable,) (ScalarAffineFunction,) (VectorOfVariables,) (VectorAffineFunction,)

MOIB.@bridge SplitInterval MOIB.SplitIntervalBridge () (Interval,) () () () (ScalarAffineFunction,) () ()

# SOC2 requires 1e-5
const config = MOIT.TestConfig(atol=1e-5, rtol=1e-5)

@testset "Continuous linear problems" begin
    MOIT.contlineartest(SplitInterval{Float64}(MOIU.CachingOptimizer(ECOSModelData{Float64}(), ECOSOptimizer())), config)
end

@testset "Continuous conic problems" begin
    MOIT.contconictest(MOIU.CachingOptimizer(ECOSModelData{Float64}(), ECOSOptimizer()), config, ["rsoc", "geomean", "sdp", "rootdet", "logdet"])
end
