import frames
import ffmpeg

type
  VideoDecoder* = object

iterator decodeVideo* (src_path: string): MockupFrame =
  var format_context: ptr AVFormatContext
  if avformat_open_input(format_context.addr, src_path, nil, nil) != 0:
    raise newException(Defect, "動画ファイルを開けませんでした")

  if avformat_find_stream_info(format_context, nil) < 0:
    raise newException(Defect, "ストリーム情報取得に失敗しました")
  
  var
    codec: ptr AVCodec
    codec_param: ptr AVCodecParameters
    stream: ptr AVStream
  let streams = cast[ptr UncheckedArray[ptr AVStream]](format_context[].streams)
  for stream_index in 0 ..< format_context[].nb_streams:
    let locpar = streams[stream_index][].codecpar
    if locpar[].codec_type == AVMEDIA_TYPE_VIDEO:
      codec = avcodec_find_decoder(locpar[].codec_id)
      codec_param = locpar
      stream = streams[stream_index]
      break
  if codec.isNil or codec_param.isNil:
    raise newException(Defect, "デコーダの取得に失敗しました")

  var
    time_base = stream[].time_base
    codec_context = avcodec_alloc_context3(codec)
  
  if avcodec_parameters_to_context(codec_context, codec_param) < 0:
    raise newException(Defect, "コーデックパラメータの初期化に失敗しました")

  if avcodec_open2(codec_context, codec, nil) < 0:
    raise newException(Defect, "コーデックの初期化に失敗しました")

  var packet = AVPacket()
  var format_converter = sws_getContext(
    codec_context[].width,
    codec_context[].height,
    codec_context[].pix_fmt,
    codec_context[].width,
    codec_context[].height,
    AV_PIX_FMT_RGBA,
    SWS_BICUBIC,
    nil, nil, nil
  )

  # while av_read_frame(format_context, packet.addr) == 0:
  #   if packet.stream_index != stream.index:
  #     av_packet_unref(packet.addr)
  #     continue
  #   if avcodec_send_packet(codec_context, packet.addr) != 0:
  #     raise newException(Defect, "パケットの取り出しに失敗しました")
  #   var frame = av_frame_alloc()
  #   while avcodec_receive_frame(codec_context, frame) == 0:
  #     var
  #       copy_frame = frame.copy # 元ポインタを直接操作するとバグる
  #       frame_RGBA = copy_frame.formatConvert(format_converter) # RGBAに変換する
  #   av_frame_free(frame.addr)
  # av_packet_unref(packet.addr)