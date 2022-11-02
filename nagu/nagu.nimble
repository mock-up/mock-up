# Package

version       = "0.1.0"
author        = "momeemt"
description   = "Nim Abstract OpenGL Utility"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.6.2"
requires "nimgl == 1.3.2"
requires "glm == 1.1.1"
requires "Palette == 0.2.1"

# Tasks

## https://qiita.com/SFITB/items/dceb1537e4086fa696d2
task test, "run all tests":
  exec "testament cat /"

## https://github.com/jiro4989/maze/blob/master/maze.nimble
task docs, "Generate documents":
  rmDir "docs"
  exec "nimble doc --project --index:on -o:docs src/nagu.nim"

task docsCi, "Run Docs CI":
  exec "nim -v"
  exec "nimble -v"
  exec "nimble check"
  exec "nimble install -Y"
  exec "nimble docs -Y"

task mainCi, "Run CI":
  exec "nimble docsCi"
  exec "nimble test -Y"

task dev, "dev envoironment":
  exec "cd example && nimble -d:debuggingOpenGL run"

task release, "release environment":
  exec "cd example && nimble run --silent"