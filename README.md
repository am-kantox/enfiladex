# Enfiladex

**Wrapper for executing `ExUnit` as `common_test` **

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
- `MIX_ENV=test iex --sname am -S mix enfiladex` (named node) to execute common test,
- compiled `beam` files are not yet removed. 

[Documentation](https://hexdocs.pm/enfiladex).

