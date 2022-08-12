import ffmpeg
import std/importutils
from types import VideoFrameFormat, VideoEncoder, VideoCodecKind, FFmpegDefect

privateAccess(VideoEncoder)

proc `[]=` (codec_context_member: pointer, key: string, value: string) =
  if av_opt_set(codec_context_member, cstring(key), cstring(value), 0) != 0:
    # FIXME: FFmpegエラーをより詳細に解析する
    raise newException(FFmpegDefect, "could not set value")

proc `[]=` (codec_context_member: pointer, key: string, values: tuple[value: string, search_frag: int32]) =
  if av_opt_set(codec_context_member, cstring(key), cstring(values.value), values.search_frag) != 0:
    # FIXME: FFmpegエラーをより詳細に解析する
    raise newException(FFmpegDefect, "could not set value")

func width* (encoder: VideoEncoder): int32 =
  result = encoder.ffmpeg_codec_context[].width

func height* (encoder: VideoEncoder): int32 =
  result = encoder.ffmpeg_codec_context[].height

func format* (encoder: VideoEncoder): VideoFrameFormat =
  result = cast[VideoFrameFormat](encoder.ffmpeg_codec_context[].pix_fmt)

func timeBase* (encoder: VideoEncoder): AVRational =
  result = encoder.ffmpeg_codec_context[].time_base

proc init* (
  _: typedesc[VideoEncoder],
  kind: VideoCodecKind,
  width, height: int32,
  fps: int32,
  format: VideoFrameFormat
): VideoEncoder =
  result = VideoEncoder()
  result.type.privateAccess()

  # new FFmpeg.AVCodec
  result.ffmpeg_codec = avcodec_find_encoder(cast[AVCodecID](kind))
  if result.ffmpeg_codec.isNil:
    raise newException(FFmpegDefect, "codec not found")
  
  # new FFmpeg.AVCodecContext
  result.ffmpeg_codec_context = avcodec_alloc_context3(result.ffmpeg_codec)
  result.ffmpeg_codec_context[].bit_rate = 400000
  result.ffmpeg_codec_context[].width = width
  result.ffmpeg_codec_context[].height = height
  result.ffmpeg_codec_context[].time_base = av_make_q(1, fps)
  result.ffmpeg_codec_context[].framerate = av_make_q(fps, 1)
  result.ffmpeg_codec_context[].gop_size = 10 # ???
  result.ffmpeg_codec_context[].max_b_frames = 1 # ???
  result.ffmpeg_codec_context[].pix_fmt = cast[AVPixelFormat](format)
  if kind == vck_H264:
    result.ffmpeg_codec_context[].priv_data["preset"] = "slow" # ???
  
  if avcodec_open2(result.ffmpeg_codec_context, result.ffmpeg_codec, nil) < 0:
    raise newException(FFmpegDefect, "could not open codec")

