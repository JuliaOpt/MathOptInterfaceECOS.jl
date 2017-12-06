using MathOptInterfaceECOS
using Base.Test

using MathOptInterfaceTests
const MOIT = MathOptInterfaceTests

const solver = () -> ECOSInstance()
const config = MOIT.TestConfig(1e-7, 1e-7, true, true, true, true)

@testset "Continuous linear problems" begin
    MOIT.contlineartest(solver, config)
end

@testset "Continuous conic problems" begin
    MOIT.contconictest(solver, config, ["rsoc", "geomean", "sdp", "rootdet", "logdet"])
end
