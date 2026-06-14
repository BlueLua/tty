#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>

#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <io.h>
#include <stdint.h>
#include <stdlib.h>
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#endif

#if LUA_VERSION_NUM == 501
#define tty_lua_newlib(L, funcs)                                               \
  (lua_newtable((L)), luaL_register((L), NULL, (funcs)))
#else
#define tty_lua_newlib(L, funcs) luaL_newlib((L), (funcs))
#endif

#define TTY_DEFAULT_FD 1

#if defined(_WIN32)
static int tty_windows_fileno(FILE *file);
static intptr_t tty_windows_get_osfhandle(int fd);
#endif

static void *tty_testudata(lua_State *L, int index, const char *type_name) {
  void *userdata = lua_touserdata(L, index);
  if (userdata == NULL) {
    return NULL;
  }

  if (!lua_getmetatable(L, index)) {
    return NULL;
  }

  luaL_getmetatable(L, type_name);
  if (!lua_rawequal(L, -1, -2)) {
    lua_pop(L, 2);
    return NULL;
  }

  lua_pop(L, 2);
  return userdata;
}

static int tty_argerror_fd(lua_State *L, int index) {
  return luaL_argerror(
      L, index,
      "expected a non-negative integer file descriptor or Lua file handle");
}

static int tty_invalid_fd_error(lua_State *L, const char *function_name,
                                int fd) {
#if defined(_WIN32)
  if (errno != 0) {
    return luaL_error(L, "%s: invalid file descriptor %d: %s", function_name,
                      fd, strerror(errno));
  }

  return luaL_error(L, "%s: invalid file descriptor %d", function_name, fd);
#else
  return luaL_error(L, "%s: invalid file descriptor %d: %s", function_name, fd,
                    strerror(EBADF));
#endif
}

static int tty_push_size_result(lua_State *L, int fd, lua_Integer rows,
                                lua_Integer cols) {
  if (rows <= 0 || cols <= 0) {
    return luaL_error(L,
                      "tty.size: failed to get terminal size for fd %d: "
                      "terminal returned zero dimensions",
                      fd);
  }

  lua_pushinteger(L, rows);
  lua_pushinteger(L, cols);
  return 2;
}

static int tty_check_numeric_fd(lua_State *L, int index) {
  lua_Number number = lua_tonumber(L, index);
  int fd;

  if (number != number || number < 0 || number > (lua_Number)INT_MAX) {
    return tty_argerror_fd(L, index);
  }

  fd = (int)number;
  if ((lua_Number)fd != number) {
    return tty_argerror_fd(L, index);
  }

  return fd;
}

static FILE *tty_check_file(lua_State *L, int index) {
#if LUA_VERSION_NUM == 501
  FILE **handle = (FILE **)tty_testudata(L, index, LUA_FILEHANDLE);
  if (handle == NULL) {
    tty_argerror_fd(L, index);
  }

  if (*handle == NULL) {
    luaL_argerror(L, index, "file handle is closed");
  }

  return *handle;
#else
  luaL_Stream *handle = (luaL_Stream *)tty_testudata(L, index, LUA_FILEHANDLE);
  if (handle == NULL) {
    tty_argerror_fd(L, index);
  }

  if (handle->closef == NULL || handle->f == NULL) {
    luaL_argerror(L, index, "file handle is closed");
  }

  return handle->f;
#endif
}

static int tty_check_file_fd(lua_State *L, int index) {
  FILE *file = tty_check_file(L, index);
  int fd;

  errno = 0;
#if defined(_WIN32)
  fd = tty_windows_fileno(file);
#else
  fd = fileno(file);
#endif

  if (fd < 0) {
    if (errno != 0) {
      luaL_argerror(L, index, strerror(errno));
    }

    luaL_argerror(L, index, "file handle has no file descriptor");
  }

  return fd;
}

static int tty_check_fd(lua_State *L, int index) {
  int type = lua_type(L, index);

  if (lua_isnoneornil(L, index)) {
    return TTY_DEFAULT_FD;
  }

  if (type == LUA_TNUMBER) {
    return tty_check_numeric_fd(L, index);
  }

  if (type == LUA_TUSERDATA) {
    return tty_check_file_fd(L, index);
  }

  return tty_argerror_fd(L, index);
}

#if defined(_WIN32)
#if defined(_MSC_VER)
static void tty_ignore_invalid_parameter(const wchar_t *expression,
                                         const wchar_t *function_name,
                                         const wchar_t *file_name,
                                         unsigned int line,
                                         uintptr_t reserved) {
  (void)expression;
  (void)function_name;
  (void)file_name;
  (void)line;
  (void)reserved;
}
#endif

static int tty_windows_fileno(FILE *file) {
  int fd;

#if defined(_MSC_VER)
  _invalid_parameter_handler previous =
      _set_thread_local_invalid_parameter_handler(tty_ignore_invalid_parameter);
#endif

  fd = _fileno(file);

#if defined(_MSC_VER)
  _set_thread_local_invalid_parameter_handler(previous);
#endif

  return fd;
}

