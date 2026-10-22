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

In the project that uses the package:

```elixir
{:my_package, "~> 0.1", repo: "heck"}
```

or, with [Igniter](https://hexdocs.pm/igniter):

```bash
mix igniter.install heck.my_package
```

Publishing a version again replaces it. Projects that already fetched it then
need `mix deps.unlock my_package` and `mix deps.get`, as their `mix.lock` has
its previous checksum.

The dependencies of a published package come from hex.pm, except the ones
published to heck, which come from heck. So to try out packages that depend on
each other, publish the dependencies first.

## The server

Hex only fetches packages over HTTP, so heck serves the repository, on port
4325, or any free port if that's busy. `--port` or `HECK_PORT` picks the port
instead. `mix heck.publish` starts the server in the background, if it isn't
running yet.

```bash
mix heck.status   # Whether the server runs, and the packages it serves
mix heck.start    # Starts the server in the background
mix heck.stop     # Stops it
mix heck.server   # Serves in the foreground, logging the requests
```

The server records where it runs in `server.json` in the heck home, and logs to
`server.log` there. When it isn't running, Hex uses the packages it has cached,
and otherwise fails with "Package fetch failed and no cached copy available".

A Hex home knows one `heck` repository, so heck runs one server at a time for
it, serving one heck home, see [heck and Hex homes](#heck-and-hex-homes). While
it runs, heck refuses to start another, on another port or for another heck
home, or to publish to another heck home. Commands that start or stop the server
wait for each other, so ones run at the same time start one server too.

## How it works

`mix heck.publish` builds the package with `mix hex.build`, adds the tarball to
a registry made with `mix hex.registry build`, signed with a key of heck's own,
and registers the repository with Hex as `heck`. The repository lives in
`~/.heck`, or in `HECK_HOME`.

The server also tells Igniter the latest version of a package, which
`mix igniter.install` asks for.

## heck and Hex homes

To try packages out separately from the usual setup, for example in CI, give
them a heck home and a Hex home of their own. Then set them for every command,
including the ones in the projects that use the packages. Their server gets a
free port, if the usual one runs on 4325:

```bash
export HECK_HOME=/tmp/try/heck HEX_HOME=/tmp/try/hex

cd my_package && mix heck.publish
cd ../my_app && mix deps.get
```

Without `HEX_HOME`, `my_app` would get its packages from the usual setup's
server, or fail with `Unknown repository "heck"` if there's none.

## Limitations

- Projects refer to the packages with `repo: "heck"`, which shouldn't be
  committed.
