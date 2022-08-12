import std/unittest
import mockuppkg/videos

test "seek video":
  var video = newVideo("assets/mockup.mp4", 0)
  video.seek(100)