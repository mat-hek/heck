defmodule Heck do
  @moduledoc false

  # A local Hex repository, for trying packages out before publishing them.
  #
  # `mix heck.publish` builds the current package, adds it to the repository and
  # starts serving it in the background, if it isn't already. Projects then
  # depend on its packages with `repo: "heck"`.
  #
  # The repository lives in `~/.heck`, or in `HECK_HOME` if set. It's served on
  # `HECK_PORT` if set, and otherwise on port 4325, or any free one if that's
  # busy.

  @repo "heck"
  @default_port 4325
  @version Mix.Project.config()[:version]

  @doc "The name of the repository, as projects refer to it."
  def repo, do: @repo

  @doc false
  def version, do: @version

  @doc false
  def home, do: System.get_env("HECK_HOME") || Path.expand("~/.heck")

  @doc false
  def public_dir, do: Path.join(home(), "public")

  @doc false
  def tarballs_dir, do: Path.join(public_dir(), "tarballs")

  @doc false
  def tarball_path(name, version), do: Path.join(tarballs_dir(), "#{name}-#{version}.tar")

  defp private_key, do: Path.join(home(), "private_key.pem")

  @doc "The port asked for with `--port` or `HECK_PORT`, if any."
  def requested_port(opts) do
    cond do
      opts[:port] -> opts[:port]
      port = System.get_env("HECK_PORT") -> String.to_integer(port)
      true -> nil
    end
  end

  @doc false
  def default_port, do: @default_port

  @doc false
  def url(port), do: "http://localhost:#{port}"

  @doc "Rebuilds the registry from the tarballs in the repository."
  def build_registry! do
    ensure_private_key!()
    File.mkdir_p!(tarballs_dir())

    quietly(fn ->
      Mix.Task.rerun("hex.registry", [
        "build",
        public_dir(),
        "--name",
        @repo,
        "--private-key",
        private_key()
      ])
    end)
  end

  @doc "Registers the repository with Hex, as served at the port."
  def register!(port) do
    quietly(fn ->
      Mix.Task.rerun("hex.repo", [
        "add",
        @repo,
        url(port),
        "--public-key",
        Path.join(public_dir(), "public_key")
      ])
    end)
  end

  # The registry is signed with a key of our own, made on first use
  defp ensure_private_key! do
    path = private_key()

    if not File.exists?(path) do
      Mix.ensure_application!(:public_key)
      key = :public_key.generate_key({:rsa, 2048, 65537})
      pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])
      File.mkdir_p!(home())
      File.write!(path, pem)
      File.chmod!(path, 0o600)
    end
  end

  defp quietly(fun) do
    shell = Mix.shell()
    Mix.shell(Mix.Shell.Quiet)

    try do
      fun.()
    after
      Mix.shell(shell)
    end
  end

  @doc "The packages in the repository, with their versions, newest first."
  def packages do
    tarballs_dir()
    |> Path.join("*-*.tar")
    |> Path.wildcard()
    |> Enum.map(&(&1 |> Path.basename() |> String.split("-", parts: 2) |> hd()))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&{&1, releases(&1)})
  end

  @doc "The packages in the repository that depend on the one given from it."
  def dependents(name) do
    for {package, versions} <- packages(),
        package != name,
        Enum.any?(versions, &(name in Heck.Tarball.repo_deps!(tarball_path(package, &1)))),
        do: package
  end

  @doc "The versions of a package in the repository, newest first."
  def releases(name) do
    prefix = name <> "-"

    tarballs_dir()
    |> Path.join(prefix <> "*.tar")
    |> Path.wildcard()
    |> Enum.map(&(&1 |> Path.basename(".tar") |> String.replace_prefix(prefix, "")))
    |> Enum.filter(&match?({:ok, _}, Version.parse(&1)))
    |> Enum.sort({:desc, Version})
  end

  @doc """
  Removes a package version from Hex's cache, so that projects fetch it anew
  after it's replaced.
  """
  def purge_hex_cache(name, version) do
    [hex_cache_home(), "packages", @repo, "#{name}-#{version}.tar"]
    |> Path.join()
    |> File.rm()
  end

  @doc "The URL Hex has for the repository, if any."
  def hex_repo_url do
    if Code.ensure_loaded?(Hex.State) do
      apply(Hex, :start, [])

      case apply(Hex.State, :fetch!, [:repos]) do
        %{@repo => %{url: url}} -> url
        _repos -> nil
      end
    end
  end

  @doc "Where Hex keeps its config, with the repositories it knows."
  def hex_config_home do
    if Code.ensure_loaded?(Hex.State) do
      apply(Hex, :start, [])
      apply(Hex.State, :fetch!, [:config_home])
    else
      System.get_env("HEX_HOME") || Path.expand("~/.hex")
    end
  end

  defp hex_cache_home do
    if Code.ensure_loaded?(Hex.State) do
      apply(Hex, :start, [])
      apply(Hex.State, :fetch!, [:cache_home])
    else
      System.get_env("HEX_HOME") || Path.expand("~/.hex")
    end
  end
end
