import ffmpeg, options, deques, sequtils, palette/color, muml, timeline, tables, fonts, math
from fp import isLeft

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
    frames: Deque[ptr AVFrame] # 保持しない
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

proc decode_init (video: var mVideo): bool =  
  checkCorrectMVideo(video.getFormatContext, "動画ファイルを開けませんでした")
  checkCorrectMVideo(video.getStreamInfo, "動画ファイルのストリーム情報取得に失敗しました")
  checkCorrectMVideo(video.getDecoder, "デコーダの取得に失敗しました")

  video.time_base = video.stream.time_base
  video.video_context = avcodec_alloc_context3(video.video_codec)
  checkCorrectMVideo(video.openAVCodecParameters, "コーデックパラメータを開けませんでした")
  checkCorrectMVideo(video.initializeAVCodecContext, "コーデックの初期化に失敗しました")
  result = true

proc copy (src: ptr AVFrame): ptr AVFrame =
  result = av_frame_alloc()
  result[].format = src[].format
  result[].height = src[].height
  result[].width = src[].width
  result[].channels = src[].channels
  result[].channel_layout = src[].channel_layout
  result[].nb_samples = src[].nb_samples
  result[].pts = src[].pts
  # 暗黙な変数resultの場合はポインタが生存するが、変数を明示的に定義して返すとポインタは死ぬ

# proc `[]` (frame: ptr AVFrame): mPixel

func pickRGBPointer (frame: ptr AVFrame, index: int): (ptr uint8, ptr uint8, ptr uint8) {.inline.} =
  let
    red = cast[ptr uint8](cast[int](frame[].data[0]) + index)
    green = cast[ptr uint8](cast[int](frame[].data[0]) + index + 1)
    blue = cast[ptr uint8](cast[int](frame[].data[0]) + index + 2)
  result = (red, green, blue)

proc getRGB (frame: ptr AVFrame, index: int): tRGB {.inline.} =
  let (red, green, blue) = frame.pickRGBPointer(index)
  result = (red[].tBinaryRange, green[].tBinaryRange, blue[].tBinaryRange)

proc setRGB (frame: ptr AVFrame, index: int, color: tRGB) {.inline.} =
  let (red, green, blue) = frame.pickRGBPointer(index)
  red[] = color.red.uint8
  green[] = color.green.uint8
  blue[] = color.blue.uint8

iterator pixel (frame: ptr AVFrame): tuple[x: int32, y: int32, index: int32] =
  let
    height = frame[].height
    width = frame[].width
    linesize = frame[].linesize[0]
  for y in 0..<height:
    for x in 0..<width:
      yield (x, y, y * linesize + x * 3)

iterator rect (frame: ptr AVFrame, x_range: (int, int), y_range: (int, int)): tuple[x: int32, y: int32, index: int32] =
  let
    linesize = frame[].linesize[0]
  for y in y_range[0]..<y_range[1]:
    for x in x_range[0]..<x_range[1]:
      yield (x.int32, y.int32, (y * linesize + x * 3).int32)

proc rect (frame: ptr AVFrame, x_range: (int, int), y_range: (int, int), color: tRGB) =
  for (x, y, index) in frame.rect((x_range[0], x_range[1]), (y_range[0], y_range[1])):
    frame.setRGB(index, color)

proc initFrame (height, width: int): ptr AVFrame =
  result = av_frame_alloc()
  result[].format = AV_PIX_FMT_RGB24.cint
  result[].height = height.cint
  result[].width = width.cint

# proc fill (frame: ptr AVFrame, color: tRGB) =
#   echo frame[].data[0].len

