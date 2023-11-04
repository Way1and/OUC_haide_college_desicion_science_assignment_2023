#=
main:
- Julia version: 1.9.3
- Author: Way1and
- Date: 2023-11-03
=#

include("./functions.jl")
P = Parameters(1, 4, 1, 1, 2, 0.5, 30)
run_checkout_sim(P)