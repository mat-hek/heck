defmodule Mix.Tasks.Heck.Unpublish do
  use Mix.Task

  @shortdoc "Removes a package, or a version of it, from the local heck repository"

  @moduledoc """
  Removes a package from the local heck repository, with all its versions, or
  one of them.

      mix heck.unpublish my_package
      mix heck.unpublish my_package 0.1.0

  Projects that fetched it keep it, until they fetch their packages again.
  """

  @impl Mix.Task
  def run(argv) do
    {name, versions} =
      case argv do
        [name] -> {name, Heck.releases(name)}
        [name, version] -> {name, Enum.filter(Heck.releases(name), &(&1 == version))}
        _other -> Mix.raise("Usage: mix heck.unpublish NAME [VERSION]")
      end

    if versions == [] do
      Mix.raise("No #{Enum.join(argv, " ")} in the heck repository in #{Heck.home()}.")
    end

    for version <- versions, do: File.rm!(Heck.tarball_path(name, version))
    Heck.build_registry!()
    for version <- versions, do: Heck.purge_hex_cache(name, version)

    Mix.shell().info("Removed #{name} #{Enum.join(versions, ", ")} from the heck repository.")

    with [] <- Heck.releases(name),
         [_ | _] = dependents <- Heck.dependents(name) do
      {verb, pronoun} =
        if match?([_], dependents), do: {"depends", "it"}, else: {"depend", "them"}

      Mix.shell().error(
        "#{Enum.join(dependents, ", ")} #{verb} on it from the heck repository, so " <>
          "projects can't fetch #{pronoun} now."
      )
    end
  end
end
