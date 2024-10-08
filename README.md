# Enfiladex

**Wrapper for executing `ExUnit` as `common_test`**

## Installation

```elixir
def deps do
  [
    {:enfiladex, "~> 0.1"}
  ]
end
```

## Usage

Add `use Enfiladex` to your test to convert it to common test suite. 

## Known issues

- `on_exit/2` callbacks with captures makes test to fail compiling with `use Enfiladex` (`Code.with_diagnostics/2` issue),
- `Enfiladex.{peer/3, multi_peer_/3}` fail from tests with an anonymous function,
- one needs to disable pruning code paths in `mix.exs` as `prune_code_paths: Mix.env() == :prod`, otherwise _Elixir_ won’t find `common_test`
- ~~`MIX_ENV=test iex --sname am -S mix enfiladex` (named node) to execute common test,~~
- ~~compiled `beam` files are not yet removed.~~

[Documentation](https://hexdocs.pm/enfiladex).

## Changelog

- **`0.3.0`** — `Enfiladex.rpc_[block_]call/2`, `Enfiladex.[block_]call_everywhere/3`
- **`0.2.1`** — doctests
- **`0.2.0`** — `start_peers/1`, `stop_peers/1`, self-tested, cleaner interface
