defmodule Mix.Tasks.Heck.Server do
  use Mix.Task

  @shortdoc "Serves the local heck repository in the foreground"

  @moduledoc """
  Serves the local heck repository in the foreground, logging the requests.

      mix heck.server

  Usually, the server runs in the background instead, as `mix heck.start` and
  `mix heck.publish` start it. This one is for seeing what Hex asks for.

  ## Options

    * `--port` - the port to serve on, `HECK_PORT` by default. Without either,
      it's 4325, or any free port if that's busy.
  """

  @impl Mix.Task
  def run(argv) do
    {opts, _args} = OptionParser.parse!(argv, strict: [port: :integer])

    Heck.build_registry!()

    port = Heck.Lock.with_lock(fn -> serve!(Heck.requested_port(opts)) end)

    Mix.shell().info("""
    Serving the "#{Heck.repo()}" Hex repository from #{Heck.home()} at #{Heck.url(port)}.
    Press Ctrl+C twice to stop.
    """)

    Process.sleep(:infinity)
  end

  defp serve!(requested) do
    port =
      case Heck.Daemon.claim!(requested) do
        {:running, port} ->
          Mix.raise(
            "The heck server runs in the background at #{Heck.url(port)}. Stop it with " <>
              "`mix heck.stop` first."
          )

        {:stopped, port} ->
          port
      end

    case Heck.Daemon.serve(port) do
      {:ok, port} ->
        Heck.register!(port)
        port

      {:error, :eaddrinuse} ->
        Mix.raise("Port #{port} is in use.")

      {:error, reason} ->
        Mix.raise("Could not serve at port #{port}: #{:inet.format_error(reason)}")
    end
  end
end
