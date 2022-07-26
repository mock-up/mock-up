import ffmpeg

type
  VideoCodecKind* = enum
    vck_mpeg4 = AV_CODEC_ID_MPEG4
    vck_H264 = AV_CODEC_ID_H264
  
  VideoEncoder* = object
    ffmpeg_codec: ptr AVCodec
    ffmpeg_codec_context: ptr AVCodecContext

  VideoFrameFormat* {.pure.} = enum
    vff_unknown_or_unset = AV_PIX_FMT_NONE
    vff_YUV420P = AV_PIX_FMT_YUV420P
    vff_YUYV422 = AV_PIX_FMT_YUYV422
    vff_RGB24 = AV_PIX_FMT_RGB24
    vff_BGR24 = AV_PIX_FMT_BGR24
    vff_YUV422P = AV_PIX_FMT_YUV422P
    
    vff_RGBA = AV_PIX_FMT_RGBA
    # WIP
  
  VideoFrame* = object
    ffmpeg_frame: ptr AVFrame
  
  FFmpegDefect* = object of Defect