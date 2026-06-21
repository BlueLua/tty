local tty = require "tty"

local function tempfile()
  local name = os.tmpname()
  local file = assert(io.open(name, "w+"))
  return file, name
end

describe("tty", function()
  it("should expose correct types", function()
    assert.Table(tty)
    assert.Function(tty.isatty)
    assert.Function(tty.size)
    assert.String(tty._VERSION)
  end)

  describe("isatty()", function()
    it("defaults to stdout", function()
      local stdout_is_tty = tty.isatty()
      assert.Boolean(stdout_is_tty)
      assert.Equal(stdout_is_tty, tty.isatty())
      assert.Equal(stdout_is_tty, tty.isatty(1))
      assert.Equal(stdout_is_tty, tty.isatty(io.stdout))
    end)

    it("should handle stderr", function()
      local stderr_is_tty = tty.isatty(2)
      assert.Boolean(stderr_is_tty)
      assert.Equal(stderr_is_tty, tty.isatty(io.stderr))
    end)

    it("should return false for a regular file handle", function()
      local file, name = tempfile()
      finally(function()
        file:close()
        os.remove(name)
      end)
      assert.False(tty.isatty(file))
    end)

    it("should reject invalid arguments", function()
      local err = "bad argument #1 to 'isatty' (expected a non-negative integer file descriptor or Lua file handle)"

      -- stylua: ignore start
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.Error(function() _ = tty.isatty("1") end, err)
      assert.Error(function() _ = tty.isatty(-1)  end, err)
      assert.Error(function() _ = tty.isatty(1.5) end, err)
      assert.Error(function() _ = tty.isatty({})  end, err)
      -- stylua: ignore end

      ---@diagnostic disable-next-line: undefined-field
      assert.Throw(function()
        _ = tty.isatty(1000000)
        ---@diagnostic disable: param-type-mismatch, discard-returns
      end, "invalid file descriptor")
    end)

    it("should error when checking a closed file", function()
      local file, name = tempfile()
      file:close()
      finally(function()
        os.remove(name)
      end)

      ---@diagnostic disable-next-line: undefined-field
      assert.Throw(function()
        tty.isatty(file)
      end, "closed")
    end)
  end)

  describe("size()", function()
    it("should return terminal size or error appropriately for stdout", function()
      local stdout_is_tty = tty.isatty()
      if stdout_is_tty then
        local rows, cols = tty.size()
        assert.Number(rows)
        assert.Number(cols)
        assert.True(rows >= 1)
        assert.True(cols >= 1)
      else
        ---@diagnostic disable-next-line: undefined-field
        assert.Throw(function()
          tty.size()
        end, "failed to get terminal size")
      end
    end)

    it("should return terminal size or error appropriately for stderr", function()
      local stderr_is_tty = tty.isatty(2)
      if stderr_is_tty then
        local terminal_rows, terminal_cols = tty.size(io.stderr)
        assert.Number(terminal_rows)
        assert.Number(terminal_cols)
        assert.True(terminal_rows >= 1)
        assert.True(terminal_cols >= 1)
      else
        ---@diagnostic disable-next-line: undefined-field
        assert.Throw(function()
          tty.size(io.stderr)
        end, "failed to get terminal size")
      end
    end)

    it("should error for a regular file handle", function()
      local file, name = tempfile()
      finally(function()
        file:close()
        os.remove(name)
      end)

      ---@diagnostic disable-next-line: undefined-field
      assert.Throw(function()
        tty.size(file)
      end, "failed to get terminal size")
    end)

    it("should reject invalid numeric file descriptors", function()
      ---@diagnostic disable-next-line: undefined-field
      assert.Throw(function()
        tty.size(1000000)
      end, "invalid file descriptor")
    end)

    it("should error when querying size of a closed file", function()
      local closed, closed_name = tempfile()
      closed:close()
      finally(function()
        if closed_name then
          os.remove(closed_name)
        end
      end)

      ---@diagnostic disable-next-line: undefined-field
      assert.Throw(function()
        tty.size(closed)
      end, "closed")
    end)
  end)
end)
