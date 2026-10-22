defmodule Heck.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github "https://github.com/mat-hek/heck"

  def project do
    [
      app: :heck,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A local Hex repository, for trying packages out before publishing them",
      package: [licenses: ["MIT"], links: %{"GitHub" => @github}],
      name: "heck",
      source_url: @github,
      docs: [main: "readme", extras: ["README.md", "LICENSE"]]
    ]
  end

  def application do
    [extra_applications: [:logger, :public_key, :crypto, :inets]]
  end

  def deps() do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
