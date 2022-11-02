# Package

version       = "0.0.1"
author        = "Mutsuha Asada"
description   = "mock up markup language parser"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.8"
requires "Palette >= 0.2.1"
requires "uuids >= 0.1.11"

# Tasks
task docs, "Generate documents":
  rmDir "docs"
  exec "nimble doc --project --index:on -o:docs src/muml.nim"

task docsCi, "Run Docs CI":
  exec "nim -v"
  exec "nimble -v"
  exec "nimble check"
  exec "nimble install -Y"
  exec "nimble docs -Y"

task mainCi, "Run CI":
  exec "nimble docsCi"
  exec "nimble test -Y"
