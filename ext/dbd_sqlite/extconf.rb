require "mkmf"

dir_config "SQLite"

if find_library("sqlite", "sqlite_open") and have_header("sqlite.h")
  create_makefile "SQLite"
end
