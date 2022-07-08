# Package

version       = "0.1.1"
author        = "momeemt"
description   = "Movie Compilation Kit with Unified and Progressive"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
skipDirs      = @["cli"]
bin           = @["cli/main"]

# Dependencies

requires "nim >= 1.4.4"
requires "ffmpeg >= 0.5.2"
requires "cligen >= 1.5.2"
requires "Palette >= 0.2.0"
requires "muml >= 0.1.0"
# requires "freetype >= 0.1.0"
requires "nimgl >= 1.3.2"
requires "glm >= 1.1.1"
