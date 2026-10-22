# Heck

A local Hex repository, for trying packages out before publishing them.

Publish a package to it, and depend on it from any project on your machine as
if it came from Hex.

The library is vibe coded, this readme is mostly hand-written.

## Why

Imagine you're about to ship a brand new version of your lib. It works both locally and on CI, so you publish on Hex, and suddenly someone reports it doesn't even compile. _What the heck?_

That's likely because of subtle differences between path, Git and Hex dependencies. For example:

- Hex doesn't ship all the files you have in your project - anything custom, such as non-Elixir source files, must be listed explicitly
- Hex stores deps in a registry, while for Git/path deps `mix.exs` is always run
- Path deps are recompiled each time the project recompiles, for Git/Hex ones you need `mix deps.compile ...`
- If you have only path deps, you don't even need `mix deps.get`

These can bite the most when you do something uncommon, like complex Igniter setup, custom targets, or non-Elixir code.

So, how can you verify that a lib works on Hex without actually publishing it there? Use Heck!

## Installation

```bash
mix archive.install github mat-hek/heck
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
need `mix heck.refetch`, which fetches their heck packages again. Without it,
they keep building the previous one, and fetching fails with "Registry checksum
mismatch against lock", as their `mix.lock` has its previous checksum.

The dependencies of a published package come from hex.pm, except the ones
published to heck, which come from heck. So to try out packages that depend on
each other, publish the dependencies first.

To remove packages:

```bash
mix heck.unpublish my_package         # All its versions
mix heck.unpublish my_package 0.1.0   # One version
mix heck.clean                        # All packages
```

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
`server.log` there. When it isn't running, Hex may throw an error, but also use the packages it has cached.

## How it works

`mix heck.publish` builds the package with `mix hex.build`, adds the tarball to
a registry made with `mix hex.registry build`, signed with a key of heck's own,
and registers the repository with Hex as `heck`. The repository lives in
`~/.heck`, or in `HECK_HOME`.

The server also tells Igniter the latest version of a package, which
`mix igniter.install` asks for.

## Sandboxing

Heck being global per machine may be problematic when working with multiple projects
simultaneously, especially for agentic workflows. To mitigate that, you can create
a separate Heck home and a Hex home per project. Then set them for every command in all relevant projects:

```bash
export HECK_HOME=/tmp/try/heck HEX_HOME=/tmp/try/hex

cd my_package && mix heck.publish
cd ../my_app && mix deps.get
```

It's especially important that `HEX_HOME` is set in all relevant projects, because Hex may otherwise
serve whatever it has in its cache. Note that Heck runs a separate server for each `HECK_HOME`.

## License

MIT, see [LICENSE](LICENSE).
