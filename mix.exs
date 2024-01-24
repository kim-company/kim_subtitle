defmodule Subtitle.MixProject do
  use Mix.Project

  @version "0.1.1"
  @link "https://github.com/kim-company/kim_subtitle"

  def project do
    [
      app: :kim_subtitle,
      version: @version,
      source_url: @link,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "WebVTT subtitle parser. Tested. Defines a generic Cue struct.",
      package: package()
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["KIM Keep In Mind"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @link}
    ]
  end
end
