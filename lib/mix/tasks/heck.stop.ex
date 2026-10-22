defmodule Mix.Tasks.Heck.Stop do
  use Mix.Task

  @shortdoc "Stops serving the local heck repository"

  @moduledoc """
  Stops the heck server that `mix heck.start` or `mix heck.publish` started.

      mix heck.stop
  """

  @impl Mix.Task
  def run(_argv) do
    case Heck.Lock.with_lock(&Heck.Daemon.stop/0) do
      {:ok, port} ->
        Mix.shell().info("Stopped the heck server at #{Heck.url(port)}.")

      :error ->
        case Heck.Daemon.hex_server() do
          {:ok, port, %{"home" => home}} ->
            Mix.shell().info(
              "No heck server runs for #{Heck.home()}. The one at #{Heck.url(port)} serves " <>
                "#{home}, and `HECK_HOME=#{home} mix heck.stop` stops it."
            )

          :error ->
            Mix.shell().info("No heck server runs for #{Heck.home()}.")
        end
    end
  end
end
