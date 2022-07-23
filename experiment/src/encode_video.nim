import ffmpeg

proc encodeVideo* =
  echo avcodec_find_encoder_by_name("mp4").repr
