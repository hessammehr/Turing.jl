include("../utility.jl")
using Distributions, Turing, Test

N = 5
setchunksize(4*N)
alg = HMC(1000, 0.2, 4)

@model vdemo() = begin
  v = Vector{Matrix{Real}}(undef, N)
  v ~ [Wishart(7, [1 0.5; 0.5 1])]
end

t_vec = @elapsed res_vec = sample(vdemo(), alg)

@model vdemo() = begin
  v = Vector{Matrix{Real}}(undef, N)
  for i = 1:N
    v[i] ~ Wishart(7, [1 0.5; 0.5 1])
  end
end

t_loop = @elapsed res = sample(vdemo(), alg)

println("Time for")
println("  Loop : $t_loop")
println("  Vec  : $t_vec")
