import commonTypes, ../builder

type
  mumlVideoFrame* = object
    start*: int
    stop*: int

  Video* = ref object of mumlRootElement
    path*: string
    videoFrame*: mumlVideoFrame
    position*: Animation[mumlPosition]
    scale*: Animation[mumlScale]
    rotate*: Animation[float]
    opacity*: Animation[float]
    # filters*: seq[mumlFilter]
    # audio*: mumlAudio

mumlBuilder(Video)