proc encode* (timeline: mTimeLine, output_path: string): bool =
  result = true
  let
    header = timeline.header
    width = header.width
    height = header.height
  var max_layer_number = 0
  for layer_number in timeline.content.keys:
    max_layer_number = max(max_layer_number, layer_number)
  
  var clip_index_table: seq[int] = @[]
  for i in 0..<max_layer_number:
    clip_index_table[i] = 0
  
  var
    io_context: ptr AVIOContext = nil
    format_context: ptr AVFormatContext = nil
    codec = avcodec_find_encoder(AV_CODEC_ID_H264)

  if avio_open(io_context.addr, output_path, AVIO_FLAG_WRITE) < 0:
    return false

  if avformat_alloc_output_context2(format_context.addr, nil, "mp4", nil) < 0:
    return false

  format_context[].pb = io_context

  if codec == nil:
    return false

  var codec_context = avcodec_alloc_context3(codec)
  if codec_context == nil:
    return false

  codec_context[].pix_fmt = AV_PIX_FMT_YUV420P
  codec_context[].width = width.int32
  codec_context[].height = height.int32
  codec_context[].field_order = AV_FIELD_PROGRESSIVE
  codec_context[].color_range = AVCOL_RANGE_MPEG
  codec_context[].color_primaries = AVCOL_PRI_BT709
  codec_context[].color_trc = AVCOL_TRC_BT709
  codec_context[].colorspace = AVCOL_SPC_BT709
  codec_context[].chroma_sample_location = AVCHROMA_LOC_LEFT
  codec_context[].sample_aspect_ratio = AVRational(num: 1, den: 1)
  let time_base = AVRational(num: 1, den: 30000)
  codec_context[].time_base = time_base

  var codec_options: ptr AVDictionary = nil
  discard av_dict_set(codec_options.addr, "preset", "medium", 0)
  discard av_dict_set(codec_options.addr, "crf", "22", 0)
  discard av_dict_set(codec_options.addr, "profile", "high", 0)
  discard av_dict_set(codec_options.addr, "level", "4.0", 0)

  if avcodec_open2(codec_context, codec_context[].codec, codec_options.addr) < 0:
    return false

  var stream = avformat_new_stream(format_context, codec)
  if stream == nil:
    return false

  stream[].sample_aspect_ratio = codec_context[].sample_aspect_ratio
  stream[].time_base = codec_context[].time_base
  echo "test"
  if avcodec_parameters_from_context(stream[].codecpar, codec_context) < 0:
    return false

  if avformat_write_header(format_context, nil) < 0:
    echo "write_header"
    return false
  
  for frame_number in 0..header.last_frame_number:
    var frame = initFrame(height, width)
    #frame[].linesize = [width.int32, width.int32, width.int32, width.int32,width.int32,width.int32,width.int32,width.int32]
    if av_frame_get_buffer(frame, 32) < 0:
      echo "frame_get_buffer"
      return false

    for layer_number in countdown(max_layer_number-1, 0):
      let clips = timeline.content[layer_number].clips
      var clip = clips[clip_index_table[layer_number]]

      if clip.frame.start <= frame_number and frame_number < clip.frame.`end`:
        echo "start object parse"
        case clip.kind:
        of mumlKindRectangle:
          let
            position = clip.rectangle.position[0]
            width = clip.rectangle.width[0]
            height = clip.rectangle.height[0]
          frame.rect((position.x.start.int, position.x.start.int + width.value.start.int), (position.y.start.int, position.y.start.int + position.y.start.int + height.value.start.int), clip.rectangle.color[0].color)
        else: discard
    
    frame.pts = av_rescale_q(frame.pts, time_base, codec_context[].time_base)
    frame.key_frame = 0
    frame.pict_type = AV_PICTURE_TYPE_NONE
    if avcodec_send_frame(codec_context, frame) != 0:
      echo "send_frame"
      return false
    var packet = AVPacket()
    while avcodec_receive_packet(codec_context, packet.addr) == 0:
      packet.stream_index = 0
      av_packet_rescale_ts(packet.addr, codec_context.time_base, stream.time_base)
      if av_interleaved_write_frame(format_context, packet.addr) != 0:
        echo "interleaved_write_frame"
        return false

      av_frame_free(frame.addr)
    av_packet_unref(addr packet)
  echo "finish"

  if avcodec_send_frame(codec_context, nil) != 0:
    echo "send_frame2"
    return false

  var packet = AVPacket()
  while avcodec_receive_packet(codec_context, packet.addr) == 0:
    packet.stream_index = 0
    av_packet_rescale_ts(packet.addr, codec_context.time_base, stream.time_base)
    if av_interleaved_write_frame(format_context, packet.addr) != 0:
      echo "nterleaved_write_frame2"
      return false
  
  if av_write_trailer(format_context) != 0:
    echo "trailer"
    return false

  avcodec_free_context(codec_context.addr)
  avformat_free_context(format_context)
  discard avio_closep(io_context.addr)

