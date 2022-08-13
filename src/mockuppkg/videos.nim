import frames
import ffmpeg
import nagu
import muml
import glm
import utils

type
  mockupVideo* = object
    format_context: ptr AVFormatContext
    codec: ptr AVCodec
    codec_param: ptr AVCodecParameters
    codec_context: ptr AVCodecContext
    stream: ptr AVStream
    vertex_shader_path: string
    fragment_shader_path: string
    positions: array[4, Vec3[int]]
    frame_counter: tuple[start, stop: int]
    decoded_frames: seq[ptr AVFrame]

proc width* (video: mockupVideo): int32 =
  result = video.codec_context.width.int32

proc height* (video: mockupVideo): int32 =
  result = video.codec_context.height.int32

proc formatConvert (src: ptr AVFrame, format_converter: ptr SwsContext): ptr AVFrame =
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

proc init* (T: type mockupVideo,
            position: Vec3[int],
            src_path: string,
            vertex_shader_path: string,
            fragment_shader_path: string): mockupVideo =
  result.vertex_shader_path = vertex_shader_path
  result.fragment_shader_path = fragment_shader_path
  result.frame_counter = (-1, -1)
  if avformat_open_input(result.format_context.addr, src_path, nil, nil) != 0:
    raise newException(Defect, "動画ファイルを開けませんでした")
  
  if avformat_find_stream_info(result.format_context, nil) < 0:
    raise newException(Defect, "ストリーム情報取得に失敗しました")

  let streams = cast[ptr UncheckedArray[ptr AVStream]](result.format_context[].streams)
  for stream_index in 0 ..< result.format_context[].nb_streams:
    let locpar = streams[stream_index][].codecpar
    if locpar[].codec_type == AVMEDIA_TYPE_VIDEO:
      result.codec = avcodec_find_decoder(locpar[].codec_id)
      result.codec_param = locpar
      result.stream = streams[stream_index]
      break
  if result.codec.isNil or result.codec_param.isNil:
    raise newException(Defect, "デコーダの取得に失敗しました")

  result.codec_context = avcodec_alloc_context3(result.codec)
  
  if avcodec_parameters_to_context(result.codec_context, result.codec_param) < 0:
    raise newException(Defect, "コーデックパラメータの初期化に失敗しました")

  if avcodec_open2(result.codec_context, result.codec, nil) < 0:
    raise newException(Defect, "コーデックの初期化に失敗しました")
  
  let (x, y, z) = (
    (result.width) div 2 + position[0],
    (result.height) div 2 + position[1],
    position[2]
  )
  result.positions = [
    vec3(-x, y, z),
    vec3(-x, -y, z),
    vec3(x, -y, z),
    vec3(x, y, z),
  ]

func frameNumber (video: mockupVideo): int =
  # `video`が持つフレーム数を返します
  result = video.codec_context[].frame_number

proc decode* (video: var mockupVideo, header: mumlHeader, frameCount: int): mockupFrame =
  var
    packet = AVPacket()
    format_converter = sws_getContext(
      video.codec_context[].width,
      video.codec_context[].height,
      video.codec_context[].pix_fmt,
      video.codec_context[].width,
      video.codec_context[].height,
      AV_PIX_FMT_RGBA,
      SWS_BICUBIC,
      nil, nil, nil
    )
  var image = mockupFrame.init(
    header,
    video.positions,
    video.vertex_shader_path,
    video.fragment_shader_path
  )


  if video.frame_counter.start <= frameCount and frameCount <= video.frame_counter.stop:
    var frame = video.decoded_frames[frameCount - video.frame_counter.start]
    image.naguTexture.use do (texture: var naguBindedTexture):
      texture.pixels = (data: frame.data[0], width: frame[].width.uint, height: frame[].height.uint)
    return image

  var frame_counter = video.frame_counter.stop
  video.frame_counter.start = video.frame_counter.stop + 1
  video.decoded_frames = @[]
  
  while av_read_frame(video.format_context, packet.addr) == 0:
    if packet.stream_index != video.stream.index:
      av_packet_unref(packet.addr)
      continue
    if avcodec_send_packet(video.codec_context, packet.addr) != 0:
      raise newException(Defect, "パケットの取り出しに失敗しました")
    var frame = av_frame_alloc()
    while avcodec_receive_frame(video.codec_context, frame) == 0:
      var
        copy_frame = frame.copy # 元ポインタを直接操作するとバグる
        frame_RGBA = copy_frame.formatConvert(format_converter) # RGBAに変換する
      frame_counter += 1
      video.decoded_frames.add frame_RGBA
    av_frame_free(frame.addr)
  av_packet_unref(packet.addr)
  video.frame_counter.stop = frame_counter

  echo frame_counter
  var frame = video.decoded_frames[0]
  image.naguTexture.use do (texture: var naguBindedTexture):
    texture.pixels = (data: frame.data[0], width: frame[].width.uint, height: frame[].height.uint)
  return image

iterator decodeVideo* (video: var mockupVideo, header: mumlHeader): mockupFrame =
  var
    packet = AVPacket()
    format_converter = sws_getContext(
      video.codec_context[].width,
      video.codec_context[].height,
      video.codec_context[].pix_fmt,
      video.codec_context[].width,
      video.codec_context[].height,
      AV_PIX_FMT_RGBA,
      SWS_BICUBIC,
      nil, nil, nil
    )
  var image = mockupFrame.init(
    header,
    video.positions,
    video.vertex_shader_path,
    video.fragment_shader_path
  )
  while av_read_frame(video.format_context, packet.addr) == 0:
    if packet.stream_index != video.stream.index:
      av_packet_unref(packet.addr)
      continue
    if avcodec_send_packet(video.codec_context, packet.addr) != 0:
      raise newException(Defect, "パケットの取り出しに失敗しました")
    var frame = av_frame_alloc()
    while avcodec_receive_frame(video.codec_context, frame) == 0:
      var
        copy_frame = frame.copy # 元ポインタを直接操作するとバグる
        frame_RGBA = copy_frame.formatConvert(format_converter) # RGBAに変換する
      image.naguTexture.use do (texture: var naguBindedTexture):
        texture.pixels = (data: frame_RGBA.data[0], width: frame_RGBA[].width.uint, height: frame_RGBA[].height.uint)
      
      if frame_RGBA[].key_frame == 1:
        echo "keyframe: ", frame_RGBA.pts
      yield image
    av_frame_free(frame.addr)
  av_packet_unref(packet.addr)

proc seek* (video: var mockupVideo, frame: int) =
  if av_seek_frame(video.format_context, video.stream[].index, frame, AVSEEK_FLAG_BACKWARD) < 0:
    echo "av_seek_frame failed"
  avcodec_flush_buffers(video.codec_context)
