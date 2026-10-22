# heck

A local Hex repository, for trying packages out before publishing them.

Publish a package to it, and depend on it from any project on your machine as
if it came from Hex, with the package's `hex.build` alias, its files and its
dependencies exactly as they will be on hex.pm.

## Installation

```bash
mix archive.install hex heck
```

## Usage

In the package's project:

```bash
mix heck.publish
```

Anywhere, to serve the repository:

```bash
mix heck.server
```

In the project that uses the package:

```elixir
{:my_package, "~> 0.1", repo: "local"}
```

or, with [Igniter](https://hexdocs.pm/igniter):

```bash
mix igniter.install local.my_package
```

Publishing a version again replaces it. Projects that already fetched it then
need `mix deps.unlock my_package` and `mix deps.get`, as their `mix.lock` has
its previous checksum.

## How it works

`mix heck.publish` builds the package with `mix hex.build`, adds the tarball to
a registry made with `mix hex.registry build`, signed with a key of heck's own,
and registers the repository with Hex as `local`. The repository lives in
`~/.heck`, or in `HECK_HOME`.

Hex only fetches packages over HTTP, so `mix heck.server` serves the registry,
on port 4325, or on `HECK_PORT`. It needs to run whenever projects fetch
packages from it, for example in `mix deps.get`. It also tells Igniter the
latest version of a package, which `mix igniter.install` asks for.

The dependencies of a published package come from hex.pm, except the ones
published to heck, which come from heck. So to try out packages that depend on
each other, publish the dependencies first.

## Limitations

  * Projects refer to the packages with `repo: "local"`, which shouldn't be
    committed.
