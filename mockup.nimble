# Package

version       = "0.1.0"
author        = "momeemt"
description   = "Movie Compilation Kit with Unified and Progressive"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["mockup"]


# Dependencies

requires "nim >= 1.4.4"
requires "ffmpeg >= 0.3.12"
requires "uuids >= 0.1.11"
requires "cligen >= 1.5.2"
