defmodule Mix.Tasks.Heck.Server do
  use Mix.Task

  @shortdoc "Serves the local heck repository"

  @moduledoc """
  Serves the local heck repository, so that projects can fetch its packages.

      mix heck.server

  Hex only fetches packages over HTTP, so the server has to run whenever
  projects fetch packages from the repository, for example in `mix deps.get`.
  It also registers the repository with Hex, as "local".

  ## Options

    * `--port` - the port to serve on, `HECK_PORT` or 4325 by default
  """

  @impl Mix.Task
  def run(argv) do
    {opts, _args} = OptionParser.parse!(argv, strict: [port: :integer])
    port = Heck.port(opts)

    Heck.update!(port)
    {:ok, ^port} = Heck.Server.start(port)

    Mix.shell().info("""
    Serving the "#{Heck.repo()}" Hex repository from #{Heck.home()} at #{Heck.url(port)}.
    Press Ctrl+C twice to stop.
    """)

    Process.sleep(:infinity)
  end
end
