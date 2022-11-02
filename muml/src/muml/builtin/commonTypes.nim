import uuids

type
  Animation* [T] = seq[T]

  mumlRootElement* = ref object of RootObj
    id*: UUID
    layer: int
    frame: Animation[int]
  
  mumlFilter* = ref object of RootObj
  
  mumlPosition* = object
    x*: float
    y*: float
    z*: float
  
  mumlScale* = object
    width*: float
    height*: float
