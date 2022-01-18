import video, image

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
      video*: video.mVideo
    of mImage:
      image*: image.mImage
    else: discard