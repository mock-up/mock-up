import ffmpeg, options

type
  mVideo* = object
    codec_context: ptr AVCodecContext

proc width* (video: mVideo): uint =
  result = video.codec_context.width.uint

proc height* (video: mVideo): uint =
  result = video.codec_context.height.uint

proc on_frame_decoded (frame: ptr AVFrame) =
  echo frame.pts

proc Video* (path: string): Option[mVideo] =
  var format_context = avformat_alloc_context()
  
  # 動画ファイルを開いて format_context に格納
  if avformat_open_input(addr format_context, path, nil, nil) != 0:
    echo "[Runtime]: avformat_open_input failed"
    return none(mVideo)
  
  # 動画ファイルのストリーム情報取得
  if avformat_find_stream_info(format_context, nil) < 0:
    echo "[Runtime]: avformat_find_stream_info failed"
    return none(mVideo)

  var
    streams = cast[ptr UncheckedArray[ptr AVStream]](format_context[].streams)
    stream_id = -1
    codec_param: ptr AVCodecParameters = nil
    video_codec: ptr AVCodec = nil
  
  for frame in 0 ..< format_context[].nb_streams:
    var
      locpar = streams[frame][].codecpar
      locdec = avcodec_find_decoder(locpar[].codec_id)
    if locpar[].codec_type == AVMEDIA_TYPE_VIDEO:
      video_codec = locdec
      codec_param = locpar
      stream_id = frame.int
      break
  
  # デコード
  var
    video_context = avcodec_alloc_context3(video_codec)
    frame = av_frame_alloc()
    packet = AVPacket()
  
  if avcodec_parameters_to_context(video_context, codec_param) < 0:
    echo "[Runtime]: avcodec_parameters_to_context failed"
    return none(mVideo)

  if avcodec_open2(video_context, video_codec, nil) < 0:
    echo "[Runtime]: avcodec_open2 failed"
    return none(mVideo)
  
  while av_read_frame(format_context, addr packet) == 0:
    if packet.stream_index == streams[stream_id].index:
      if avcodec_send_packet(video_context, addr packet) != 0:
        return none(mVideo)
      while avcodec_receive_frame(video_context, frame) == 0:
        on_frame_decoded(frame)
    av_packet_unref(addr packet)
  
  result = some(mVideo(codec_context: video_context))
