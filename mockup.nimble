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
requires "https://github.com/mock-up/nagu"
requires "https://github.com/mock-up/muml.nim"
