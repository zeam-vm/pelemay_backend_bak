# To run this benchmark, `elixir bench/scalar_multiply_bench.exs`

Mix.install([
  {:pelemay_backend, path: "."},
  {:exla, "~> 0.3"},
  {:benchee, "~> 1.1", only: :dev}
])

pelemay = PelemayBackend.jit(&Nx.multiply/2)
exla_cpu = EXLA.jit(&Nx.multiply/2)

Benchee.run(
  %{
    "Nx" => fn input -> Nx.multiply(2.0, input) end,
    "EXLA" => fn input -> exla_cpu.(2.0, input) end,
    "Pelemay Backend" => fn input -> pelemay.(2.0, input) end
  },
  inputs: %{
    "1_000" => Nx.iota({1_000}, type: {:f, 32}),
    "10_000" => Nx.iota({10_000}, type: {:f, 32}),
    "100_000" => Nx.iota({100_000}, type: {:f, 32})
  }
)
