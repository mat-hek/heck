defmodule Mix.Tasks.Heck.Start do
  use Mix.Task

  @shortdoc "Starts serving the local heck repository in the background"

  @moduledoc """
  Starts serving the local heck repository in the background, if it isn't
  served already.

      mix heck.start

  `mix heck.publish` does it too. Hex only fetches packages over HTTP, so the
  server has to run whenever projects fetch packages from the repository, for
  example in `mix deps.get`. `mix heck.stop` stops it, and `mix heck.server`
  serves the repository in the foreground instead.

  One server runs at a time, for one home, as Hex knows one "heck"
  repository.

  ## Options

    * `--port` - the port to serve on, `HECK_PORT` by default. Without either,
      it's 4325, or any free port if that's busy. If the server runs on another
      port, it fails.
  """

  @impl Mix.Task
  def run(argv) do
    {opts, _args} = OptionParser.parse!(argv, strict: [port: :integer])
    Heck.build_registry!()

    message =
      Heck.Lock.with_lock(fn ->
        server = Heck.Daemon.claim!(Heck.requested_port(opts))
        {port, message} = Heck.Daemon.ensure_started!(server)
        Heck.register!(port)
        message
      end)

    Mix.shell().info(message)
  end
end
