import unittest
import mockup_ffmpeg/h264
import mockup_ffmpeg/results
import macros

{.experimental: "caseStmtMacros".}

template checkResult [T, E] (res: Result[T, E]) =
  case res
  of ok(_):
    check true
  of err(e):
    echo e
    check false

test "decode cloud.mp4":
  proc main (): Result[(), string] =
    var movie = ?openH264("tests/testdata/cloud.mp4")
    for frame in movie.decodeH264:
      discard
  checkResult main()

test "encode H.264 from cloud.mp4":
  proc main (): Result[(), string] =
    var
      src = ?openH264("tests/testdata/cloud.mp4")
    var dest = ?newH264("tests/testdata/out/cloud.mp4", src.width, src.height, src.fps)
    for frame in src.decodeH264:
      discard ?dest.addFrame(frame)
    dest.flush()
  checkResult main()
