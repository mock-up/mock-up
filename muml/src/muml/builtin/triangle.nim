import commonTypes, ../builder

type
  Triangle* = ref object of mumlRootElement
    position*: Animation[mumlPosition]
    scale*: Animation[mumlScale]
    rotate*: Animation[float]
    opacity*: Animation[float]

mumlBuilder(Triangle)
