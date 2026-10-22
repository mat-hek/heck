defmodule Heck.Lock do
  @moduledoc false

  # One heck server runs at a time per Hex home, so the tasks that check for the
  # server and start or stop it do it holding a lock, one per Hex home: a file
  # in the system temp directory, named after the Hex home. Creating it is
  # atomic, so one task at a time holds it. Tasks hold it for seconds, so an
  # older one was left behind, for example by a task stopped halfway.

  @stale_seconds 30

  @doc "Runs the function holding the lock, waiting for it if needed."
  def with_lock(fun) do
    path = path()
    acquire!(path)

    try do
      fun.()
    after
      File.rm(path)
    end
  end

  defp path do
    Mix.ensure_application!(:crypto)
    hash = :crypto.hash(:sha256, Heck.hex_config_home()) |> Base.encode16(case: :lower)
    Path.join(System.tmp_dir!(), "heck-#{binary_part(hash, 0, 16)}.lock")
  end

  defp acquire!(path) do
    case File.open(path, [:write, :exclusive]) do
      {:ok, file} ->
        IO.write(file, System.pid())
        File.close(file)

      {:error, :eexist} ->
        if stale?(path), do: File.rm(path), else: Process.sleep(100)
        acquire!(path)

      {:error, reason} ->
        Mix.raise("Could not create #{path}: #{:file.format_error(reason)}")
    end
  end

  defp stale?(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} -> System.os_time(:second) - mtime > @stale_seconds
      {:error, _reason} -> false
    end
  end
end
