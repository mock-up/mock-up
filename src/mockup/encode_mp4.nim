import ffmpeg

type
  MP4Encoder* = object
    frame_num: int # フレーム数
    codec_context: ptr AVCodecContext
    stream: ptr AVStream
    format_context: ptr AVFormatContext
    io_context: ptr AVIOContext

proc openMP4* (dist_path: string, width, height, fps: int32): MP4Encoder =
  result.frame_num = 0

  # H264コーデックの取得
  var codec = avcodec_find_encoder(AV_CODEC_ID_H264)
  if codec.isNil:
    raise newException(Defect, "エンコーダが見つかりませんでした")

  # コーデックコンテキストの取得
  result.codec_context = avcodec_alloc_context3(codec)
  if result.codec_context.isNil:
    raise newException(Defect, "コーデックの割り当てに失敗しました")

  result.codec_context.pix_fmt = AV_PIX_FMT_YUV420P
  result.codec_context.width = width
  result.codec_context.height = height
  # codec_context.field_order = AV_FIELD_PROGRESSIVE # これ何
  result.codec_context.time_base = av_make_q(1, fps)
  result.codec_context.framerate = av_make_q(fps, 1)
  result.codec_context.gop_size = 10
  result.codec_context.max_b_frames = 1
  result.codec_context.bit_rate = 400000

  var codec_options: ptr ffmpeg.AVDictionary = nil
  discard ffmpeg.av_dict_set(codec_options.addr, "profile", "high", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "preset", "medium", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "crf", "22", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "level", "4.0", 0)

  if avio_open(result.io_context.addr, dist_path, AVIO_FLAG_WRITE) < 0:
    raise newException(Defect, "IOコンテキストの初期化に失敗しました")

  if avformat_alloc_output_context2(result.format_context.addr, nil, "mp4", nil) < 0:
    raise newException(Defect, "出力フォーマットへのコンテキスト割り当てに失敗しました")
  result.format_context.pb = result.io_context

  if ffmpeg.avcodec_open2(result.codec_context, result.codec_context[].codec, codec_options.addr) < 0:
    raise newException(Defect, "コーデックコンテキストの初期化に失敗しました")

  result.stream = avformat_new_stream(result.format_context, codec)
  if result.stream.isNil:
    raise newException(Defect, "ストリームの取得に失敗しました")
  # video.encoder_stream.sample_aspect_ratio = video.encoder_codec_context.sample_aspect_ratio
  # video.encoder_stream.time_base = video.encoder_codec_context.time_base

  if avcodec_parameters_from_context(result.stream.codecpar, result.codec_context) < 0:
    raise newException(Defect, "コーデックコンテキストによる塗りつぶしに失敗しました")

  if avformat_write_header(result.format_context, nil) < 0:
    raise newException(Defect, "ヘッダーの書き込みに失敗しました")

proc prepareCopyFrame (src: ptr AVFrame): ptr AVFrame =
  result = av_frame_alloc()
  result[].format = src[].format
  result[].height = src[].height
  result[].width = src[].width
  result[].channels = src[].channels # ?
  result[].channel_layout = src[].channel_layout
  result[].nb_samples = src[].nb_samples
  # result[].pts = src[].pts

proc addFrame* (encoder: var MP4Encoder, src_frame: ptr AVFrame) =
  var frame = src_frame
  var dest_frame = frame.prepareCopyFrame
  dest_frame.format = encoder.codec_context.pix_fmt.cint
  if av_frame_get_buffer(dest_frame, 32) < 0:
    raise newException(Defect, "バッファの割り当てに失敗しました")
  var swsCtxEnc = sws_getContext(
    encoder.codec_context.width,
    encoder.codec_context.height,
    AV_PIX_FMT_RGBA,
    encoder.codec_context.width,
    encoder.codec_context.height,
    encoder.codec_context.pix_fmt,
    ffmpeg.SWS_BICUBIC,
    nil, nil, nil
  )
  discard ffmpeg.sws_scale(
    swsCtxEnc,
    frame[].data[0].addr,
    frame[].linesize[0].addr,
    0,
    frame[].height,
    dest_frame[].data[0].addr,
    dest_frame[].linesize[0].addr
  )
  var packet = ffmpeg.AVPacket()
  dest_frame.pts = encoder.frame_num
  encoder.frame_num += 1
  if (var ret = avcodec_send_frame(encoder.codec_context, dest_frame); echo ret; ret) < 0:
    raise newException(Defect, "エンコーダーへのフレームの供給に失敗しました")
  while avcodec_receive_packet(encoder.codec_context, packet.addr) == 0:
    packet.stream_index = 0
    av_packet_rescale_ts(packet.addr, encoder.codec_context.time_base, encoder.stream.time_base)
    if av_interleaved_write_frame(encoder.format_context, packet.addr) != 0:
      raise newException(Defect, "パケットの書き込みに失敗しました")
  av_packet_unref(packet.addr)

proc close* (encoder: var MP4Encoder) =
  if avcodec_send_frame(encoder.codec_context, nil) != 0:
    return
  var packet = AVPacket()
  while avcodec_receive_packet(encoder.codec_context, packet.addr) == 0:
    packet.stream_index = 0
    av_packet_rescale_ts(packet.addr, encoder.codec_context.time_base, encoder.stream.time_base)
    if av_interleaved_write_frame(encoder.format_context, packet.addr) != 0:
      return
  if av_write_trailer(encoder.format_context) != 0:
    return
  avcodec_free_context(encoder.codec_context.addr)
  avformat_free_context(encoder.format_context)
  discard avio_closep(encoder.io_context.addr)
