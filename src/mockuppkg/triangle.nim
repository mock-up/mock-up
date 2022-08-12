import nagu, glm, muml

func naguCoordinate* (positions: array[3, Vec3[int]], header: mumlHeader): array[3, Vec3[float32]] =
  for index in 0..2:
    result[index][0] = positions[index][0] / header.width + 0.5
    result[index][1] = positions[index][1] / header.height + 0.5
    result[index][2] = positions[index][2].float32

const mockupInitializeMvpMatrix = [
  1f, 0.0f, 0.0f, 0.0f,
  0.0f, 1f, 0.0f, 0.0f,
  0.0f, 0.0f, 1.0f, 0.0f,
  -0.5f, -0.5f, 0.0f, 1.0f
]

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
