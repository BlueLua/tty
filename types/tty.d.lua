---@meta tty

---@alias tty.fd integer|file* A file descriptor number or a Lua file handle.

local version = "tty 0.0.0" -- x-release-please-version

---
---Terminal helpers for checking TTY state and reading terminal dimensions.
---
---@class tty
local M = {
  _VERSION = version,
}

---
---Check whether a file descriptor or Lua file handle is attached to a terminal.
---
---```lua
---local tty = require "tty"
---
---print(tty.isatty())
---print(tty.isatty(2))
---print(tty.isatty(io.stdout))
---```
---
---@param fd? tty.fd
---@return boolean isatty
---@nodiscard
function M.isatty(fd) end

---
---Get the terminal size for stdout, or for a specific file descriptor or Lua file handle.
---
---```lua
---local tty = require "tty"
---
---local rows, cols = tty.size()
---print(("terminal: %dx%d"):format(cols, rows))
---```
---
---@param fd? tty.fd
---@return integer rows Number of terminal rows.
---@return integer cols Number of terminal columns.
---@nodiscard
function M.size(fd) end

return M
