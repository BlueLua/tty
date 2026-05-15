# tty 🔳

Small cross-platform Lua bindings for terminal inspection.

Supports Lua 5.1, 5.2, 5.3, 5.4, 5.5, and LuaJIT.

## Install

```bash
luarocks install tty
```

## API

### `isatty(fd?)` -> boolean

Check whether a file descriptor or Lua file handle is attached to a terminal.

```lua
local tty = require "tty"
print(tty.isatty())
print(tty.isatty(2))
print(tty.isatty(io.stdout))
```

### `size(fd?)` -> rows, cols

Get the terminal size for stdout, or for a specific file descriptor or Lua file
handle.

```lua
local rows, cols = tty.size()
print(("terminal: %dx%d"):format(cols, rows))
```
