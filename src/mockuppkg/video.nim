import ffmpeg, options, deques

type
  mVideo* = object
    path: string
    format_context: ptr AVFormatContext
    codec_param: ptr AVCodecParameters
    codec_context: ptr AVCodecContext
    video_codec: ptr AVCodec
    video_context: ptr AVCodecContext
    stream: ptr AVStream
    frames: Deque[ptr AVFrame]
    time_base: AVRational

proc width* (video: mVideo): uint =
  result = video.codec_context.width.uint

proc height* (video: mVideo): uint =
  result = video.codec_context.height.uint

template checkCorrectMVideo (condition: bool, msg: string): untyped =
  if condition:
    stderr.writeLine("[Runtime]: " & msg)
    return none(mVideo)

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

  result = not(stream_id == -1 or codec_param == nil or video_codec == nil)

proc initializeAVCodecContext (video: var mVideo): bool =
  result = avcodec_open2(video.video_context, video.video_codec, nil) < 0

proc openAVCodecParameters (video: var mVideo): bool =
  result = avcodec_parameters_to_context(video.video_context, video.codec_param) < 0

proc encode* (output_path: string, video: mVideo): bool =
  result = true

proc decode* (video: var mVideo): Option[mVideo] =
  var
    frames = initDeque[ptr AVFrame]()
    packet = AVPacket()
    frame = av_frame_alloc()
  
  checkCorrectMVideo(video.getFormatContext, "動画ファイルを開けませんでした")
  checkCorrectMVideo(video.getStreamInfo, "動画ファイルのストリーム情報取得に失敗しました")
  checkCorrectMVideo(video.getDecoder, "デコーダの取得に失敗しました")

  # デコード
  video.time_base = video.stream.time_base
  video.video_context = avcodec_alloc_context3(video.video_codec)
  checkCorrectMVideo(video.openAVCodecParameters, "コーデックパラメータを開けませんでした")
  checkCorrectMVideo(video.initializeAVCodecContext, "コーデックの初期化に失敗しました")

  while av_read_frame(video.format_context, addr packet) == 0:
    if packet.stream_index == video.stream.index:
      if avcodec_send_packet(video.video_context, addr packet) != 0:
        return none(mVideo)
      while avcodec_receive_frame(video.video_context, frame) == 0:
        var new_ref = av_frame_alloc()
        discard av_frame_ref(new_ref, frame)
        frames.addLast(new_ref)
    av_packet_unref(addr packet)

  video.frames = frames
  result = some(video)

proc Video* (path: string): mVideo =
  result = mVideo(
    path: path,
    format_context: avformat_alloc_context(),
    codec_param: nil,
    codec_context: nil,
    video_codec: nil,
    video_context: nil,
    stream: nil,
    frames: initDeque[ptr AVFrame](),
    time_base: AVRational()
  )
