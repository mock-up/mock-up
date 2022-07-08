from ffmpeg import nil
from muml import nil
import nimgl/glfw
import images
import videos

type
  MockUpTimeline* = object
    height*: int32
    width*: int32
    header*: muml.mumlHeader
    content*: seq[MockUpLayer]
  MockUpLayer* = object
    clips*: seq[muml.mumlObject]
    beforeKey: uint
  MockUpFrame* = object
    frame: ptr ffmpeg.AVFrame
    # MockUpTimelineからあるフレームにおける構成要素が切り出される

# MockUpTimelineからこれらの要素を計算する
proc format* (timeline: MockUpTimeline): cint = discard
proc channels* (timeline: MockUpTimeline): cint = discard
proc channel_layout* (timeline: MockUpTimeline): uint64 = discard
proc nb_samples* (timeline: MockUpTimeline): cint = discard
proc pts* (timeline: MockUpTimeline): int64 = discard

proc newFrame* (timeline: MockUpTimeline): ptr ffmpeg.AVFrame =
  result = ffmpeg.av_frame_alloc()
  result.height = timeline.height
  result.width = timeline.width
  result.format = ffmpeg.AV_PIX_FMT_RGB24.cint # timeline.format
  result.channels = timeline.channels
  result.channel_layout = timeline.channel_layout
  result.nb_samples = timeline.nb_samples
  result.pts = timeline.pts

proc video = discard

# proc streaming* (timeline: MockUpTimeline, frame_number: int): MockUpFrame =
#   result.frame = timeline.newFrame()
#   if ffmpeg.av_frame_get_buffer(result.frame, 32) < 0:
#     return # Leftを返すようにする

#   # 動画, 画像をデコードする
#   # mumlをパースして読む
#   for layer in timeline.content:
#     let clip = layer.clips[layer.beforeKey] # clipを読み出す
#     if not clip.frame.start <= frame_number:
#       continue # 次のレイヤーをチェックする
#     if not clip.frame.end - 1 == frame_number:
#       discard # beforeKeyを更新する
#     case clip.kind:
#     of muml.mumlKindVideo: discard
#       # 動画をデコード
#       # frame[].dataからテクスチャを生成
#       # OpenGLに貼り付け
#     of muml.mumlKindRectangle: discard
#       # OpenGLで描画
#     # of muml.mumlKindText: discard
#     else: discard

## ここから

proc initialize_avformat_context (format_name: string): ptr ffmpeg.AVFormatContext =
  result = nil
  if ffmpeg.avformat_alloc_output_context2(result.addr, nil, format_name, nil) < 0:
    raise newException(FFmpegError, "Could not allocate output format context!")

proc initialize_io_context (fctx: ptr ffmpeg.AVFormatContext, output: string) =
  echo output
  if (fctx[].oformat[].flags and ffmpeg.AVFMT_NOFILE) == 0:
    let ret: cint = ffmpeg.avio_open2(fctx[].pb.addr, output, ffmpeg.AVIO_FLAG_WRITE, nil, nil)
    var error: array[1024, char]
    discard ffmpeg.av_strerror(ret, error[0].addr, 1024)
    # echo error
    if ret < 0:
      raise newException(FFmpegError, "Could not open output IO context!")

proc set_codec_params (fctx: ptr ffmpeg.AVFormatContext, codec_ctx: ptr ffmpeg.AVCodecContext, video: MockupVideo) =

  codec_ctx[].codec_tag = 0
  codec_ctx[].codec_id = ffmpeg.AV_CODEC_ID_H264
  codec_ctx[].codec_type = ffmpeg.AVMEDIA_TYPE_VIDEO
  codec_ctx[].width = video.width
  codec_ctx[].height = video.height
  codec_ctx[].gop_size = 12
  codec_ctx[].pix_fmt = ffmpeg.AV_PIX_FMT_YUV420P
  codec_ctx[].framerate = ffmpeg.AVRational(num: 60, den: 1)
  codec_ctx[].time_base = ffmpeg.AVRational(num: 1, den: 1) # video.codecContext[].time_base
  # codec_ctx[].ticks_per_frame = 28
  # codec_ctx[].debug = 1
  if (fctx[].oformat[].flags and ffmpeg.AVFMT_GLOBALHEADER) != 0:
    codec_ctx[].flags = codec_ctx[].flags or ffmpeg.AV_CODEC_FLAG_GLOBAL_HEADER

