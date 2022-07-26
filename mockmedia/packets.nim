import ffmpeg

type
  Packet* = object
    ffmpeg_packet: ptr AVPacket

proc init* (_: typedesc[Packet]): Packet =
  result = Packet()
  result.ffmpeg_packet = av_packet_alloc()