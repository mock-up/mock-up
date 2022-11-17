import ffmpeg
import results

type
  H264* = object
    codec: ptr AVCodec # DE
    codecCtx: ptr AVCodecContext # DE
    codecParams: ptr AVCodecParameters # D
    ioCtx: ptr AVIOContext # E
    fmtCtx: ptr AVFormatContext # DE
    stream: ptr AVStream # DE

  VideoFrame* = object
    frame: ptr AVFrame

func width* (h264: H264): int32 =
  result = h264.codecCtx.width

func height* (h264: H264): int32 =
  result = h264.codecCtx.height

func fps* (h264: H264): int32 =
  result = h264.codecCtx.timebase.den
  result = av_q2d(h264.stream.r_frame_rate).int32

# proc `=destroy`* (h264: var H264) =
#   echo "=destroy"
#   avcodec_free_context(h264.codecCtx.addr)
#   avformat_free_context(h264.fmtCtx)
#   discard avio_closep(h264.ioCtx.addr)

# proc `=destroy`* (frame: var VideoFrame) =
#   discard

# proc `=copy`* (dest: var VideoFrame; src: VideoFrame) =
#   if dest == src: return
#   `=destroy`(dest)

proc findH264Encoder* (): Result[ptr AVCodec, string] =
  let encoder = avcodec_find_encoder(AV_CODEC_ID_H264)
  if encoder.isNil:
    return err("failed to find H264 encoder")
  return ok(encoder)

proc allocCodecContext* (codec: ptr AVCodec): Result[ptr AVCodecContext, string] =
  let ctx = avcodec_alloc_context3(codec)
  if ctx.isNil:
    return err("failed to alloc codec context")
  return ok(ctx)

proc set* (dict: var ptr AVDictionary, key, value: string): Result[(), string] =
  if av_dict_set(dict.addr, key.cstring, value.cstring, 0) < 0:
    return err("failed to set to AVDictionary")
  return ok(())

func toAVIOFlag* (mode: FileMode): cint =
  case mode
  of fmRead:
    result = AVIO_FLAG_READ
  of fmWrite:
    result = AVIO_FLAG_WRITE
  of fmReadWrite:
    result = AVIO_FLAG_READ_WRITE
  else:
    # TODO
    discard

proc allocIOContext* (distPath: string, flag: FileMode): Result[ptr AVIOContext, string] =
  var ioCtx: ptr AVIOContext = nil
  if avio_open(ioCtx.addr, distPath, flag.toAVIOFlag) < 0:
    return err("failed to initialize IO-context")
  return ok(ioCtx)

proc allocFormatContext* (formatName: string): Result[ptr AVFormatContext, string] =
  var fmtCtx: ptr AVFormatContext = nil
  if avformat_alloc_output_context2(fmtCtx.addr, nil, formatName.cstring, nil) < 0:
    return err("failed to alloc context for output format")
  return ok(fmtCtx)

proc initializeCodecContext* (codecCtx: ptr AVCodecContext, codecOpts: var ptr AVDictionary): Result[(), string] =
  if avcodec_open2(codecCtx, codecCtx[].codec, codecOpts.addr) < 0:
    return err("failed to initialize codec context")
  return ok(())

proc initializeCodecContext* (codecCtx: ptr AVCodecContext, codec: ptr AVCodec): Result[(), string] =
  if avcodec_open2(codecCtx, codec, nil) < 0:
    return err("failed to initialize codec context")
  return ok(())

proc allocStream* (fmtCtx: ptr AVFormatContext, codec: ptr AVCodec): Result[ptr AVStream, string] =
  var stream = avformat_new_stream(fmtCtx, codec)
  if stream.isNil:
    return err("failed to alloc stream")
  return ok(stream)

proc fillCodecParameters* (params: ptr AVCodecParameters, codecCtx: ptr AVCodecContext): Result[(), string] =
  if avcodec_parameters_from_context(params, codecCtx) < 0:
    return err("failed to fill codec context")
  return ok(())

proc writeHeader* (fmtCtx: ptr AVFormatContext): Result[(), string] =
  if avformat_write_header(fmtCtx, nil) < 0:
    return err("failed to write header")
  return ok(())

func frameCount* (h264: H264): int =
  result = h264.codecCtx.frame_number

