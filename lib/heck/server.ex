defmodule Heck.Server do
  @moduledoc false

  # Serves the registry files, like a static file server, and the versions of a
  # package as JSON, which Igniter asks for to install a package without a
  # version. Igniter asks at the same path as Hex, but for JSON, while Hex sends
  # no Accept header. /heck tells the heck tasks which server they talk to.

  @files ~r{\A/(names|versions|public_key|packages/[a-z][a-z0-9_]*|tarballs/[a-z][a-z0-9_]*-[0-9A-Za-z.+-]+\.tar)\z}

  @doc """
  Starts serving on the given port, 0 for any, logging requests to the `:log`
  device. Returns the port.
  """
  def start(port, opts \\ []) do
    log = Keyword.get(opts, :log, :stdio)

    with {:ok, listen} <-
           :gen_tcp.listen(port, [
             :binary,
             packet: :http_bin,
             active: false,
             reuseaddr: true,
             ip: {127, 0, 0, 1}
           ]) do
      spawn_link(fn -> accept(listen, log) end)
      :inet.port(listen)
    end
  end

  defp accept(listen, log) do
    {:ok, socket} = :gen_tcp.accept(listen)
    pid = spawn(fn -> receive(do: (:go -> serve(socket, log))) end)
    :ok = :gen_tcp.controlling_process(socket, pid)
    send(pid, :go)
    accept(listen, log)
  end

  defp serve(socket, log) do
    with {:ok, {:http_request, method, {:abs_path, path}, _version}} <-
           :gen_tcp.recv(socket, 0, 10_000),
         {:ok, headers} <- recv_headers(socket, %{}) do
      path = path |> String.split("?") |> hd()
      {status, type, body} = respond(method, path, headers)
      IO.puts(log, "#{method} #{path} #{status}")

      :gen_tcp.send(socket, [
        "HTTP/1.1 #{status} #{reason(status)}\r\n",
        "content-type: #{type}\r\n",
        "content-length: #{byte_size(body)}\r\n",
        "connection: close\r\n\r\n",
        if(method == :HEAD, do: "", else: body)
      ])
    end

    :gen_tcp.close(socket)
  end

  defp recv_headers(socket, headers) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, {:http_header, _, name, _, value}} ->
        name = name |> to_string() |> String.downcase()
        recv_headers(socket, Map.put(headers, name, value))

      {:ok, :http_eoh} ->
        {:ok, headers}

      other ->
        other
    end
  end

  @doc false
  def respond(method, path, headers) when method in [:GET, :HEAD] do
    json? = headers |> Map.get("accept", "") |> String.contains?("application/json")

    case {json?, String.split(path, "/")} do
      {_json?, ["", "heck"]} -> info()
      {true, ["", "packages", name]} -> releases(name)
      _other -> file(path)
    end
  end

  def respond(_method, _path, _headers), do: {405, "text/plain", "Method not allowed\n"}

  defp info do
    json = JSON.encode!(%{"heck" => Heck.version(), "home" => Heck.home(), "pid" => System.pid()})
    {200, "application/json", json}
  end

  defp releases(name) do
    case Heck.releases(name) do
      [] ->
        {404, "text/plain", "Not found\n"}

      versions ->
        json =
          JSON.encode!(%{
            "name" => name,
            "releases" => Enum.map(versions, &%{"version" => &1}),
            "retirements" => %{}
          })

        {200, "application/json", json}
    end
  end

  defp file(path) do
    with true <- Regex.match?(@files, path),
         {:ok, body} <- File.read(Path.join(Heck.public_dir(), path)) do
      {200, "application/octet-stream", body}
    else
      _ -> {404, "text/plain", "Not found\n"}
    end
  end

  defp reason(200), do: "OK"
  defp reason(404), do: "Not Found"
  defp reason(405), do: "Method Not Allowed"
end
