import shape
import glm

type
  naguTriangleObj [binded: static bool] = ShapeObj[binded, 3, 9, 12]
  naguTriangle* = ref naguTriangleObj[false]
  naguBindedTriangle* = ref naguTriangleObj[true]
