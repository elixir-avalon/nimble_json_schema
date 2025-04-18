defmodule NimbleJsonSchema.MixProject do
  use Mix.Project

  def project do
    [
      app: :nimble_json_schema,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.36", only: :dev, runtime: false},
      {:ex_json_schema, "~> 0.10.2", only: [:test, :dev]},
      {:nimble_options, "~> 1.1"}
    ]
  end
end
