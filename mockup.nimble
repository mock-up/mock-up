# Package

version       = "0.0.1"
author        = "momeemt"
description   = "Movie Compilation Kit with Unified and Progressive"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
binDir        = "bin"
bin           = @["mockup"]

# Dependencies

requires "nim >= 1.4.4"
requires "ffmpeg >= 0.5.3"
requires "cligen >= 1.5.2"
requires "nimgl >= 1.3.2"
requires "glm >= 1.1.1"
requires "neo >= 0.3.1"
requires "jester >= 0.5.0"
requires "nagu"
requires "muml"
requires "uuids == 0.1.11"

# Tasks
task ci, "Run CI":
  exec "nim -v"
  exec "nimble -v"
  exec "nimble check"
  exec "nimble install -Y"
  exec "nimble test -Y"
  exec "nimble docs -Y"
  exec "nimble build -d:release -Y"
  exec "./bin/mockup -h"
  exec "./bin/mockup -v"

task docs, "Generate documents":
  rmDir "docs"
  exec "nimble doc --project --index:on -o:docs -Y src/mockup.nim"

task docsCi, "Run Docs CI":
  exec "nim -v"
  exec "nimble -v"
  exec "nimble check"
  exec "nimble install -Y"
  exec "nimble docs -Y"
