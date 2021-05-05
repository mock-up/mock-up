import ffmpeg, options, deques

type
  mVideo* = object
    path: string
    output_path: string
    format_context: ptr AVFormatContext
    codec_param: ptr AVCodecParameters
    codec_context: ptr AVCodecContext
    video_codec: ptr AVCodec
    video_context: ptr AVCodecContext
    stream: ptr AVStream
    frames: Deque[ptr AVFrame]
    time_base: AVRational
    io_context: ptr AVIOContext
    encode_format_context: ptr AVFormatContext
    codec: ptr AVCodec

proc width* (video: mVideo): uint =
  result = video.codec_context.width.uint

proc height* (video: mVideo): uint =
  result = video.codec_context.height.uint

template checkCorrectMVideo (condition: bool, msg: string): untyped =
  if condition:
    stderr.writeLine("[Runtime]: " & msg)
    return false

proc getFormatContext (video: var mVideo): bool =
  result = avformat_open_input(addr video.format_context, video.path, nil, nil) != 0

proc getStreamInfo (video: var mVideo): bool =
  result = avformat_find_stream_info(video.format_context, nil) < 0

proc getDecoder (video: var mVideo): bool =
  var
    streams = cast[ptr UncheckedArray[ptr AVStream]](video.format_context[].streams)
    stream_id = -1
    codec_param: ptr AVCodecParameters = nil
    video_codec: ptr AVCodec = nil
  
  for stream in 0 ..< video.format_context[].nb_streams:
    var
      locpar = streams[stream][].codecpar
      locdec = avcodec_find_decoder(locpar[].codec_id)
    if locpar[].codec_type == AVMEDIA_TYPE_VIDEO:
      video_codec = locdec
      codec_param = locpar
      stream_id = stream.int
      break
  
  video.codec_param = codec_param
  video.video_codec = video_codec
  video.stream = streams[stream_id]

  result = stream_id == -1 or codec_param == nil or video_codec == nil

proc initializeAVCodecContext (video: var mVideo): bool =
  result = avcodec_open2(video.video_context, video.video_codec, nil) < 0

proc openAVCodecParameters (video: var mVideo): bool =
  result = avcodec_parameters_to_context(video.video_context, video.codec_param) < 0

proc getIOContext (video: var mVideo): bool =
  result = avio_open(video.io_context.addr, video.output_path, AVIO_FLAG_WRITE) < 0

proc allocMuxerMp4 (video: var mVideo): bool =
  result = avformat_alloc_output_context2(
    video.encode_format_context.addr, nil, "mp4", nil
  ) < 0

proc getEncoderMp4 (video: var mVideo): bool =
  var codec = avcodec_find_encoder(AV_CODEC_ID_H264)
  if codec == nil:
    return false
  var codec_context = avcodec_alloc_context3(codec)
  if codec_context == nil:
    return false

  video.codec = codec
  video.codec_context = codec_context

  var first_frame = video.frames[0]
  video.codec_context.pix_fmt = AVPixelFormat(first_frame.format.int)
  video.codec_context.width = first_frame.width
  video.codec_context.height = first_frame.height
  video.codec_context.field_order = AV_FIELD_PROGRESSIVE
  video.codec_context.color_range = first_frame.color_range
  video.codec_context.color_primaries = first_frame.color_primaries
  video.codec_context.color_trc = first_frame.color_trc
  video.codec_context.colorspace = first_frame.colorspace
  video.codec_context.chroma_sample_location = first_frame.chroma_location
  video.codec_context.sample_aspect_ratio = first_frame.sample_aspect_ratio
  echo video.time_base
  video.codec_context.time_base = video.time_base

  # 怪しい bit演算だったかも
  #if video.encode_format_context.oformat.flags != 0 and AVFMT_GLOBALHEADER != 0:
  #  video.codec_context.flags = video.codec_context.flags or AV_CODEC_FLAG_GLOBAL_HEADER
  
  var codec_options: ptr AVDictionary = nil
  discard av_dict_set(codec_options.addr, "preset", "medium", 0)
  discard av_dict_set(codec_options.addr, "crf", "22", 0)
  discard av_dict_set(codec_options.addr, "profile", "high", 0)
  discard av_dict_set(codec_options.addr, "level", "4.0", 0)

  if avcodec_open2(video.codec_context, video.codec_context.codec, codec_options.addr) != 0:
    return false

  result = true

