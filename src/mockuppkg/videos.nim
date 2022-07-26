from ffmpeg import nil
import images

type
  MockupVideo* = object
    path: string
    io_context: ptr ffmpeg.AVIOContext
    format_context: ptr ffmpeg.AVFormatContext
    codec_param: ptr ffmpeg.AVCodecParameters
    codec: ptr ffmpeg.AVCodec
    stream: ptr ffmpeg.AVStream
    time_base: ffmpeg.AVRational
    codec_context*: ptr ffmpeg.AVCodecContext
    programID: uint32
    encoder_codec: ptr ffmpeg.AVCodec
    encoder_codec_context: ptr ffmpeg.AVCodecContext
    encoder_stream: ptr ffmpeg.AVStream
    encoder_format_context: ptr ffmpeg.AVFormatContext

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
  video.time_base = video.stream[].time_base
  video.codec_context = ffmpeg.avcodec_alloc_context3(video.codec)
  video.initializeCodecContextParams
  video.initializeCodecContext

proc setEncoder (video: var MockupVideo) =
  var codec = ffmpeg.avcodec_find_encoder(ffmpeg.AV_CODEC_ID_H264)
  if codec == nil:
    raise newException(FFmpegError, "エンコーダが見つかりませんでした")
  video.encoder_codec = codec

proc setEncoderCodecContext (video: var MockupVideo) =
  var codec_context = ffmpeg.avcodec_alloc_context3(video.encoder_codec)
  if codec_context == nil:
    raise newException(FFmpegError, "コーデックの割り当てに失敗しました")
  video.encoder_codec_context = codec_context

proc prepareMp4Encode (video: var MockupVideo, frame: ptr ffmpeg.AVFrame) =
  video.setEncoder
  video.setEncoderCodecContext
  video.encoder_codec_context.pix_fmt = ffmpeg.AVPixelFormat(frame.format.int)
  video.encoder_codec_context.width = frame.width
  video.encoder_codec_context.height = frame.height
  video.encoder_codec_context.field_order = ffmpeg.AV_FIELD_PROGRESSIVE
  video.encoder_codec_context.color_range = frame.color_range
  video.encoder_codec_context.color_primaries = frame.color_primaries
  video.encoder_codec_context.color_trc = frame.color_trc
  video.encoder_codec_context.colorspace = frame.colorspace
  video.encoder_codec_context.chroma_sample_location = frame.chroma_location
  video.encoder_codec_context.sample_aspect_ratio = frame.sample_aspect_ratio
  video.encoder_codec_context.time_base = video.time_base
  var codec_options: ptr ffmpeg.AVDictionary = nil
  discard ffmpeg.av_dict_set(codec_options.addr, "profile", "high", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "preset", "medium", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "crf", "22", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "level", "4.0", 0)

  if ffmpeg.avcodec_open2(video.encoder_codec_context, video.encoder_codec_context[].codec, codec_options.addr) < 0:
    raise newException(FFmpegError, "コーデックコンテキストの初期化に失敗しました")

proc newVideo* (path: string, programID: uint32): MockupVideo =
  result.path = path
  result.programID = programID
  result.prepareDecode
  if ffmpeg.avio_open(
    result.io_context.addr, "./assets/out/encode.mp4", ffmpeg.AVIO_FLAG_WRITE
  ) < 0:
    raise newException(FFmpegError, "IOコンテキストの初期化に失敗しました")
  if ffmpeg.avformat_alloc_output_context2(
    result.encoder_format_context.addr, nil, "mp4", nil
  ) < 0:
    raise newException(FFmpegError, "出力フォーマットへのコンテキスト割り当てに失敗しました")
  result.encoder_format_context.pb = result.io_context

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

proc getEncoderSwscontext* (codecContext: ptr ffmpeg.AVCodecContext, pixelFormat: ffmpeg.AVPixelFormat): ptr ffmpeg.SwsContext =
  result = ffmpeg.sws_getContext(
    codecContext[].width,
    codecContext[].height,
    pixelFormat,
    codecContext[].width,
    codecContext[].height,
    codecContext[].pix_fmt,
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

iterator items* (video: var MockupVideo): MockupImage =
  ## 与えられた動画のフレームを全て返却する
  var packet = ffmpeg.AVPacket()
  var once = true
  var image: MockupImage
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

      if once:
        image = newImage(frame_RGBA, video.programID)

        var ref_frame = ffmpeg.av_frame_alloc()
        discard ffmpeg.av_frame_ref(ref_frame, frame)
        
        video.prepareMp4Encode(ref_frame)
        video.encoder_stream = ffmpeg.avformat_new_stream(
          video.encoder_format_context, video.encoder_codec
        )
        if video.encoder_stream == nil:
          raise newException(FFmpegError, "ストリームの取得に失敗しました")
        video.encoder_stream.sample_aspect_ratio = video.encoder_codec_context.sample_aspect_ratio
        video.encoder_stream.time_base = video.encoder_codec_context.time_base

        if ffmpeg.avcodec_parameters_from_context(
          video.encoder_stream.codecpar, video.encoder_codec_context
        ) < 0:
          raise newException(FFmpegError, "コーデックコンテキストによる塗りつぶしに失敗しました")
        
        if ffmpeg.avformat_write_header(video.encoder_format_context, nil) < 0:
          raise newException(FFmpegError, "ヘッダーの書き込みに失敗しました")

        once = false

      image.updateImage(frame_RGBA)
      yield image
    ffmpeg.av_frame_free(frame.addr)
  ffmpeg.av_packet_unref(packet.addr)
