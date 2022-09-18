defmodule PelemayBackend.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/zeam-vm/pelemay_backend"

  def project do
    [
      app: :pelemay_backend,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      compilers: [:pelemay_backend, :elixir_make] ++ Mix.compilers(),
      aliases: [
        "compile.pelemay_backend": &compile/1
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PelemayBackend.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:nx, "~> 0.3.0"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:openblas_builder, "~> 0.1.0-dev", github: "zeam-vm/openblas_builder", branch: "main"},
      {:elixir_make, "~> 0.6", runtime: false},
      {:benchee, "~> 1.1", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "README",
      logo: "Pelemay.png",
      before_closing_body_tag: &before_closing_body_tag/1,
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/katex.min.css" integrity="sha384-t5CR+zwDAROtph0PXGte6ia8heboACF9R5l/DiY+WZ3P2lxNgvJkQk5n7GPvLMYw" crossorigin="anonymous">
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/katex.min.js" integrity="sha384-FaFLTlohFghEIZkw6VGwmf9ISTubWAVYW8tG8+w2LAIftJEULZABrF9PPFv+tVkH" crossorigin="anonymous"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/contrib/auto-render.min.js" integrity="sha384-bHBqxz8fokvgoJ/sc17HODNxa42TlaEhB+w8ZJXTc2nZf1VgEaFZeZvT4Mznfz0v" crossorigin="anonymous"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        renderMathInElement(document.body, {
          delimiters: [
            {left: '$$', right: '$$', display: true},
            {left: '$', right: '$', display: false}
          ]
        });
      });
    </script>
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <script>mermaid.initialize({startOnLoad: true})</script>
    <script src="https://cdn.jsdelivr.net/npm/vega@5.20.2"></script>
    <script src="https://cdn.jsdelivr.net/npm/vega-lite@5.1.1"></script>
    <script src="https://cdn.jsdelivr.net/npm/vega-embed@6.18.2"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        for (const codeEl of document.querySelectorAll("pre code.vega-lite")) {
          try {
            const preEl = codeEl.parentElement;
            const spec = JSON.parse(codeEl.textContent);
            const plotEl = document.createElement("div");
            preEl.insertAdjacentElement("afterend", plotEl);
            vegaEmbed(plotEl, spec);
            preEl.remove();
          } catch (error) {
            console.log("Failed to render Vega-Lite plot: " + error)
          }
        }
      });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""

  defp compile(_) do
    # System.put_env("TEST", "#{inspect OpenBLASBuilder.hello()}")

    OpenBLASBuilder.extract_archive!()

    OpenBLASBuilder.compile_matched!([
      {"interface", "cblas_sscal"},
      {"interface", "sscal"},
      {"interface", "cblas_scopy"},
      {"interface", "scopy"},
      {"driver/others", "memory"},
      {"driver/others", "blas_l1_thread"},
      {"driver/others", "blas_server"},
      {"driver/others", "parameter"},
      {"driver/others", "openblas_env"},
      {"driver/others", "openblas_error_handle"},
      {"driver/others", "divtable"}
    ])
    |> Map.values()
    |> Enum.join(" ")
    |> then(&System.put_env("OPENBLAS_OBJ", &1))

    {:ok, []}
  end
end
