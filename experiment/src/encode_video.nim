import ffmpeg
import std/[strformat, streams]

proc getError (num: int): string =
  var buf: array[200, cchar]
  discard av_strerror(num.cint, buf[0].addr, 200.csize_t)
  for c in buf:
    if c == '\x00': return
    result.add c

proc encode (enc_ctx: ptr AVCodecContext, frame: ptr AVFrame, pkt: ptr AVPacket, outfile: FileStream) =
  var ret: int
  if not frame.isNil:
    echo &"Send frame {frame[].pts}"
  ret = avcodec_send_frame(enc_ctx, frame)
  if ret < 0:
    raise newException(Defect, "Error sending a frame for encoding")
  
  while ret >= 0:
    ret = avcodec_receive_packet(enc_ctx, pkt)
    echo getError(ret)

    if ret < 0:
      return
    # if ret == -11: # or ret == AVERROR_EOF()
    #   return
    # elif ret < 0:
    #   raise newException(Defect, "Error during encoding")

    echo &"Write packet {pkt[].pts} (size={pkt[].size})"
    outfile.writeData(pkt[].data, pkt[].size)
    av_packet_unref(pkt)

proc encodeVideo* =
  const
    FileName = "dummy.h264"
    CodecName = "libx264"
  var
    codec: ptr AVCodec
    c: ptr AVCodecContext = nil
    ret: int
    frame: ptr AVFrame
    pkt: ptr AVPacket
    endcode: array[4, uint8] = [0'u8, 0, 1, 0xb7]

  codec = avcodec_find_encoder_by_name(CodecName)
  if codec.isNil:
    raise newException(Defect, &"Codec {CodecName} not found")

  c = avcodec_alloc_context3(codec)
  if c.isNil:
    raise newException(Defect, "Could not allocate video codec context")

  pkt = av_packet_alloc();
  if pkt.isNil:
    quit(1)

  c[].bit_rate = 400000;
  c[].width = 352;
  c[].height = 288;
  c[].time_base = av_make_q(1, 25)
  c[].framerate = av_make_q(25, 1)
  c[].gop_size = 10
  c[].max_b_frames = 1
  c[].pix_fmt = AV_PIX_FMT_YUV420P

  if codec[].id == AV_CODEC_ID_H264:
    discard av_opt_set(c[].priv_data, "preset", "slow", 0)

  ret = avcodec_open2(c, codec, nil)
  if ret < 0:
    raise newException(Defect, "Could not open codec: av_err2str(ret)")

  var f = newFileStream(FileName, FileMode.fmReadWrite)

  frame = av_frame_alloc()
  if frame.isNil:
    raise newException(Defect, "Could not allocate video frame")

  frame[].format = c[].pix_fmt.int32
  frame[].width  = c[].width
  frame[].height = c[].height

  ret = av_frame_get_buffer(frame, 0)
  if ret < 0:
    raise newException(Defect, "Could not allocate the video frame data")

  for i in 0 ..< 250:
    stdout.flushFile()
    ret = av_frame_make_writable(frame)
    if ret < 0:
      quit(1)

    for y in 0 ..< c[].height:
      for x in 0 ..< c[].width:
        cast[ptr uint8](cast[int](frame[].data[0]) + y * frame[].linesize[0] + x)[] = (x + y + i).uint8
    
    for y in 0 ..< c[].height div 2:
      for x in 0 ..< c[].width div 2:
        cast[ptr uint8](cast[int](frame[].data[1]) + y * frame[].linesize[1] + x)[] = (128 + y + i * 4).uint8
        cast[ptr uint8](cast[int](frame[].data[2]) + y * frame[].linesize[2] + x)[] = (64 + x + i * 3).uint8

    frame[].pts = i
    encode(c, frame, pkt, f)
  
  encode(c, nil, pkt, f)

  if codec[].id == AV_CODEC_ID_MPEG1VIDEO or codec[].id == AV_CODEC_ID_MPEG2VIDEO:
    f.writeData(endcode[0].addr, sizeof(endcode))

  f.close()

  avcodec_free_context(c.addr)
  av_frame_free(frame.addr)
  av_packet_free(pkt.addr)
