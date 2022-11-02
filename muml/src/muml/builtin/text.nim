import commonTypes, ../builder

type
  Text* = ref object of mumlRootElement
    position*: Animation[mumlPosition]
    text*: string
    # color*: Animation[Color]

mumlBuilder(Text)
