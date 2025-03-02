# Lua-ReactiveX [![Build Status](https://travis-ci.org/4O4/lua-reactivex.svg?branch=master)](https://travis-ci.org/4O4/lua-reactivex) [![Coverage Status](https://coveralls.io/repos/github/4O4/lua-reactivex/badge.svg?branch=master)](https://coveralls.io/github/4O4/lua-reactivex?branch=master)

[Reactive Extensions](http://reactivex.io) for Lua.

Lua-ReactiveX gives Lua the power of Observables, which are data structures that represent a stream of values that arrive over time. They're very handy when dealing with events, streams of data, asynchronous requests, and concurrency.

This is a friendly fork of [RxLua](https://github.com/bjornbytes/RxLua). All credits for initial development go to the original author, [bjornbytes](https://github.com/bjornbytes).

This fork includes some fixes and features contributed by the community. There are also foundational changes here in order to introduce a proper automatic unsubscription mechanism which was missing and caused unexpected behavior in some cases. These changes are heavily inspired by the RxJS (5.x) internals, and thus RxJS is considered a reference implementation for all future development of Lua-ReactiveX.

## Getting Started

### Lua

Install with luarocks:

```sh
luarocks install reactivex
```

Or download a portable package from the Releases page, and extract `reactivex.lua` file into your project. Then simply require it:

```lua
local rx = require("reactivex")
```

### Luvit

Install using `lit`:

```sh
lit install 4O4/reactivex
```

Then require it:

```lua
local rx = require("reactivex")
```

### Love2D

See [RxLove](https://github.com/bjornbytes/RxLove). 

## Example Usage

Use ReactiveX to construct a simple cheer:

```lua
local rx = require("reactivex")

rx.Observable.fromRange(1, 8)
  :filter(function(x) return x % 2 == 0 end)
  :concat(rx.Observable.of('who do we appreciate'))
  :map(function(value) return value .. '!' end)
  :subscribe(print)

-- => 2! 4! 6! 8! who do we appreciate!
```

See [examples](examples) for more.

## Resources

- [Documentation](doc)
- [Contributor Guide](doc/CONTRIBUTING.md)
- [ReactiveX Introduction](http://reactivex.io/intro.html)

## Tests

Uses [lust](https://github.com/bjornbytes/lust). Run with:

```
lua tests/runner.lua
```

or, to run a specific test:

```
lua tests/runner.lua skipUntil
```

## License

[MIT](LICENSE)