proc newH264* (distPath: string, width, height, fps: int32): Result[H264, string] =
  var h264 = H264()
  h264.codec = ?findH264Encoder()
  h264.codecCtx = ?allocCodecContext(h264.codec)
  h264.codecCtx.pix_fmt = AV_PIX_FMT_YUV420P
  h264.codecCtx.width = width
  h264.codecCtx.height = height
  h264.codecCtx.time_base = av_make_q(1, fps)
  h264.codecCtx.framerate = av_make_q(fps, 1)
  h264.codecCtx.gop_size = 10
  h264.codecCtx.max_b_frames = 1
  h264.codecCtx.bit_rate = 400000
  var codecOptions: ptr AVDictionary = nil
  discard ?codecOptions.set("profile", "high")
  discard ?codecOptions.set("preset", "medium")
  discard ?codecOptions.set("crf", "22")
  discard ?codecOptions.set("level", "4.0")
  h264.ioCtx = ?allocIOContext(distPath, fmWrite)
  h264.fmtCtx = ?allocFormatContext("mp4")
  h264.fmtCtx.pb = h264.ioCtx
  discard ?initializeCodecContext(h264.codecCtx, codecOptions)
  h264.stream = ?h264.fmtCtx.allocStream(h264.codec)
  discard ?h264.stream.codecpar.fillCodecParameters(h264.codecCtx)
  discard ?h264.fmtCtx.writeHeader()
  result = ok(h264)

proc openH264FromSrc (fmtCtx: var ptr AVFormatContext, srcPath: string): Result[(), string] =
  if avformat_open_input(fmtCtx.addr, srcPath, nil, nil) != 0:
    return err("failed to open video file")
  return ok(())

proc findStreamInfo (fmtCtx: var ptr AVFormatContext): Result[(), string] =
  echo fmtCtx.repr
  if avformat_find_stream_info(fmtCtx, nil) < 0:
    return err("failed to find stream information")
  return ok(())

proc getVideoDecoder (fmtCtx: ptr AVFormatContext): Result[(ptr AVCodec, ptr AVCodecParameters, ptr AVStream), string] =
  var
    codec: ptr AVCodec = nil
    codecParams: ptr AVCodecParameters = nil
    videoStream: ptr AVStream = nil
  var streams = cast[ptr UncheckedArray[ptr AVStream]](fmtCtx[].streams)
  for index in 0 ..< fmtCtx.nb_streams:
    let locpar = streams[index].codecpar
    if locpar.codec_type == AVMEDIA_TYPE_VIDEO:
      codec = avcodec_find_decoder(locpar.codec_id)
      codecParams = locpar
      videoStream = streams[index]
      break
  if codec.isNil or codecParams.isNil:
    return err("failed to get video decoder")
  return ok((codec, codecParams, videoStream))

proc newPacket* (): Result[ptr AVPacket, string] =
  var p = av_packet_alloc()
  if p.isNil:
    return err("failed to alloc packet")
  return ok(p)

proc initSwsContext* (width, height: int32, srcFmtPix, destFmtPix: AVPixelFormat): ptr SwsContext =
  result = sws_getContext(
    width, height, srcFmtPix,
    width, height, destFmtPix,
    SWS_BICUBIC,
    nil, nil, nil
  )

proc scale* (swsCtx: ptr SwsContext, srcFrame, destFrame: VideoFrame): int =
  result = sws_scale(
    swsCtx,
    srcFrame.frame[].data[0].addr,
    srcFrame.frame[].linesize[0].addr,
    0,
    srcFrame.frame[].height,
    destFrame.frame[].data[0].addr,
    destFrame.frame[].linesize[0].addr
  )

proc openH264* (srcPath: string): Result[H264, string] =
  var h264 = H264()
  discard ?h264.fmtCtx.openH264FromSrc(srcPath)
  discard ?h264.fmtCtx.findStreamInfo()
  (h264.codec, h264.codecParams, h264.stream) = ?h264.fmtCtx.getVideoDecoder()
  h264.codecCtx = ?allocCodecContext(h264.codec)
  if avcodec_parameters_to_context(h264.codecCtx, h264.codecParams) < 0:
    return err("failed to initialize codec parameters")
  discard ?h264.codecCtx.initializeCodecContext(h264.codec)
  echo h264.width
  return ok(h264)

