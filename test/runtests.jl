using MathOptInterfaceECOS
using Base.Test

using MathOptInterface
const MOI = MathOptInterface # TODO remove

using MathOptInterfaceTests
const MOIT = MathOptInterfaceTests

using MathOptInterfaceUtilities
const MOIU = MathOptInterfaceUtilities

MOIU.@instance ECOSInstanceData () (EqualTo, GreaterThan, LessThan) (Zeros, Nonnegatives, Nonpositives, SecondOrderCone, ExponentialCone) () (SingleVariable,) (ScalarAffineFunction,) (VectorOfVariables,) (VectorAffineFunction,)

MOIU.@bridge SplitInterval MOIU.SplitIntervalBridge () (Interval,) () () () (ScalarAffineFunction,) () ()

# SOC2 requires 1e-5
const config = MOIT.TestConfig(atol=1e-5, rtol=1e-5)

@testset "Continuous linear problems" begin
    MOIT.contlineartest(SplitInterval{Float64}(MOIU.InstanceManager(ECOSInstanceData{Float64}(), ECOSInstance())), config)
end

@testset "Continuous conic problems" begin
    MOIT.contconictest(MOIU.InstanceManager(ECOSInstanceData{Float64}(), ECOSInstance()), config, ["rsoc", "geomean", "sdp", "rootdet", "logdet"])
end