proc initialize_codec_stream (stream: ptr ffmpeg.AVStream, codec_ctx: ptr ffmpeg.AVCodecContext, codec: ptr ffmpeg.AVCodec) =
  if ffmpeg.avcodec_parameters_from_context(stream[].codecpar, codec_ctx) < 0:
    raise newException(FFmpegError, "Could not initialize stream codec parameters!")
  var codec_options: ptr ffmpeg.AVDictionary = nil

  discard ffmpeg.av_dict_set(codec_options.addr, "profile", "high", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "preset", "superfast", 0)
  discard ffmpeg.av_dict_set(codec_options.addr, "tune", "zerolatency", 0)

  if ffmpeg.avcodec_open2(codec_ctx, codec, codec_options.addr) < 0:
    raise newException(FFmpegError, "Could not open video encoder!")

type MockUpStreaming = object
  ofmt_ctx: ptr ffmpeg.AVFormatContext
  out_stream: ptr ffmpeg.AVStream
  out_codec_ctx: ptr ffmpeg.AVCodecContext
  swsctx: ptr ffmpeg.SwsContext

proc initStreaming* (output: string, video: MockupVideo): MockUpStreaming =
  result.ofmt_ctx = initialize_avformat_context("flv")
  result.ofmt_ctx.initialize_io_context(output)

  var out_codec = ffmpeg.avcodec_find_encoder(ffmpeg.AV_CODEC_ID_H264)
  
  result.out_stream = ffmpeg.avformat_new_stream(result.ofmt_ctx, out_codec)
  result.out_codec_ctx = ffmpeg.avcodec_alloc_context3(out_codec)
  
  set_codec_params(result.ofmt_ctx, result.out_codec_ctx, video)
  initialize_codec_stream(result.out_stream, result.out_codec_ctx, out_codec)

  result.out_stream[].codecpar[].extradata = result.out_codec_ctx[].extradata
  result.out_stream[].codecpar[].extradata_size = result.out_codec_ctx[].extradata_size

  result.swsctx = getEncoderSwscontext(result.out_codec_ctx, ffmpeg.AV_PIX_FMT_RGBA)

  if ffmpeg.avformat_write_header(result.ofmt_ctx, nil) < 0:
    raise newException(FFmpegError, "Could not write header!")

var framenum = 1

proc sendFrame* (streaming: MockUpStreaming, src_frame: MockupImage) =
  var
    frame = src_frame
    dest_frame = src_frame
    packet = ffmpeg.AVPacket()
  dest_frame.frame = src_frame.frame.prepareCopyFrame
  dest_frame.frame[].format = streaming.out_codec_ctx[].pix_fmt.cint
  if ffmpeg.av_frame_get_buffer(dest_frame.frame, 32) < 0:
    raise newException(FFmpegError, "バッファの割り当てに失敗しました")
  discard ffmpeg.sws_scale(
    streaming.swsctx,
    frame.frame[].data[0].addr,
    frame.frame[].linesize[0].addr,
    0,
    frame.frame[].height,
    dest_frame.frame[].data[0].addr,
    dest_frame.frame[].linesize[0].addr
  )
  # dest_frame.frame.pts = ffmpeg.av_rescale_q(
  #   src_frame.frame.pts, streaming.out_codec_ctx.time_base, streaming.out_stream[].time_base
  # )
  dest_frame.frame.pts += ffmpeg.av_rescale_q(1, streaming.out_codec_ctx[].time_base, streaming.out_stream[].time_base)
  #dest_frame.frame.key_frame = 0
  #dest_frame.frame.pict_type = ffmpeg.AV_PICTURE_TYPE_NONE
  if ffmpeg.avcodec_send_frame(streaming.out_codec_ctx, dest_frame.frame) != 0:
    raise newException(FFmpegError, "エンコーダーへのフレームの供給に失敗しました")
  while ffmpeg.avcodec_receive_packet(streaming.out_codec_ctx, packet.addr) == 0:
    packet.stream_index = 0
    streaming.out_stream.time_base = ffmpeg.AVRational(num: 60, den: 1)
    ffmpeg.av_packet_rescale_ts(
      packet.addr, streaming.out_codec_ctx.time_base, streaming.out_stream.time_base
    )
    framenum += 1
    if ffmpeg.av_interleaved_write_frame(streaming.ofmt_ctx, packet.addr) != 0:
      raise newException(FFmpegError, "パケットの書き込みに失敗しました")
  ffmpeg.av_packet_unref(packet.addr)

proc finish* (streaming: MockUpStreaming) =
  discard ffmpeg.av_write_trailer(streaming.ofmt_ctx)
  discard ffmpeg.avcodec_close(streaming.out_codec_ctx)
  discard ffmpeg.avio_close(streaming.ofmt_ctx[].pb)
  # ffmpeg.avformat_free_context(streaming.ofmt_ctx)