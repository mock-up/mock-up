import ffmpeg

proc encode (codec_context: ptr AVCodecContext, frame: ptr AVFrame, stream: ptr AVStream, format_context: ptr AVFormatContext) =
  var packet = ffmpeg.AVPacket()
  if avcodec_send_frame(codec_context, frame) < 0:
    raise newException(Defect, "エンコーダーへのフレームの供給に失敗しました")
  while avcodec_receive_packet(codec_context, packet.addr) == 0:
    packet.stream_index = 0
    av_packet_rescale_ts(packet.addr, codec_context.time_base, stream.time_base)
    if av_interleaved_write_frame(format_context, packet.addr) != 0:
      raise newException(Defect, "パケットの書き込みに失敗しました")
  av_packet_unref(packet.addr)

proc encodeMp4* (dist_path: string) =
  # H264コーデックの取得
  var codec = avcodec_find_encoder(AV_CODEC_ID_H264)
  if codec.isNil:
    raise newException(Defect, "エンコーダが見つかりませんでした")

  # コーデックコンテキストの取得
  var codec_context = avcodec_alloc_context3(codec)
  if codec_context.isNil:
    raise newException(Defect, "コーデックの割り当てに失敗しました")

  codec_context.pix_fmt = AV_PIX_FMT_YUV420P
  codec_context.width = 1280
  codec_context.height = 720
  # codec_context.field_order = AV_FIELD_PROGRESSIVE # これ何
  codec_context.time_base = av_make_q(1, 25)
  codec_context.framerate = av_make_q(25, 1)
  codec_context.gop_size = 10
  codec_context.max_b_frames = 1
  codec_context.bit_rate = 400000

  var codec_options: ptr ffmpeg.AVDictionary = nil
  discard ffmpeg.av_dict_set(codec_options.addr, "profile", "high", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "preset", "medium", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "crf", "22", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "level", "4.0", 0)

  var io_context: ptr AVIOContext
  if avio_open(io_context.addr, dist_path, AVIO_FLAG_WRITE) < 0:
    raise newException(Defect, "IOコンテキストの初期化に失敗しました")

  var format_context: ptr AVFormatContext
  if avformat_alloc_output_context2(format_context.addr, nil, "mp4", nil) < 0:
    raise newException(Defect, "出力フォーマットへのコンテキスト割り当てに失敗しました")
  format_context.pb = io_context

  if ffmpeg.avcodec_open2(codec_context, codec_context[].codec, codec_options.addr) < 0:
    raise newException(Defect, "コーデックコンテキストの初期化に失敗しました")

  var stream = avformat_new_stream(format_context, codec)
  if stream.isNil:
    raise newException(Defect, "ストリームの取得に失敗しました")
  # video.encoder_stream.sample_aspect_ratio = video.encoder_codec_context.sample_aspect_ratio
  # video.encoder_stream.time_base = video.encoder_codec_context.time_base

  if avcodec_parameters_from_context(stream.codecpar, codec_context) < 0:
    raise newException(Defect, "コーデックコンテキストによる塗りつぶしに失敗しました")

  if avformat_write_header(format_context, nil) < 0:
    raise newException(Defect, "ヘッダーの書き込みに失敗しました")

  var frame = av_frame_alloc()
  if frame.isNil:
    raise newException(Defect, "Could not allocate video frame")

  frame.format = codec_context.pix_fmt.int32
  frame.width  = codec_context.width
  frame.height = codec_context.height

  if av_frame_get_buffer(frame, 0) < 0:
    raise newException(Defect, "Could not allocate the video frame data")
  
  for i in 0 ..< 250:
    if av_frame_make_writable(frame) < 0:
      quit(1)

    for y in 0 ..< codec_context.height:
      for x in 0 ..< codec_context.width:
        cast[ptr uint8](cast[int](frame[].data[0]) + y * frame[].linesize[0] + x)[] = (x + y + i).uint8
    
    for y in 0 ..< codec_context.height div 2:
      for x in 0 ..< codec_context.width div 2:
        cast[ptr uint8](cast[int](frame[].data[1]) + y * frame[].linesize[1] + x)[] = (128 + y + i * 4).uint8
        cast[ptr uint8](cast[int](frame[].data[2]) + y * frame[].linesize[2] + x)[] = (64 + x + i * 3).uint8

    frame[].pts = i
    encode(codec_context, frame, stream, format_context)

  if avcodec_send_frame(codec_context, nil) != 0:
    return
  var packet = AVPacket()
  while avcodec_receive_packet(codec_context, packet.addr) == 0:
    packet.stream_index = 0
    av_packet_rescale_ts(packet.addr, codec_context.time_base, stream.time_base)
    if av_interleaved_write_frame(format_context, packet.addr) != 0:
      return
  if av_write_trailer(format_context) != 0:
    return
  avcodec_free_context(codec_context.addr)
  avformat_free_context(format_context)
  discard avio_closep(io_context.addr)
