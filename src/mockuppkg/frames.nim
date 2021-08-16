from ffmpeg import nil
from fp import nil
from Palette import nil

type
  Frame* = object
    av_frame: ptr ffmpeg.AVFrame
  FrameEither* = fp.Either[string, Frame]
  PixelRowData = tuple[x: int, linesize: cint, datum: ptr uint8]
  Pixel* = object
    x, y: int
    red, green, blue: ptr uint8

proc getFrameEither (frame_either: FrameEither): Frame =
  result = fp.get[string, Frame](frame_either)

proc getAVFrameInFrameEither (frame_either: FrameEither): ptr ffmpeg.AVFrame =
  result = frame_either.getFrameEither.av_frame

proc initFrame* (height, width: int32): FrameEither =
  result = fp.Right[string, Frame](Frame(av_frame: ffmpeg.av_frame_alloc()))
  result.getAVFrameInFrameEither[].format = ffmpeg.AV_PIX_FMT_RGB24.cint
  result.getAVFrameInFrameEither[].height = height
  result.getAVFrameInFrameEither[].width = width
  if ffmpeg.av_frame_get_buffer(fp.get[string, Frame](result).av_frame, 32) < 0:
    result = fp.Left[string, Frame]("Error")

proc copy* (src: Frame): Frame =
  result.av_frame = ffmpeg.av_frame_alloc()
  result.av_frame[].format = src.av_frame[].format
  result.av_frame[].height = src.av_frame[].height
  result.av_frame[].width = src.av_frame[].width
  result.av_frame[].channels = src.av_frame[].channels
  result.av_frame[].channel_layout = src.av_frame[].channel_layout
  result.av_frame[].nb_samples = src.av_frame[].nb_samples
  result.av_frame[].pts = src.av_frame[].pts

proc `[]`* (frame: Frame, x: int): PixelRowData =
  result = (x: x, linesize: frame.av_frame[].linesize[0], datum: frame.av_frame[].data[0])

proc `[]`* (pixelRowData: PixelRowData, y: int): Pixel =
  var index = (y * pixelRowData.linesize + pixelRowData.x * 3).uint
  result = Pixel(
    x: pixelRowData.x, y: y,
    red: cast[ptr uint8](cast[uint](pixelRowData.datum) + index),
    green: cast[ptr uint8](cast[uint](pixelRowData.datum) + index + 1),
    blue: cast[ptr uint8](cast[uint](pixelRowData.datum) + index + 2)
  )

proc rgb* (pixel: Pixel): Palette.tRGB =
  result = (
    Palette.tBinaryRange(pixel.red[]),
    Palette.tBinaryRange(pixel.green[]),
    Palette.tBinaryRange(pixel.blue[])
  )

proc `rgb=`* (pixel: Pixel, color: Palette.tRGB): Palette.tRGB =
  pixel.red[] = color.red.uint8
  pixel.green[] = color.green.uint8
  pixel.blue[] = color.blue.uint8