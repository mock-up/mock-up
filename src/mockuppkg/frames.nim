from ffmpeg import nil

type
  Frame* = object
    av_frame: ptr ffmpeg.AVFrame

proc initFrame (height, width: int32): Frame =
  result.av_frame = ffmpeg.av_frame_alloc()
  result.av_frame[].format = ffmpeg.AV_PIX_FMT_RGB24.cint
  result.av_frame[].height = height
  result.av_frame[].width = width

proc copy* (src: Frame): Frame =
  result.av_frame = ffmpeg.av_frame_alloc()
  result.av_frame[].format = src.av_frame[].format
  result.av_frame[].height = src.av_frame[].height
  result.av_frame[].width = src.av_frame[].width
  result.av_frame[].channels = src.av_frame[].channels
  result.av_frame[].channel_layout = src.av_frame[].channel_layout
  result.av_frame[].nb_samples = src.av_frame[].nb_samples
  result.av_frame[].pts = src.av_frame[].pts
