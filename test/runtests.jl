using MathOptInterfaceECOS
using Base.Test

using MathOptInterfaceTests
const MOIT = MathOptInterfaceTests

const solver = () -> ECOSInstance()
# SOC2 requires 1e-5
const config = MOIT.TestConfig(1e-5, 1e-5, true, true, true, true)

@testset "Continuous linear problems" begin
    MOIT.contlineartest(solver, config)
end

@testset "Continuous conic problems" begin
    MOIT.contconictest(solver, config, ["rsoc", "geomean", "sdp", "rootdet", "logdet"])
end
