defmodule Heck.TarballTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "points the selected dependencies at the heck repository", %{tmp_dir: dir} do
    path = Path.join(dir, "pkg-1.0.0.tar")

    write_tarball!(path, [
      {"name", "pkg"},
      {"version", "1.0.0"},
      {"description", "Zażółć gęślą jaźń"},
      {"requirements",
       [
         [{"name", "dep"}, {"optional", false}, {"repository", "hexpm"}],
         [{"name", "other"}, {"optional", false}, {"repository", "hexpm"}]
       ]}
    ])

    assert Heck.Tarball.redirect_deps!(path, &(&1 == "dep")) == ["dep"]

    files = read_tarball!(path)
    assert files["CHECKSUM"] == checksum(files)

    metadata = files["metadata.config"] |> consult() |> Map.new()
    assert metadata["description"] == "Zażółć gęślą jaźń"

    assert metadata["requirements"] == [
             [{"name", "dep"}, {"optional", false}, {"repository", "heck"}],
             [{"name", "other"}, {"optional", false}, {"repository", "hexpm"}]
           ]

    assert Heck.Tarball.name_and_version!(path) == {"pkg", "1.0.0"}
  end

  @tag :tmp_dir
  test "lists the dependencies from the heck repository", %{tmp_dir: dir} do
    path = Path.join(dir, "pkg-1.0.0.tar")

    write_tarball!(path, [
      {"name", "pkg"},
      {"version", "1.0.0"},
      {"requirements",
       [
         [{"name", "dep"}, {"optional", false}, {"repository", "heck"}],
         [{"name", "other"}, {"optional", false}, {"repository", "hexpm"}]
       ]}
    ])

    assert Heck.Tarball.repo_deps!(path) == ["dep"]
  end

  @tag :tmp_dir
  test "leaves the tarball as it is without dependencies to redirect", %{tmp_dir: dir} do
    path = Path.join(dir, "pkg-1.0.0.tar")
    write_tarball!(path, [{"name", "pkg"}, {"version", "1.0.0"}, {"requirements", []}])
    before = File.read!(path)

    assert Heck.Tarball.redirect_deps!(path, fn _name -> true end) == []
    assert File.read!(path) == before
  end

  defp write_tarball!(path, metadata) do
    metadata =
      metadata |> Enum.map(&:io_lib.format("~tp.~n", [&1])) |> :unicode.characters_to_binary()

    files = %{"VERSION" => "3", "metadata.config" => metadata, "contents.tar.gz" => "contents"}

    :ok =
      :erl_tar.create(
        String.to_charlist(path),
        for {name, content} <- Map.put(files, "CHECKSUM", checksum(files)) do
          {String.to_charlist(name), content}
        end
      )
  end

  defp read_tarball!(path) do
    {:ok, entries} = :erl_tar.extract(String.to_charlist(path), [:memory])
    Map.new(entries, fn {name, content} -> {to_string(name), content} end)
  end

  defp checksum(files) do
    :crypto.hash(:sha256, [files["VERSION"], files["metadata.config"], files["contents.tar.gz"]])
    |> Base.encode16()
  end

  defp consult(binary) do
    path = Path.join(System.tmp_dir!(), "heck-metadata-#{System.unique_integer([:positive])}")
    File.write!(path, binary)
    {:ok, terms} = :file.consult(String.to_charlist(path))
    File.rm!(path)
    terms
  end
end
