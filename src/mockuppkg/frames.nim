from ffmpeg import nil
from fp import nil
from Palette import nil

type
  Frame* = object
    av_frame: ptr ffmpeg.AVFrame
  FrameEither* = fp.Either[string, Frame]

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
