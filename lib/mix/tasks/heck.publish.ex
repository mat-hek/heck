defmodule Mix.Tasks.Heck.Publish do
  use Mix.Task

  @shortdoc "Publishes the current package to the local heck repository"

  @moduledoc """
  Publishes the current package to the local heck repository.

      mix heck.publish

  The package is built with `mix hex.build`, so the project's `hex.build` alias,
  if any, runs as with a real publish. Publishing a version again replaces it,
  and projects that already fetched it then need `mix deps.unlock` and
  `mix deps.get`.

  Projects then depend on the package with `repo: "local"`, while
  `mix heck.server` runs:

      {:my_package, "~> 0.1", repo: "local"}

  The package's dependencies come from Hex, except the ones published to the
  local repository, which come from there. So publish the dependencies first.

  ## Options

    * `--port` - the port `mix heck.server` runs on, `HECK_PORT` or 4325 by
      default
  """

  @impl Mix.Task
  def run(argv) do
    {opts, _args} = OptionParser.parse!(argv, strict: [port: :integer])
    port = Heck.port(opts)

    tarball = Path.join(System.tmp_dir!(), "heck-#{System.unique_integer([:positive])}.tar")
    build!(tarball)
    {name, version} = Heck.Tarball.name_and_version!(tarball)
    local_deps = Heck.Tarball.redirect_deps!(tarball, &(Heck.releases(&1) != []))

    File.mkdir_p!(Heck.tarballs_dir())
    dest = Path.join(Heck.tarballs_dir(), "#{name}-#{version}.tar")
    replaced? = File.exists?(dest)
    File.cp!(tarball, dest)
    File.rm!(tarball)

    Heck.update!(port)
    Heck.purge_hex_cache(name, version)

    Mix.shell().info("""

    #{if replaced?, do: "Replaced", else: "Published"} #{name} #{version} in the "#{Heck.repo()}" \
    repository. With `mix heck.server` running, depend on it with:

        {:#{name}, "~> #{version}", repo: "#{Heck.repo()}"}

    or install it with `mix igniter.install #{Heck.repo()}.#{name}`.\
    """)

    if local_deps != [] do
      Mix.shell().info("""

      #{if match?([_], local_deps), do: "Its dependency", else: "Its dependencies"} \
      #{Enum.join(local_deps, ", ")} #{if match?([_], local_deps), do: "comes", else: "come"} \
      from the "#{Heck.repo()}" repository too, as published there.\
      """)
    end

    if replaced? do
      Mix.shell().info("""

      Projects that already fetched #{name} #{version} need `mix deps.unlock #{name}` and \
      `mix deps.get`, as their mix.lock has its previous checksum.\
      """)
    end
  end

  # Through `mix`, so that the project's hex.build alias runs, as it does when
  # publishing to Hex
  defp build!(tarball) do
    mix = System.find_executable("mix") || Mix.raise("Could not find the mix executable")

    case System.cmd(mix, ["hex.build", "--output", tarball],
           into: IO.stream(),
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {_output, status} -> Mix.raise("mix hex.build failed with status #{status}")
    end
  end
end
