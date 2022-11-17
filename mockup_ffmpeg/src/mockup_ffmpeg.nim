import ffmpeg
import mockup_ffmpeg/results

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

proc set* (dict: ptr AVDictionary, key, value: string): Result[(), string] =
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

proc initializeCodecContext* (codecCtx: ptr AVCodecContext, codecOpts: ptr AVDictionary): Result[(), string] =
  if avcodec_open2(codecCtx, codecCtx[].codec, codecOpts.addr) < 0:
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

type
  H264* = object
    codec: ptr AVCodec
    codecCtx: ptr AVCodecContext
    codecOptions: ptr AVDictionary
    ioCtx: ptr AVIOContext
    fmtCtx: ptr AVFormatContext
    stream: ptr AVStream
    frameCount: int
  
  VideoFrame* = object
    frame: ptr AVFrame

proc `=destroy`* (h264: var H264) =
  avcodec_free_context(h264.codecCtx.addr)
  avformat_free_context(h264.fmtCtx)
  discard avio_closep(h264.ioCtx.addr)

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
  discard ?h264.codecOptions.set("profile", "high")
  discard ?h264.codecOptions.set("preset", "medium")
  discard ?h264.codecOptions.set("crf", "22")
  discard ?h264.codecOptions.set("level", "4.0")
  h264.ioCtx = ?allocIOContext(distPath, fmWrite)
  h264.fmtCtx = ?allocFormatContext("mp4")
  h264.fmtCtx.pb = h264.ioCtx
  discard ?initializeCodecContext(h264.codecCtx, h264.codecOptions)
  h264.stream = ?h264.fmtCtx.allocStream(h264.codec)
  discard ?h264.stream.codecpar.fillCodecParameters(h264.codecCtx)
  discard ?h264.fmtCtx.writeHeader()
  result = ok(h264)

proc `=destroy`* (frame: var VideoFrame) =
  discard

proc `=copy`* (dest: var VideoFrame; src: VideoFrame) =
  if dest == src: return
  `=destroy`(dest)

proc newFrame* (): VideoFrame =
  result = VideoFrame(frame: av_frame_alloc())

proc allocFrameBuffer* (frame: var VideoFrame, align: int32): Result[(), string] =
  if av_frame_get_buffer(frame.frame, align) < 0:
    return err("failed to alloc frame buffer")
  return ok(())

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

proc newPacket* (): Result[ptr AVPacket, string] =
  var p = av_packet_alloc()
  if p.isNil:
    return err("failed to alloc packet")
  return ok(p)

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
  frame.frame.format = srcFrame.frame.format
  frame.frame.width = srcFrame.frame.width
  frame.frame.height = srcFrame.frame.height
  frame.frame.pts = h264.frameCount
  h264.frameCount += 1
  discard ?frame.allocFrameBuffer(32)
  var swsCtx = initSwsContext(h264.codecCtx.width, h264.codecCtx.height, AV_PIX_FMT_RGBA, h264.codecCtx.pix_fmt)
  discard swsCtx.scale(srcFrame, frame)
  discard ?h264.codecCtx.send(frame)
  discard ?h264.receive()