---@diagnostic disable: param-type-mismatch, discard-returns

local tty = require "tty"

local function fail(msg)
  error(msg, 2)
end

local function assertEqual(actual, expected, msg)
  if actual ~= expected then
    fail(("%s: expected %s, got %s"):format(msg or "values differ", tostring(expected), tostring(actual)))
  end
end

local function assertType(v, expectedType, msg)
  if type(v) ~= expectedType then
    fail(("%s: expected %s, got %s"):format(msg or "unexpected type", expectedType, type(v)))
  end
end

local function assertErrorContains(fn, expected, msg)
  local ok, err = pcall(fn)
  if ok then
    fail((msg or "expected error") .. ": call succeeded")
  end

  err = tostring(err)
  if not err:find(expected, 1, true) then
    fail(("%s: expected error containing %q, got %q"):format(msg or "wrong error", expected, err))
  end
end

local function openTempFile()
  local file = io.tmpfile()
  if file then
    return file, nil
  end

  local name = os.tmpname()
  file = assert(io.open(name, "w+"))
  return file, name
end

local function closeTempFile(file, name)
  if file then
    pcall(function()
      file:close()
    end)
  end

  if name then
    os.remove(name)
  end
end

assertType(tty, "table", "module")
assertType(tty.isatty, "function", "tty.isatty")
assertType(tty.size, "function", "tty.size")

local stdoutIsTTY = tty.isatty()
assertType(stdoutIsTTY, "boolean", "tty.isatty()")
assertEqual(tty.isatty(nil), stdoutIsTTY, "nil defaults to stdout")
assertEqual(tty.isatty(1), stdoutIsTTY, "numeric stdout fd")
assertEqual(tty.isatty(io.stdout), stdoutIsTTY, "stdout file handle")

local stderrIsTTY = tty.isatty(2)
assertType(stderrIsTTY, "boolean", "tty.isatty(2)")
assertEqual(tty.isatty(io.stderr), stderrIsTTY, "stderr file handle")

local temp, tempName = openTempFile()
assertEqual(tty.isatty(temp), false, "regular file handle")
assertErrorContains(function()
  tty.size(temp)
end, "failed to get terminal size", "regular file size")
closeTempFile(temp, tempName)

if stdoutIsTTY then
  local terminalRows, terminalCols = tty.size()
  local nilRows, nilCols = tty.size(nil)
  assertType(terminalRows, "number", "tty.size() rows")
  assertType(terminalCols, "number", "tty.size() cols")
  assertType(nilRows, "number", "tty.size(nil) rows")
  assertType(nilCols, "number", "tty.size(nil) cols")
  if terminalRows < 1 or terminalCols < 1 then
    fail(("tty.size() returned invalid dimensions %s x %s"):format(tostring(terminalRows), tostring(terminalCols)))
  end
  if nilRows < 1 or nilCols < 1 then
    fail(("tty.size(nil) returned invalid dimensions %s x %s"):format(tostring(nilRows), tostring(nilCols)))
  end
else
  assertErrorContains(function()
    tty.size()
  end, "failed to get terminal size", "redirected stdout size")
  assertErrorContains(function()
    tty.size(nil)
  end, "failed to get terminal size", "redirected nil size")
end

if stderrIsTTY then
  local terminalRows, terminalCols = tty.size(io.stderr)
  assertType(terminalRows, "number", "tty.size(io.stderr) rows")
  assertType(terminalCols, "number", "tty.size(io.stderr) cols")
  if terminalRows < 1 or terminalCols < 1 then
    fail(
      ("tty.size(io.stderr) returned invalid dimensions %s x %s"):format(tostring(terminalRows), tostring(terminalCols))
    )
  end
else
  assertErrorContains(function()
    tty.size(io.stderr)
  end, "failed to get terminal size", "redirected stderr size")
end

-- stylua: ignore start
assertErrorContains(function() tty.isatty("1")     end, "file descriptor", "string fd")
assertErrorContains(function() tty.isatty(-1)      end, "file descriptor", "negative fd")
assertErrorContains(function() tty.isatty(1.5)     end, "file descriptor", "fractional fd")
assertErrorContains(function() tty.isatty({})      end, "file descriptor", "table fd")
assertErrorContains(function() tty.isatty(1000000) end, "invalid file descriptor", "invalid numeric fd")
assertErrorContains(function() tty.size(1000000)  end, "invalid file descriptor", "invalid numeric size fd")

local closed, closedName = openTempFile()
closed:close()
assertErrorContains(function() tty.isatty(closed) end, "closed", "closed file isatty")
assertErrorContains(function() tty.size(closed)  end, "closed", "closed file size")
if closedName then
  os.remove(closedName)
end
-- stylua: ignore end

print("tty tests passed")
