defmodule Heck.Tarball do
  @moduledoc false

  # A tarball from `mix hex.build` holds VERSION, CHECKSUM, metadata.config and
  # contents.tar.gz. CHECKSUM is the SHA-256 of the other three, and
  # metadata.config a list of Erlang terms.

  @doc "Reads the package name and version from a tarball."
  def name_and_version!(path) do
    metadata = path |> read!() |> Map.fetch!("metadata.config") |> parse!() |> Map.new()
    {Map.fetch!(metadata, "name"), Map.fetch!(metadata, "version")}
  end

  @doc """
  Points the dependencies that `local?` selects, by name, at the heck
  repository, rewriting the tarball. Returns their names.
  """
  def redirect_deps!(path, local?) do
    files = read!(path)

    {terms, redirected} =
      files
      |> Map.fetch!("metadata.config")
      |> parse!()
      |> Enum.map_reduce([], fn
        {"requirements", requirements}, redirected when is_list(requirements) ->
          {requirements, redirected} =
            Enum.map_reduce(requirements, redirected, &redirect(&1, &2, local?))

          {{"requirements", requirements}, redirected}

        term, redirected ->
          {term, redirected}
      end)

    if redirected != [] do
      write!(path, Map.put(files, "metadata.config", encode(terms)))
    end

    Enum.reverse(redirected)
  end

  defp redirect(requirement, redirected, local?) do
    {"name", name} = List.keyfind(requirement, "name", 0)

    if local?.(name) and List.keyfind(requirement, "repository", 0) != {"repository", Heck.repo()} do
      {List.keystore(requirement, "repository", 0, {"repository", Heck.repo()}),
       [name | redirected]}
    else
      {requirement, redirected}
    end
  end

  defp read!(path) do
    {:ok, entries} = :erl_tar.extract(String.to_charlist(path), [:memory])
    Map.new(entries, fn {name, content} -> {to_string(name), content} end)
  end

  defp write!(path, files) do
    Mix.ensure_application!(:crypto)
    %{"VERSION" => version, "metadata.config" => metadata, "contents.tar.gz" => contents} = files
    checksum = :crypto.hash(:sha256, [version, metadata, contents]) |> Base.encode16()

    :ok =
      :erl_tar.create(String.to_charlist(path), [
        {~c"VERSION", version},
        {~c"CHECKSUM", checksum},
        {~c"metadata.config", metadata},
        {~c"contents.tar.gz", contents}
      ])
  end

  defp parse!(metadata) do
    {:ok, tokens, _end} = metadata |> :unicode.characters_to_list() |> :erl_scan.string()

    tokens
    |> Enum.chunk_while(
      [],
      fn
        {:dot, _} = dot, form -> {:cont, Enum.reverse([dot | form]), []}
        token, form -> {:cont, [token | form]}
      end,
      fn form -> {:cont, Enum.reverse(form), []} end
    )
    |> Enum.reject(&(&1 == []))
    |> Enum.map(fn form ->
      {:ok, term} = :erl_parse.parse_term(form)
      term
    end)
  end

  # As Hex writes it
  defp encode(terms) do
    terms |> Enum.map(&:io_lib.format("~tp.~n", [&1])) |> :unicode.characters_to_binary()
  end
end
