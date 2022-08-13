import nagu, glm, muml
import utils

proc init* (T: type naguTriangle,
            header: mumlHeader,
            positions: array[3, Vec3[int]],
            # colors: array[3, tColor],
            colors: array[3, Vec4[float32]],
            vertex_shader_path: string,
            fragment_shader_path: string): naguTriangle =
  result = naguTriangle.make(
    positions.naguCoordinate(header),
    colors,
    vertex_shader_path,
    fragment_shader_path,
    mockupInitializeMvpMatrix
  )
