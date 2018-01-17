struct Solution
    ret_val::Int
    primal::Vector{Float64}
    dual_eq::Vector{Float64}
    dual_ineq::Vector{Float64}
    slack::Vector{Float64}
    objval::Float64
end
Solution() = Solution(0,
                      Float64[], Float64[], Float64[], Float64[], NaN)

mutable struct Data
    m::Int
    n::Int
    IA::Vector{Int}
    JA::Vector{Int}
    VA::Vector{Float64}
    b::Vector{Float64}
    IG::Vector{Int}
    JG::Vector{Int}
    VG::Vector{Float64}
    h::Vector{Float64}
    objconstant::Float64
    c::Vector{Float64}
end

mutable struct Cone
    f::Int # number of linear equality constraints
    l::Int # length of LP cone
    q::Int # length of SOC cone
    qa::Vector{Int} # array of second-order cone constraints
    ep::Int # number of primal exponential cone triples
    eqsetconstant::Dict{Int, Float64} # For the constant of EqualTo
    eqnrows::Dict{Int, Int} # The number of rows of Zeros
    ineqsetconstant::Dict{Int, Float64} # For the constant of LessThan and GreaterThan
    ineqnrows::Dict{Int, Int} # The number of rows of each vector sets except Zeros
    function Cone()
        new(0, 0, 0, Int[], 0,
            Dict{Int, Float64}(),
            Dict{Int, UnitRange{Int}}(),
            Dict{Int, Float64}(),
            Dict{Int, UnitRange{Int}}())
    end
end
