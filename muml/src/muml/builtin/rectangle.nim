import commonTypes, ../builder

type
  Rectangle* = ref object of mumlRootElement
    position*: Animation[mumlPosition]
    width*: Animation[float]
    height*: Animation[float]
    scale*: Animation[mumlScale]
    rotate*: Animation[float]
    opacity*: Animation[float]
    # color*: Animation[Color]

mumlBuilder(Rectangle)
