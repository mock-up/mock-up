# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import mockup_ffmpeg/h264
import mockup_ffmpeg/results
import macros

{.experimental: "caseStmtMacros".}

test "decode cloud.mp4":
  proc main (): Result[(), string] =
    var movie = ?openH264("tests/testdata/cloud.mp4")
    echo movie.width

    for frame in movie.decodeH264:
      discard

  let res = main()
  case res
  of ok(o):
    check true
  of err(e):
    echo e
    check false
