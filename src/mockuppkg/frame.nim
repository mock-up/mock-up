from ffmpeg import AVFrame, av_frame_alloc, av_image_get_buffer_size, av_malloc, AV_PIX_FMT_YUV420P, av_image_fill_arrays
import options

type
  Frame* = object
    ptrFrame: ptr ptr AVFrame

proc init* (width, height: int): Option[Frame] =
  var frame: ptr ptr AVFrame
  frame[] = av_frame_alloc()
  if frame[] == nil:
    raise newException(OSError, "can't allocate frame.")
  var
    numBytes = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, width.cint, height.cint, 1.cint)
    buffer = av_malloc((numBytes * sizeof(uint8)).csize_t)
  if buffer == nil:
    return none(Frame)
  var
    empty_arr: array[4, ptr uint8]
    empty_arr2: array[4, cint]
  discard av_image_fill_arrays(empty_arr, empty_arr2, cast[ptr uint8](buffer), AV_PIX_FMT_YUV420P, width.cint, height.cint, 1.cint)
  result = some(Frame(ptrFrame: frame))