proc output* (video: var mVideo, path: string, muml: mumlNode): bool =
  
  if not video.decode_init:
    echo "[Runtime]: デコーダの初期化に失敗しました"
  
  video.output_path = path
  checkCorrectMVideo(video.getIOContext, "動画ファイルを開けませんでした")
  checkCorrectMVideo(video.allocMuxerMp4, "muxerをallocできませんでした")
  video.encode_format_context.pb = video.io_context

  var
    packet1 = AVPacket()
    once = true
    stream: ptr AVStream
    count = 0
    swsCtxDec: ptr SwsContext
    swsCtxEnc: ptr SwsContext

  var elements: seq[mumlObject] = @[]
  for element in muml.content.element:
    elements.add element
  
  echo "hi"

  var library = fonts.init()
  if fp.isLeft(library):
    echo "error"
    return
  var font = fp.get(library).getFont("/Users/momeemt/Library/Application Support/Adobe/CoreSync/plugins/livetype/.r/.35673.otf")
  var text_table: Table[UUID, seq[seq[int]]]
  #var character = text[text_index]
  for mumlObj in elements:
    case mumlObj.kind
    of mumlKindText:
      text_table[mumlObj.uuid] = font.getText(mumlObj.text.text)
    else: discard

  while av_read_frame(video.format_context, addr packet1) == 0:
    if packet1.stream_index == video.stream.index:
      if avcodec_send_packet(video.video_context, addr packet1) != 0:
        return false
      var frame = av_frame_alloc()
      while avcodec_receive_frame(video.video_context, frame) == 0:
        # frames.addLast(new_ref) ここでフレームをエンコーダに渡す
        ## ここでエンコーダを初期化
        if once:
          var new_ref = av_frame_alloc()
          discard av_frame_ref(new_ref, frame)
          video.frames.addLast(new_ref)
          if not getEncoderMp4(video):
            return false
          
          stream = avformat_new_stream(video.encode_format_context, video.codec)

          if stream == nil:
            return false
          
          stream.sample_aspect_ratio = video.codec_context.sample_aspect_ratio
          stream.time_base = video.codec_context.time_base

          if avcodec_parameters_from_context(stream.codecpar, video.codec_context) < 0:
            return false

          if avformat_write_header(video.encode_format_context, nil) < 0:
            return false

          swsCtxDec = sws_getContext(
            video.codec_context[].width,
            video.codec_context[].height,
            video.codec_context[].pix_fmt,
            video.codec_context[].width,
            video.codec_context[].height,
            AV_PIX_FMT_RGB24,
            SWS_BICUBIC,
            nil, nil, nil
          )

          swsCtxEnc = sws_getContext(
            video.codec_context[].width,
            video.codec_context[].height,
            AV_PIX_FMT_RGB24,
            video.codec_context[].width,
            video.codec_context[].height,
            video.codec_context[].pix_fmt,
            SWS_BICUBIC,
            nil, nil, nil
          )

          once = false

        var frame2 = av_frame_alloc()
        frame2[].format = frame[].format
        frame2[].height = frame[].height
        frame2[].width = frame[].width
        frame2[].channels = frame[].channels
        frame2[].channel_layout = frame[].channel_layout
        frame2[].nb_samples = frame[].nb_samples
        frame2[].pts = frame[].pts
        var frameRGBA = frame.copy
        frameRGBA[].format = AV_PIX_FMT_RGB24.cint

        if av_frame_get_buffer(frame2, 32) < 0:
          return false
        if av_frame_get_buffer(frameRGBA, 32) < 0:
          return false

        discard av_frame_copy(frame2, frame)
        discard av_frame_copy_props(frame2, frame)
        discard av_frame_copy(frameRGBA, frame)
        discard av_frame_copy_props(frameRGBA, frame)

        discard sws_scale(
          swsCtxDec,
          frame2[].data[0].addr,
          frame2[].linesize[0].addr,
          0,
          frame2[].height,
          frameRGBA[].data[0].addr,
          frameRGBA[].linesize[0].addr
        )
        for y in 0..<frameRGBA[].height:
          for x in 0..<frameRGBA[].width:
        #for (x, y, index) in frame2.pixel:
            let index = y * frameRGBA[].linesize[0] + x * 3
            var
              data = cast[int](frameRGBA[].data[0])
              red = cast[ptr uint8](data + index)
              green = cast[ptr uint8](data + index + 1)
              blue = cast[ptr uint8](data + index + 2)

            for mumlObj in elements:
              case mumlObj.kind:
              of mumlKindVideo:
                let filters = mumlObj.video.filters
                for filter in filters:
                  case filter.kind:
                  of colorInversion:
                    if filter.red: red[] = 255 - red[]
                    if filter.green: green[] = 255 - green[]
                    if filter.blue: blue[] = 255 - blue[]
                  of grayScale:
                    let value = (red[] * 0.3 + green[] * 0.59 + blue[] * 0.11).uint8
                    red[] = value
                    green[] = value
                    blue[] = value
              of mumlKindRectangle:
                let
                  position = mumlObj.rectangle.position[0]
                  width = mumlObj.rectangle.width[0]
                  height = mumlObj.rectangle.height[0]
                  color = mumlObj.rectangle.color[0].color
                if position.x.end == system.NaN:
                  if position.x.start.int <= x and x <= position.x.start.int + width.value.start.int:
                    if position.y.start.int <= y and y <= position.y.start.int + height.value.start.int:
                      red[] = color.red.uint8
                      green[] = color.green.uint8
                      blue[] = color.blue.uint8
                else:
                  let new_x = (position.x.end - position.x.start).float / (position.frame.end.float - position.frame.start.float).float * (count.float - position.frame.start.float).float + position.x.start.float
                  let new_y = (position.y.end - position.y.start).float / (position.frame.end.float - position.frame.start.float).float * (count.float - position.frame.start.float).float + position.y.start.float
                  if new_x.int64 <= x.int64 and x.int64 <= new_x.int64 + width.value.start.int64:
                    if new_y.int64 <= y.int64 and y.int64 <= new_y.int64 + height.value.start.int64:
                      red[] = color.red.uint8
                      green[] = color.green.uint8
                      blue[] = color.blue.uint8
              of mumlKindText:
                let
                  position = mumlObj.text.position[0]
                  color = mumlObj.text.color[0].color
                  uuid = mumlObj.uuid
                if classify(position.x.end) == fcNan:
                  if position.x.start.int <= x and x < text_table[uuid][0].len + position.x.start.int:
                    if position.y.start.int <= y and y < text_table[uuid].len + position.y.start.int:
                      if not(text_table[uuid][y-position.y.start.int][x-position.x.start.int] == 0):
                        let value = text_table[uuid][y-position.y.start.int][x-position.x.start.int]
                        red[] = (red[].float + (color.red.float - red[].float) * value.float / 255).uint8
                        green[] = (green[].float + (color.green.float - green[].float) * value.float / 255).uint8
                        blue[] = (blue[].float + (color.blue.float - blue[].float) * value.float / 255).uint8
              else: discard
        
            #frameRGBA.setRGB(index, color)

        discard sws_scale(
          swsCtxEnc,
          frameRGBA[].data[0].addr,
          frameRGBA[].linesize[0].addr,
          0,
          frameRGBA[].height,
          frame2[].data[0].addr,
          frame2[].linesize[0].addr
        )

        echo count
        count += 1

        # 本来はここにフレームに対する処理を挟む
        #echo frame2.pts
        frame2.pts = av_rescale_q(frame2.pts, video.time_base, video.codec_context.time_base)
        frame2.key_frame = 0
        frame2.pict_type = AV_PICTURE_TYPE_NONE
        if avcodec_send_frame(video.codec_context, frame2) != 0:
          return false
        var packet = AVPacket()
        while avcodec_receive_packet(video.codec_context, packet.addr) == 0:
          packet.stream_index = 0
          av_packet_rescale_ts(packet.addr, video.codec_context.time_base, stream.time_base)
          if av_interleaved_write_frame(video.encode_format_context, packet.addr) != 0:
            return false
        
        av_frame_free(frame2.addr)
        av_frame_free(frameRGBA.addr)

      av_frame_free(frame.addr)
    av_packet_unref(addr packet1)
  echo count
  
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