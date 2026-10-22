defmodule Heck.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :heck,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: [],
      description: "A local Hex repository, for trying packages out before publishing them",
      package: [licenses: ["Apache-2.0"], links: %{}]
    ]
  end

  def application do
    [extra_applications: [:logger, :public_key, :crypto]]
  end
end