proc encode_mp4* (video: var mVideo, path: string): bool =
  video.output_path = path
  checkCorrectMVideo(video.getIOContext, "動画ファイルを開けませんでした")
  checkCorrectMVideo(video.allocMuxerMp4, "muxerをallocできませんでした")
  video.encode_format_context.pb = video.io_context

  if not getEncoderMp4(video):
    return false
  
  var stream = avformat_new_stream(video.encode_format_context, video.codec)

  if stream == nil:
    return false
  
  stream.sample_aspect_ratio = video.codec_context.sample_aspect_ratio
  stream.time_base = video.codec_context.time_base

  if avcodec_parameters_from_context(stream.codecpar, video.codec_context) < 0:
    return false

  if avformat_write_header(video.encode_format_context, nil) < 0:
    return false

  while video.frames.len > 0:
    var frame = video.frames.peekFirst
    video.frames.popFirst
    frame.pts = av_rescale_q(frame.pts, video.time_base, video.codec_context.time_base)
    frame.key_frame = 0
    frame.pict_type = AV_PICTURE_TYPE_NONE
    if avcodec_send_frame(video.codec_context, frame) != 0:
      return false
    av_frame_free(frame.addr)
    var packet = AVPacket()
    while avcodec_receive_packet(video.codec_context, packet.addr) == 0:
      packet.stream_index = 0
      av_packet_rescale_ts(packet.addr, video.codec_context.time_base, stream.time_base)
      if av_interleaved_write_frame(video.encode_format_context, packet.addr) != 0:
        return false
  
  if avcodec_send_frame(video.codec_context, nil) != 0:
    return false

  var packet = AVPacket()
  while avcodec_receive_packet(video.codec_context, packet.addr) == 0:
    packet.stream_index = 0
    av_packet_rescale_ts(packet.addr, video.codec_context.time_base, stream.time_base)
    if av_interleaved_write_frame(video.encode_format_context, packet.addr) != 0:
      return false
  
  if av_write_trailer(video.encode_format_context) != 0:
    return false

  avcodec_free_context(video.codec_context.addr)
  avformat_free_context(video.encode_format_context)
  discard avio_closep(video.io_context.addr)

  result = true

proc time_base* (video: var mVideo): AVRational =
  result = video.time_base

proc decode* (video: var mVideo): bool =
  var
    frames = initDeque[ptr AVFrame]()
    packet = AVPacket()
    frame = av_frame_alloc()
  
  checkCorrectMVideo(video.getFormatContext, "動画ファイルを開けませんでした")
  checkCorrectMVideo(video.getStreamInfo, "動画ファイルのストリーム情報取得に失敗しました")
  checkCorrectMVideo(video.getDecoder, "デコーダの取得に失敗しました")

  # デコード
  video.time_base = video.stream.time_base
  echo video.time_base
  video.video_context = avcodec_alloc_context3(video.video_codec)
  checkCorrectMVideo(video.openAVCodecParameters, "コーデックパラメータを開けませんでした")
  checkCorrectMVideo(video.initializeAVCodecContext, "コーデックの初期化に失敗しました")

  while av_read_frame(video.format_context, addr packet) == 0:
    if packet.stream_index == video.stream.index:
      if avcodec_send_packet(video.video_context, addr packet) != 0:
        return false
      while avcodec_receive_frame(video.video_context, frame) == 0:
        var new_ref = av_frame_alloc()
        discard av_frame_ref(new_ref, frame)
        frames.addLast(new_ref)
    av_packet_unref(addr packet)

  video.frames = frames
  result = true

proc Video* (path: string): mVideo =
  result = mVideo(
    path: path,
    output_path: "",
    format_context: avformat_alloc_context(),
    codec_param: nil,
    codec_context: nil,
    video_codec: nil,
    video_context: nil,
    stream: nil,
    frames: initDeque[ptr AVFrame](),
    time_base: AVRational(),
    io_context: nil,
    encode_format_context: nil,
    codec: nil
  )
