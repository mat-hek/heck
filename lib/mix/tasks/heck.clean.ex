defmodule Mix.Tasks.Heck.Clean do
  use Mix.Task

  @shortdoc "Removes all packages from the local heck repository"

  @moduledoc """
  Removes all packages from the local heck repository.

      mix heck.clean

  The server, if it runs, keeps serving the repository, now empty, and Hex keeps
  knowing it, as its signing key stays. Projects that fetched the packages keep
  them, until they fetch their packages again.

  ## Options

    * `--yes` - doesn't ask first
  """

  @impl Mix.Task
  def run(argv) do
    {opts, _args} = OptionParser.parse!(argv, strict: [yes: :boolean])

    case Heck.packages() do
      [] ->
        Mix.shell().info("No packages in the heck repository in #{Heck.home()}.")

      packages ->
        list =
          Enum.map_join(packages, "\n", fn {name, versions} ->
            "  #{name} #{Enum.join(versions, ", ")}"
          end)

        if opts[:yes] ||
             Mix.shell().yes?("Remove all packages from #{Heck.home()}?\n\n#{list}\n",
               default: :no
             ) do
          for {name, versions} <- packages, version <- versions do
            File.rm!(Heck.tarball_path(name, version))
          end

          Heck.build_registry!()

          for {name, versions} <- packages, version <- versions do
            Heck.purge_hex_cache(name, version)
          end

          Mix.shell().info("Removed all packages from the heck repository.")
        end
    end
  end
end