static intptr_t tty_windows_get_osfhandle(int fd) {
  intptr_t handle;

#if defined(_MSC_VER)
  _invalid_parameter_handler previous =
      _set_thread_local_invalid_parameter_handler(tty_ignore_invalid_parameter);
#endif

  handle = _get_osfhandle(fd);

#if defined(_MSC_VER)
  _set_thread_local_invalid_parameter_handler(previous);
#endif

  return handle;
}

static const char *tty_windows_error_message(DWORD code, char *buffer,
                                             size_t buffer_size) {
  DWORD length;

  if (buffer_size == 0) {
    return "unknown Windows error";
  }

  length =
      FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                     NULL, code, 0, buffer, (DWORD)buffer_size, NULL);

  if (length == 0) {
    return "unknown Windows error";
  }

  while (length > 0 &&
         (buffer[length - 1] == '\n' || buffer[length - 1] == '\r' ||
          buffer[length - 1] == '.')) {
    buffer[length - 1] = '\0';
    length--;
  }

  return buffer;
}

static HANDLE tty_check_windows_handle(lua_State *L, const char *function_name,
                                       int fd) {
  intptr_t os_handle;

  errno = 0;
  os_handle = tty_windows_get_osfhandle(fd);
  if (os_handle == (intptr_t)-1) {
    tty_invalid_fd_error(L, function_name, fd);
    return INVALID_HANDLE_VALUE;
  }

  return (HANDLE)os_handle;
}

static int tty_push_is_tty(lua_State *L, int fd) {
  HANDLE handle = tty_check_windows_handle(L, "tty.isatty", fd);
  DWORD mode;

  lua_pushboolean(L, GetConsoleMode(handle, &mode) != 0);
  return 1;
}

static int
tty_get_console_screen_buffer_info(HANDLE handle,
                                   CONSOLE_SCREEN_BUFFER_INFO *info) {
  HANDLE output;
  DWORD mode;
  DWORD code;
  int ok;

  if (GetConsoleScreenBufferInfo(handle, info)) {
    return 1;
  }

  if (!GetConsoleMode(handle, &mode)) {
    return 0;
  }

  output =
      CreateFileA("CONOUT$", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                  NULL, OPEN_EXISTING, 0, NULL);
  if (output == INVALID_HANDLE_VALUE) {
    return 0;
  }

  ok = GetConsoleScreenBufferInfo(output, info);
  code = GetLastError();
  CloseHandle(output);
  if (!ok) {
    SetLastError(code);
  }

  return ok;
}

static int tty_push_size(lua_State *L, int fd) {
  HANDLE handle = tty_check_windows_handle(L, "tty.size", fd);
  CONSOLE_SCREEN_BUFFER_INFO info;

  if (!tty_get_console_screen_buffer_info(handle, &info)) {
    DWORD code = GetLastError();
    char code_string[32];
    char message[256];
    sprintf(code_string, "%lu", (unsigned long)code);
    return luaL_error(
        L,
        "tty.size: failed to get terminal size for fd %d: Windows error %s: "
        "%s",
        fd, code_string,
        tty_windows_error_message(code, message, sizeof(message)));
  }

  return tty_push_size_result(
      L, fd, (lua_Integer)(info.srWindow.Bottom - info.srWindow.Top + 1),
      (lua_Integer)(info.srWindow.Right - info.srWindow.Left + 1));
}
#else
static int tty_validate_fd(lua_State *L, const char *function_name, int fd) {
  errno = 0;
  if (fcntl(fd, F_GETFD) == -1 && errno == EBADF) {
    return tty_invalid_fd_error(L, function_name, fd);
  }

  return 0;
}

static int tty_push_is_tty(lua_State *L, int fd) {
  int result;

  tty_validate_fd(L, "tty.isatty", fd);

  errno = 0;
  result = isatty(fd);

  if (result == 1) {
    lua_pushboolean(L, 1);
    return 1;
  }

  if (errno == EBADF) {
    return tty_invalid_fd_error(L, "tty.isatty", fd);
  }

  lua_pushboolean(L, 0);
  return 1;
}

static int tty_push_size(lua_State *L, int fd) {
  struct winsize size;

  tty_validate_fd(L, "tty.size", fd);

  errno = 0;
  memset(&size, 0, sizeof(size));

  if (ioctl(fd, TIOCGWINSZ, &size) == -1) {
    return luaL_error(L, "tty.size: failed to get terminal size for fd %d: %s",
                      fd, strerror(errno));
  }

  return tty_push_size_result(L, fd, (lua_Integer)size.ws_row,
                              (lua_Integer)size.ws_col);
}
#endif

static int tty_isatty(lua_State *L) {
  int fd = tty_check_fd(L, 1);
  return tty_push_is_tty(L, fd);
}

static int tty_size(lua_State *L) {
  int fd = tty_check_fd(L, 1);
  return tty_push_size(L, fd);
}

static const luaL_Reg tty_functions[] = {
    {"isatty", tty_isatty},
    {"size", tty_size},
    {NULL, NULL},
};

LUALIB_API int luaopen_tty(lua_State *L) {
  tty_lua_newlib(L, tty_functions);
  lua_pushliteral(L, "tty 0.1.0"); /* x-release-please-version */
  lua_setfield(L, -2, "_VERSION");
  return 1;
}
