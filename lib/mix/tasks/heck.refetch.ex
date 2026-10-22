defmodule Mix.Tasks.Heck.Refetch do
  use Mix.Task

  @shortdoc "Fetches a project's heck packages again, after they're republished"

  @moduledoc """
  Fetches the current project's packages from the heck repository again, so
  that it gets the ones published again under the same version.

      mix heck.refetch
      mix heck.refetch my_package

  It unlocks the given packages, or all from the repository, and runs
  `mix deps.get`. Without it, the project keeps building the previous ones, and
  fetching fails with "Registry checksum mismatch against lock", as `mix.lock`
  has their previous checksums.
  """

  @impl Mix.Task
  def run(names) do
    Mix.Project.get!()

    # From mix.lock, where an entry from a Hex repository names it
    locked =
      for {app, {:hex, _name, version, _checksum, _managers, _deps, repo, _outer}} <-
            Mix.Dep.Lock.read(),
          repo == Heck.repo(),
          do: {to_string(app), version}

    selected =
      case names do
        [] ->
          locked

        names ->
          case names -- Enum.map(locked, &elem(&1, 0)) do
            [] -> Enum.filter(locked, &(elem(&1, 0) in names))
            other -> Mix.raise("Not locked from the heck repository: #{Enum.join(other, ", ")}")
          end
      end

    cond do
      selected == [] ->
        Mix.shell().info("No packages from the heck repository in mix.lock.")

      Heck.Daemon.hex_server() == :error ->
        Mix.raise("The heck repository isn't served. `mix heck.start` serves it.")

      true ->
        for {name, version} <- selected, do: Heck.purge_hex_cache(name, version)
        Mix.Task.run("deps.unlock", Enum.map(selected, &elem(&1, 0)))
        Mix.Task.run("deps.get")

        Mix.shell().info(
          "\nFetched #{selected |> Enum.map(&elem(&1, 0)) |> Enum.join(", ")} again " <>
            "from the heck repository."
        )
    end
  end
end