proc send* (codecCtx: var ptr AVCodecContext, packet: ptr AVPacket): Result[(), string] =
  if avcodec_send_packet(codecCtx, packet) != 0:
    return err("failed to get packet")
  return ok(())

proc newFrame* (): VideoFrame =
  result = VideoFrame(frame: av_frame_alloc())

proc copy* (src: VideoFrame): Result[VideoFrame, string] =
  var frame = newFrame()
  frame.frame.format = src.frame.format
  frame.frame.height = src.frame.height
  frame.frame.width = src.frame.width
  if av_frame_get_buffer(frame.frame, 32) < 0:
    return err("failed to allocate buffer")
  if av_frame_copy(frame.frame, src.frame) < 0:
    return err("failed to copy frame data")
  if av_frame_copy_props(frame.frame, src.frame) < 0:
    return err("failed to copy metadata of frame")
  return ok(frame)

proc allocFrameBuffer* (frame: var VideoFrame, align: int32): Result[(), string] =
  if av_frame_get_buffer(frame.frame, align) < 0:
    return err("failed to alloc frame buffer")
  return ok(())

iterator decodeH264* (h264: var H264): VideoFrame =
  var
    packet = newPacket().unwrap() # TODO
    swsCtx = initSwsContext(h264.codecCtx.width, h264.codecCtx.height, AV_PIX_FMT_YUV420P, AV_PIX_FMT_RGBA)
  while av_read_frame(h264.fmtCtx, packet) == 0:
    if packet.stream_index != h264.stream.index:
      av_packet_unref(packet)
      continue
    discard h264.codecCtx.send(packet).unwrap()
    var frame = newFrame()
    while avcodec_receive_frame(h264.codecCtx, frame.frame) == 0:
      var
        copyFrame = frame.copy().unwrap()
        frameRGBA = newFrame()
      frameRGBA.frame.format = AV_PIX_FMT_RGBA.cint
      frameRGBA.frame.height = frame.frame.height
      frameRGBA.frame.width = frame.frame.width
      discard frameRGBA.allocFrameBuffer(32).unwrap()
      discard swsCtx.scale(copyFrame, frameRGBA)
      yield frameRGBA
    av_frame_free(frame.frame.addr)
  av_packet_unref(packet)

proc send* (codecCtx: var ptr AVCodecContext, frame: VideoFrame): Result[(), string] =
  if avcodec_send_frame(codecCtx, frame.frame) < 0:
    return err("failed to supply frame for codec context")
  return ok(())

proc receive* (h264: var H264): Result[(), string] =
  var packet = ?newPacket()
  while avcodec_receive_packet(h264.codecCtx, packet) == 0:
    packet.stream_index = 0
    av_packet_rescale_ts(packet, h264.codecCtx.time_base, h264.stream.time_base)
    if av_interleaved_write_frame(h264.fmtCtx, packet) != 0:
      return err("failed to write to packet")
  av_packet_unref(packet)
  return ok(())

proc addFrame* (h264: var H264, srcFrame: VideoFrame): Result[(), string] =
  var frame = newFrame()
  frame.frame.format = h264.codecCtx.pix_fmt.cint
  frame.frame.width = srcFrame.frame.width
  frame.frame.height = srcFrame.frame.height
  frame.frame.pts = h264.frameCount()
  discard ?frame.allocFrameBuffer(32)
  var swsCtx = initSwsContext(h264.codecCtx.width, h264.codecCtx.height, AV_PIX_FMT_RGBA, h264.codecCtx.pix_fmt)
  discard swsCtx.scale(srcFrame, frame)
  discard ?h264.codecCtx.send(frame)
  discard ?h264.receive()

proc flush* (h264: var H264): Result[(), string] =
  if avcodec_send_frame(h264.codecCtx, nil) != 0:
    return err("failed to flush")
  var packet = ?newPacket()
  while avcodec_receive_packet(h264.codecCtx, packet) == 0:
    packet.stream_index = 0
    av_packet_rescale_ts(packet, h264.codecCtx.time_base, h264.stream.time_base)
    if av_interleaved_write_frame(h264.fmtCtx, packet) != 0:
      return err("failed to flush")
  if av_write_trailer(h264.fmtCtx) != 0:
    return err("failed to flush")
  avcodec_free_context(h264.codecCtx.addr)
  avformat_free_context(h264.fmtCtx)
  discard avio_closep(h264.ioCtx.addr)
  return ok(())
