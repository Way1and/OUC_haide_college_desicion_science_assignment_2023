#=
main:
- Julia version: 1.9.3
- Author: Way1and
- Date: 2023-11-03
=#

include("./functions.jl")
P = Parameters(2023, 4, 1, 2, 1, 0.5, 1440)

run_checkout_sim(P)