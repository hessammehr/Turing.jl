type WarmUpManager
  state       ::    Int
  curr_iter   ::    Int
  params      ::    Dict
end

getindex(wum::WarmUpManager, param) = wum.params[param]

setindex!(wum::WarmUpManager, value, param) = wum.params[param] = value

update_state(wum::WarmUpManager) = begin

end

init_warm_up_params{T<:Hamiltonian}(vi::VarInfo, spl::Sampler{T}) = begin
  wum = WarmUpManager(1, 1, Dict())

  # Pre-cond
  wum[:θ_num] = 1
  wum[:θ_mean] = realpart(vi[spl])
  D = length(vi[spl])
  wum[:stds] = ones(D)
  wum[:vars] = ones(D)

  # DA
  wum[:ϵ] = nothing
  wum[:μ] = nothing
  wum[:ϵ_bar] = 1.0
  wum[:H_bar] = 0.0
  wum[:m] = 0
  wum[:n_adapt] = spl.alg.n_adapt

  spl.info[:wum] = wum
end

update_da_params(wum::WarmUpManager, ϵ::Float64) = begin
  wum[:ϵ] = [ϵ]
  wum[:μ] = log(10 * ϵ)
end

adapt_step_size(wum::WarmUpManager, stats::Float64, δ::Float64) = begin
  dprintln(2, "adapting step size ϵ...")
  m = wum[:m] += 1
  if m <= wum[:n_adapt]
    γ = 0.05; t_0 = 10; κ = 0.75
    μ = wum[:μ]; ϵ_bar = wum[:ϵ_bar]; H_bar = wum[:H_bar]

    H_bar = (1 - 1 / (m + t_0)) * H_bar + 1 / (m + t_0) * (δ - stats)
    ϵ = exp(μ - sqrt(m) / γ * H_bar)
    dprintln(1, " ϵ = $ϵ, stats = $stats")

    ϵ_bar = exp(m^(-κ) * log(ϵ) + (1 - m^(-κ)) * log(ϵ_bar))
    push!(wum[:ϵ], ϵ)
    wum[:ϵ_bar], wum[:H_bar] = ϵ_bar, H_bar

    if m == wum[:n_adapt]
      dprintln(0, " Adapted ϵ = $ϵ, $m HMC iterations is used for adaption.")
    end
  end
end

update_pre_cond(wum::WarmUpManager, θ_new) = begin

  wum[:θ_num] += 1                                      # θ_new = x_t
  t = wum[:θ_num]                                       # t
  θ_mean_old = copy(wum[:θ_mean])                       # x_bar_t-1
  wum[:θ_mean] = (t - 1) / t * wum[:θ_mean] + θ_new / t # x_bar_t
  θ_mean_new = wum[:θ_mean]                             # x_bar_t

  if t == 2
    first_two = [θ_mean_old'; θ_new'] # θ_mean_old here only contains the first θ
    wum[:vars] = diag(cov(first_two))
  elseif t <= 1000
    D = length(θ_new)
    # D = 2.4^2
    wum[:vars] = (t - 1) / t * wum[:vars] .+ 100 * eps(Float64) +
                        (2.4^2 / D) / t * (t * θ_mean_old .* θ_mean_old - (t + 1) * θ_mean_new .* θ_mean_new + θ_new .* θ_new)
  end

  if t > 500
    wum[:stds] = sqrt(wum[:vars])
    wum[:stds] = wum[:stds] / min(wum[:stds]...)
  end
end