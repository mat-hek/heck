defmodule Mix.Tasks.Heck.Status do
  use Mix.Task

  @shortdoc "Shows the heck server and the packages in the local repository"

  @moduledoc """
  Shows whether the heck server runs, and the packages in the local repository.

      mix heck.status
  """

  @impl Mix.Task
  def run(_argv) do
    case Heck.Daemon.ours() do
      {:ok, port, %{"pid" => pid}} ->
        url = Heck.url(port)

        Mix.shell().info(
          "The heck server runs at #{url}, with OS pid #{pid}, logging to " <>
            "#{Heck.Daemon.log_path()}."
        )

        # Hex knows one "heck" repository, which may point elsewhere
        case Heck.hex_repo_url() do
          ^url ->
            :ok

          other ->
            Mix.shell().error(
              "Hex's \"#{Heck.repo()}\" repository points to #{other || "nothing"}. " <>
                "`mix heck.start` points it to #{url}."
            )
        end

      :error ->
        case Heck.Daemon.hex_server() do
          {:ok, port, %{"home" => home}} ->
            Mix.shell().info(
              "No heck server runs for #{Heck.home()}. The one at #{Heck.url(port)} " <>
                "serves #{home}."
            )

          :error ->
            Mix.shell().info(
              "No heck server runs for #{Heck.home()}. `mix heck.start` starts one."
            )
        end
    end

    case Heck.packages() do
      [] ->
        Mix.shell().info("\nNo packages in #{Heck.home()} yet. `mix heck.publish` adds one.")

      packages ->
        Mix.shell().info("\nPackages in #{Heck.home()}:")

        for {name, versions} <- packages do
          Mix.shell().info("  #{name} #{Enum.join(versions, ", ")}")
        end
    end
  end
end
