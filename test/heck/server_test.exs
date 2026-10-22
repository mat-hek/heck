defmodule Heck.ServerTest do
  use ExUnit.Case, async: false

  setup do
    home = Path.join(System.tmp_dir!(), "heck-test-#{System.unique_integer([:positive])}")
    tarballs = Path.join([home, "public", "tarballs"])
    File.mkdir_p!(tarballs)
    File.mkdir_p!(Path.join([home, "public", "packages"]))

    for version <- ["0.1.0", "0.10.0", "0.2.0-rc.1"] do
      File.write!(Path.join(tarballs, "foo-#{version}.tar"), "tarball #{version}")
    end

    File.write!(Path.join(tarballs, "foo_bar-9.0.0.tar"), "other package")
    File.write!(Path.join([home, "public", "packages", "foo"]), "registry entry")

    previous = System.get_env("HECK_HOME")
    System.put_env("HECK_HOME", home)

    on_exit(fn ->
      if previous, do: System.put_env("HECK_HOME", previous), else: System.delete_env("HECK_HOME")
      File.rm_rf!(home)
    end)

    {:ok, port} = Heck.Server.start(0)
    %{url: "http://localhost:#{port}"}
  end

  test "lists the versions of a package as JSON, newest first", %{url: url} do
    assert {200, "application/json", body} = get(url <> "/packages/foo", "application/json")

    assert %{"name" => "foo", "releases" => releases} = JSON.decode!(body)
    assert Enum.map(releases, & &1["version"]) == ["0.10.0", "0.2.0-rc.1", "0.1.0"]
  end

  test "serves registry files to Hex, which sends no Accept header", %{url: url} do
    assert {200, _type, "registry entry"} = get(url <> "/packages/foo")
    assert {200, _type, "tarball 0.1.0"} = get(url <> "/tarballs/foo-0.1.0.tar")
  end

  test "tells which heck server it is", %{url: url} do
    assert {200, "application/json", body} = get(url <> "/heck")
    home = System.get_env("HECK_HOME")
    pid = System.pid()
    assert %{"heck" => _version, "home" => ^home, "pid" => ^pid} = JSON.decode!(body)
  end

  test "serves nothing outside the registry", %{url: url} do
    assert {404, _type, _body} = get(url <> "/packages/missing", "application/json")
    assert {404, _type, _body} = get(url <> "/tarballs/missing-1.0.0.tar")
    assert {404, _type, _body} = get(url <> "/../private_key.pem")
    assert {404, _type, _body} = get(url <> "/tarballs/..%2F..%2Fprivate_key.pem")
  end

  defp get(url, accept \\ nil) do
    headers = if accept, do: [{~c"accept", String.to_charlist(accept)}], else: []

    {:ok, {{_, status, _}, response_headers, body}} =
      :httpc.request(:get, {String.to_charlist(url), headers}, [], body_format: :binary)

    type = response_headers |> List.keyfind(~c"content-type", 0) |> elem(1) |> to_string()
    {status, type, body}
  end
end
