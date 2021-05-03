import ffmpeg, options

type
  mClipType* = enum
    mVideo
    mImage
    mAudio
  
  mClip* = object
    start_frame*: uint64
    frame_width*: uint64
    case clip_type*: mClipType
    of mVideo:
      codec_context: ptr AVCodecContext
    of mImage:
      frame: ptr AVFrame
    else: discard

proc Image* (width, height: uint, format: AVPixelFormat): Option[mClip] =
  var frame = av_frame_alloc()

  if frame == nil:
    stderr.writeLine "フレームを確保できませんでした"
    return none(mClip)
  
  var
    buffer_for_save = av_image_get_buffer_size(format, width.cint, height.cint, 1.cint)
    buffer = av_malloc((buffer_for_save * sizeof(uint8)).csize_t)
    dst_data: array[4, ptr uint8]
    dst_linesize: array[4, cint]

  if buffer == nil:
    return none(mClip)
  
  var success_fill_arrays = av_image_fill_arrays(
    dst_data,
    dst_linesize,
    cast[ptr uint8](buffer),
    format,
    width.cint,
    height.cint,
    1.cint
  ).int

  if success_fill_arrays < 0:
    return none(mClip)
  
  # 応急処置
  frame.data[0..3] = dst_data
  frame.linesize[0..3] = dst_linesize

  result = some(mClip(
    start_frame: 0,
    frame_width: 0,
    clip_type: mImage,
    frame: frame
  ))

proc copy (clip: mClip): Option[mClip] =
  case clip.clip_type
  of mImage:
    var new_frame = av_frame_alloc()
    discard av_frame_copy_props(new_frame, clip.frame)
    new_frame.format = clip.frame.format
    new_frame.width = clip.frame.width
    new_frame.height = clip.frame.height
    if av_frame_get_buffer(new_frame, 32) != 0:
      return none(mClip)
    result = some(mClip(start_frame: 0, frame_width: 0, clip_type: mImage, frame: new_frame))
  else: discard

proc width* (clip: mClip): uint =
  case clip.clip_type
  of mVideo:
    result = clip.codec_context.width.uint
  else: discard

proc height* (clip: mClip): uint =
  case clip.clip_type
  of mVideo:
    result = clip.codec_context.height.uint
  else: discard

proc on_frame_decoded (frame: ptr AVFrame) =
  echo frame.pts

proc Video* (path: string): Option[mClip] =
  var format_context = avformat_alloc_context()
  
  # 動画ファイルを開いて format_context に格納
  if avformat_open_input(addr format_context, path, nil, nil) != 0:
    echo "[Runtime]: avformat_open_input failed"
    return none(mClip)
  
  # 動画ファイルのストリーム情報取得
  if avformat_find_stream_info(format_context, nil) < 0:
    echo "[Runtime]: avformat_find_stream_info failed"
    return none(mClip)

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
    return none(mClip)

  if avcodec_open2(video_context, video_codec, nil) < 0:
    echo "[Runtime]: avcodec_open2 failed"
    return none(mClip)
  
  while av_read_frame(format_context, addr packet) == 0:
    if packet.stream_index == streams[stream_id].index:
      if avcodec_send_packet(video_context, addr packet) != 0:
        return none(mClip)
      while avcodec_receive_frame(video_context, frame) == 0:
        on_frame_decoded(frame)
    av_packet_unref(addr packet)
  
  result = some(
    mClip(
      start_frame: 0,
      frame_width: 0,
      clip_type: mVideo,
      codec_context: video_context
    )
  )
