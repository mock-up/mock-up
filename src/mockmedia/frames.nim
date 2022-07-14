import ffmpeg
import std/importutils
from types import FFmpegDefect, VideoFrame, VideoFrameFormat, VideoEncoder
import codecs

VideoFrame.privateAccess

func width* (frame: VideoFrame): int =
  result = frame.ffmpeg_frame[].width

func height* (frame: VideoFrame): int =
  result = frame.ffmpeg_frame[].height

func timeBase* (frame: VideoFrame): AVRational =
  result = frame.ffmpeg_frame[].time_base

proc `width=`* (frame: var VideoFrame, width: int32) =
  frame.ffmpeg_frame[].width = width

proc `height=`* (frame: var VideoFrame, height: int32) =
  frame.ffmpeg_frame[].height = height

proc `format=`* (frame: var VideoFrame, format: VideoFrameFormat) =
  # FIXME: should do safety-cast
  frame.ffmpeg_frame[].format = cast[AVPixelFormat](format).cint

func `//`* (numerator, denominator: int32): AVRational =
  result = av_make_q(numerator, denominator)

proc `fps=`* (frame: var VideoFrame, fps: int32) =
  frame.ffmpeg_frame[].time_base = 1 // fps

proc `timebase=`* (frame: var VideoFrame, time_base: AVRational) =
  frame.ffmpeg_frame[].time_base = time_base

proc `frameNumber=`* (frame: var VideoFrame, frame_number: int32) =
  # FIXME: cqをcodec_context->time_baseに相当するものに修正
  frame.ffmpeg_frame[].pts = av_rescale_q(frame_number, frame.timeBase, frame.timeBase)

proc init* (_: typedesc[VideoFrame], width, height, fps: int32): VideoFrame =
  result = VideoFrame()
  result.ffmpeg_frame = av_frame_alloc()
  if result.ffmpeg_frame.isNil:
    raise newException(FFmpegDefect, "could not allocate video frame")
  result.format = vff_RGBA
  result.width = width
  result.height = height
  result.fps = fps

  if av_frame_get_buffer(result[].ffmpeg_frame, 32) < 0:
    raise newException(FFmpegDefect, "バッファの割り当てに失敗しました")

proc init* (_: typedesc[VideoFrame], encoder: VideoEncoder): VideoFrame =
  result = VideoFrame()
  result.type.privateAccess()
  result.ffmpeg_frame = av_frame_alloc()
  if result.ffmpeg_frame.isNil:
    raise newException(FFmpegDefect, "could not allocate video frame")
  result.format = encoder.format
  result.width = encoder.width
  result.height = encoder.height
  result.timebase = encoder.timeBase

  if av_frame_get_buffer(result.ffmpeg_frame, 0) < 0:
    raise newException(FFmpegDefect, "could not allocate the video frame data")