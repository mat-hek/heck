defmodule Heck.Daemon do
  @moduledoc false

  # The server, running in the background: a BEAM of its own, detached from the
  # terminal. Once it serves, it records its port and OS pid in server.json, in
  # the heck home. The tasks verify the record by asking the server for /heck,
  # so a stale one does no harm.
  #
  # Hex knows one "heck" repository, so one server runs at a time, for one home.
  # A server of another home is found where Hex's "heck" repository points, as
  # starting and publishing point it to the server. The tasks check and start the
  # server holding Heck.Lock, so that two of them don't both start one.

  @doc "The log of the background server."
  def log_path, do: Path.join(Heck.home(), "server.log")

  defp state_path, do: Path.join(Heck.home(), "server.json")

  @doc """
  Serves at the port, or, for `:auto`, at the default one, or any free one if
  that's busy. Records where. Returns the port.
  """
  def serve(port, opts \\ []) do
    result =
      case port do
        :auto ->
          with {:error, :eaddrinuse} <- Heck.Server.start(Heck.default_port(), opts) do
            Heck.Server.start(0, opts)
          end

        port ->
          Heck.Server.start(port, opts)
      end

    with {:ok, port} <- result do
      # Written aside and renamed, so that it's never read half written
      File.mkdir_p!(Heck.home())
      tmp = state_path() <> ".#{System.pid()}"
      File.write!(tmp, JSON.encode!(%{"port" => port, "pid" => System.pid()}))
      File.rename!(tmp, state_path())
      {:ok, port}
    end
  end

  @doc "Runs the background server, in the detached BEAM."
  def run(port) do
    log = File.open!(log_path(), [:append, :utf8])

    case serve(port, log: log) do
      {:ok, port} ->
        IO.puts(log, "Serving #{Heck.public_dir()} at #{Heck.url(port)}")
        Process.sleep(:infinity)

      {:error, reason} ->
        IO.puts(log, "Could not serve at port #{port}: #{:inet.format_error(reason)}")
        System.halt(1)
    end
  end

  @doc """
  Asks the server at the port about itself. Returns its home, version and OS
  pid, or `:error` when no heck server answers there.
  """
  def info(port) do
    Mix.ensure_application!(:inets)
    {:ok, _apps} = Application.ensure_all_started(:inets)
    url = String.to_charlist(Heck.url(port) <> "/heck")
    http_opts = [timeout: 2_000, connect_timeout: 1_000]

    with {:ok, {{_, 200, _}, _headers, body}} <-
           :httpc.request(:get, {url, []}, http_opts, body_format: :binary),
         {:ok, %{"heck" => _, "home" => _, "pid" => _} = info} <- JSON.decode(body) do
      {:ok, info}
    else
      _ -> :error
    end
  end

  @doc "The server of this home, if it runs: its port and info."
  def ours do
    with {:ok, json} <- File.read(state_path()),
         {:ok, %{"port" => port, "pid" => pid}} <- JSON.decode(json),
         {:ok, %{"pid" => ^pid} = info} <- info(port),
         true <- info["home"] == Heck.home() do
      {:ok, port, info}
    else
      _ ->
        # Its record may be gone, while Hex still points to it
        case hex_server() do
          {:ok, _port, %{"home" => home}} = found ->
            if home == Heck.home(), do: found, else: :error

          :error ->
            :error
        end
    end
  end

  @doc "The heck server where Hex's \"heck\" repository points, if one runs there."
  def hex_server do
    with url when is_binary(url) <- Heck.hex_repo_url(),
         %URI{host: host, port: port} when host in ["localhost", "127.0.0.1"] <- URI.parse(url),
         {:ok, info} <- info(port) do
      {:ok, port, info}
    else
      _ -> :error
    end
  end

  @doc """
  Checks that this home's server can run, at the requested port, if any, as one
  server runs at a time, for one home. Returns `{:running, port}`, or
  `{:stopped, port}`, where the port is `:auto` when none was requested.
  """
  def claim!(requested) do
    server =
      with :error <- ours(),
           :error <- hex_server(),
           :error <- if(requested, do: requested_server(requested), else: :error) do
        :error
      end

    case server do
      :error ->
        {:stopped, requested || :auto}

      {:ok, port, %{"home" => home}} ->
        cond do
          home != Heck.home() ->
            Mix.raise(
              "The heck server at #{Heck.url(port)} serves #{home}, and one runs at a time, " <>
                "for one home. Stop it with `HECK_HOME=#{home} mix heck.stop` first."
            )

          requested && requested != port ->
            Mix.raise(
              "The heck server runs at #{Heck.url(port)}. Stop it with `mix heck.stop` " <>
                "first, to run it at #{Heck.url(requested)}."
            )

          true ->
            {:running, port}
        end
    end
  end

  defp requested_server(port) do
    with {:ok, info} <- info(port), do: {:ok, port, info}
  end

  @doc """
  Starts the background server, unless it runs, as `claim!/1` found. Returns its
  port and a message for the user.
  """
  def ensure_started!({:running, port}) do
    {port, "The heck server runs at #{Heck.url(port)}."}
  end

  def ensure_started!({:stopped, port}) do
    if is_integer(port), do: ensure_free!(port)
    File.rm(state_path())
    spawn!(port)

    case await(System.monotonic_time(:millisecond) + 10_000) do
      {:ok, port} ->
        {port,
         "Started the heck server at #{Heck.url(port)}, logging to #{log_path()}. " <>
           "`mix heck.stop` stops it."}

      :timeout ->
        Mix.raise("The heck server didn't start, see #{log_path()}.")
    end
  end

  # Rather than finding out from the server's log, after waiting for it
  defp ensure_free!(port) do
    case :gen_tcp.listen(port, ip: {127, 0, 0, 1}, reuseaddr: true) do
      {:ok, socket} ->
        :gen_tcp.close(socket)

      {:error, reason} ->
        Mix.raise("Could not serve at port #{port}: #{:inet.format_error(reason)}")
    end
  end

  defp spawn!(port) do
    elixir = System.find_executable("elixir") || Mix.raise("Could not find the elixir executable")
    ebin = Heck |> :code.which() |> to_string() |> Path.dirname()
    File.mkdir_p!(Heck.home())

    {_output, 0} =
      System.cmd(
        elixir,
        ["--erl", "-detached", "-pa", ebin, "-e", "Heck.Daemon.run(#{inspect(port)})"],
        env: [{"HECK_HOME", Heck.home()}],
        stderr_to_stdout: true
      )
  end

  defp await(deadline) do
    case ours() do
      {:ok, port, _info} ->
        {:ok, port}

      :error ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(100)
          await(deadline)
        else
          :timeout
        end
    end
  end

  @doc "Stops this home's server. Returns its port."
  def stop do
    case ours() do
      {:ok, port, %{"pid" => pid}} ->
        kill(pid)
        await_down(port, System.monotonic_time(:millisecond) + 10_000)
        File.rm(state_path())
        {:ok, port}

      :error ->
        :error
    end
  end

  defp kill(pid) do
    case :os.type() do
      {:win32, _} -> System.cmd("taskkill", ["/PID", pid, "/F"], stderr_to_stdout: true)
      _unix -> System.cmd("kill", [pid], stderr_to_stdout: true)
    end
  end

  defp await_down(port, deadline) do
    if info(port) != :error and System.monotonic_time(:millisecond) < deadline do
      Process.sleep(100)
      await_down(port, deadline)
    end
  end
end
