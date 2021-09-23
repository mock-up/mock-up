from ffmpeg import nil
from nimgl/opengl as gl import nil
import Palette

type
  MockupVideo* = object
    ## FFmpegは露出させたくない: ユーザーはMockupVideoだけに注力する
    path: string ## 動画の参照パス
    format_context: ptr ffmpeg.AVFormatContext
    codec_param: ptr ffmpeg.AVCodecParameters
    codec: ptr ffmpeg.AVCodec
    stream: ptr ffmpeg.AVStream
    time_base: ffmpeg.AVRational
    codec_context: ptr ffmpeg.AVCodecContext

  MockupFrame* = object
    frame*: ptr ffmpeg.AVFrame
    ## OpenGLと対話する
  FFmpegError* = object of ValueError
    ## FFmpegとの連携で引き起こした例外

proc width* (video: MockupVideo): int32 =
  result = video.codec_context.width.int32

proc height* (video: MockupVideo): int32 =
  result = video.codec_context.height.int32

proc setFormatContext (video: var MockupVideo) =
  if ffmpeg.avformat_open_input(video.format_context.addr, video.path, nil, nil) != 0:
    raise newException(FFmpegError, "動画ファイルを開けませんでした")

proc setStreamInfo (video: var MockupVideo) =
  if ffmpeg.avformat_find_stream_info(video.format_context, nil) < 0:
    raise newException(FFmpegError, "ストリーム情報取得に失敗しました")

proc setDecoder (video: var MockupVideo) =
  let streams = cast[ptr UncheckedArray[ptr ffmpeg.AVStream]](video.format_context[].streams)
  for stream_index in 0 ..< video.format_context[].nb_streams:
    let locpar = streams[stream_index][].codecpar
    if locpar[].codec_type == ffmpeg.AVMEDIA_TYPE_VIDEO:
      video.codec = ffmpeg.avcodec_find_decoder(locpar[].codec_id)
      video.codec_param = locpar
      video.stream = streams[stream_index]
      break
  if video.codec == nil or video.codec_param == nil:
    raise newException(FFmpegError, "デコーダの取得に失敗しました")

proc initializeCodecContextParams (video: var MockupVideo) =
  if ffmpeg.avcodec_parameters_to_context(video.codec_context, video.codec_param) < 0:
    raise newException(FFmpegError, "コーデックパラメータの初期化に失敗しました")

proc initializeCodecContext (video: var MockupVideo) =
  if ffmpeg.avcodec_open2(video.codec_context, video.codec, nil) < 0:
    raise newException(FFmpegError, "コーデックの初期化に失敗しました")

proc prepareDecode (video: var MockupVideo) =
  video.setFormatContext
  video.setStreamInfo
  video.setDecoder
  video.time_base = video.stream.time_base
  video.codec_context = ffmpeg.avcodec_alloc_context3(video.codec)
  video.initializeCodecContextParams
  video.initializeCodecContext

proc newVideo* (path: string): MockupVideo =
  result = MockupVideo(path: path)
  result.prepareDecode # すぐ初期化していいのか？

proc is_initial_state (video: MockupVideo): bool =
  result = video.format_context == nil and
           video.codec_param == nil and
           video.codec == nil and
           video.stream == nil and
           video.codec_context == nil

proc prepareCopyFrame (src: ptr ffmpeg.AVFrame): ptr ffmpeg.AVFrame =
  result = ffmpeg.av_frame_alloc()
  result[].format = src[].format
  result[].height = src[].height
  result[].width = src[].width
  result[].channels = src[].channels
  result[].channel_layout = src[].channel_layout
  result[].nb_samples = src[].nb_samples
  result[].pts = src[].pts

proc copy (src: ptr ffmpeg.AVFrame): ptr ffmpeg.AVFrame =
  result = prepareCopyFrame(src)
  if ffmpeg.av_frame_get_buffer(result, 32) < 0:
    raise newException(FFmpegError, "バッファの割り当てに失敗しました")
  if ffmpeg.av_frame_copy(result, src) < 0:
    raise newException(FFmpegError, "フレームデータのコピーに失敗しました")
  if ffmpeg.av_frame_copy_props(result, src) < 0:
    raise newException(FFmpegError, "フレームのメタデータのコピーに失敗しました")
  # 暗黙な変数resultの場合はポインタが生存するが、変数を明示的に定義して返すとポインタは死ぬ

proc getFormatConverter (video: MockupVideo, pixel_format: ffmpeg.AVPixelFormat): ptr ffmpeg.SwsContext =
  result = ffmpeg.sws_getContext(
    video.codec_context[].width,
    video.codec_context[].height,
    video.codec_context[].pix_fmt,
    video.codec_context[].width,
    video.codec_context[].height,
    pixel_format,
    ffmpeg.SWS_BICUBIC,
    nil, nil, nil
  )

proc formatConvert (src: ptr ffmpeg.AVFrame, format_converter: ptr ffmpeg.SwsContext): ptr ffmpeg.AVFrame =
  result = prepareCopyFrame(src)
  result[].format = ffmpeg.AV_PIX_FMT_RGBA.cint
  if ffmpeg.av_frame_get_buffer(result, 32) < 0:
    raise newException(FFmpegError, "バッファの割り当てに失敗しました")
  discard ffmpeg.sws_scale(
    format_converter,
    src[].data[0].addr,
    src[].linesize[0].addr,
    0,
    src[].height,
    result[].data[0].addr,
    result[].linesize[0].addr
  )

func pickRGBPointer (frame: ptr ffmpeg.AVFrame, index: int): (ptr uint8, ptr uint8, ptr uint8) {.inline.} =
  let
    red = cast[ptr uint8](cast[int](frame[].data[0]) + index)
    green = cast[ptr uint8](cast[int](frame[].data[0]) + index + 1)
    blue = cast[ptr uint8](cast[int](frame[].data[0]) + index + 2)
  result = (red, green, blue)

proc getRGB (frame: ptr ffmpeg.AVFrame, index: int): tRGB {.inline.} =
  let (red, green, blue) = frame.pickRGBPointer(index)
  result = (red[].tBinaryRange, green[].tBinaryRange, blue[].tBinaryRange)

iterator decode* (video: MockupVideo): MockupFrame =
  ## 与えられた動画のフレームを全て返却する
  var packet = ffmpeg.AVPacket()
  var format_converter = video.getFormatConverter(ffmpeg.AV_PIX_FMT_RGBA)
  while ffmpeg.av_read_frame(video.format_context, packet.addr) == 0:
    if packet.stream_index != video.stream.index:
      ffmpeg.av_packet_unref(packet.addr)
      continue
    if ffmpeg.avcodec_send_packet(video.codec_context, packet.addr) != 0:
      raise newException(FFmpegError, "パケットの取り出しに失敗しました")
    var frame = ffmpeg.av_frame_alloc()
    while ffmpeg.avcodec_receive_frame(video.codec_context, frame) == 0:
      var
        copy_frame = frame.copy # 元ポインタを直接操作するとバグる
        frame_RGBA = copy_frame.formatConvert(format_converter) # RGBAに変換する

      yield MockupFrame(frame: frame_RGBA)
    ffmpeg.av_frame_free(frame.addr)
  ffmpeg.av_packet_unref(packet.addr)

iterator decode* (video: MockupVideo, start, stop: uint): MockupFrame = discard