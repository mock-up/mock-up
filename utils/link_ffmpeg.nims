import strutils, strformat

const
  FFmpegDylibDirPath = "/opt/homebrew/Cellar/ffmpeg/5.0.1_3/lib"
  LocalLibDirPath = "/usr/local/lib"
  LibNames = @[
    "libavcodec.59.18.100",
    "libavdevice.59.4.100",
    "libavfilter.8.24.100",
    "libavformat.59.16.100",
    "libavutil.57.17.100",
    "libpostproc.56.3.100",
    "libswresample.4.3.100",
    "libswscale.6.4.100"
  ]

proc unlinkAndLink (full_lib_name: string) =
  let lib_name = full_lib_name.split(".")[0..1].join(".")
  exec &"unlink {LocalLibDirPath}/{lib_name}.dylib"
  exec &"ln -s {FFmpegDylibDirPath}/{full_lib_name}.dylib {LocalLibDirPath}/{lib_name}.dylib"

for lib_name in LibNames:
  unlinkAndLink(lib_name)
