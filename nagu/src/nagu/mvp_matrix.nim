import vbo

type
  ModelMatrixVector* [V: static int] = VBO[V, float32]
  BindedModelMatrixVector* [V: static int] = BindedVBO[V, float32]

  ModelMatrix* [V: static int] = array[4, ModelMatrixVector[V]]

proc init* [V: static int] (_: typedesc[ModelMatrix[V]]): ModelMatrix[V] =
  result = [
    ModelMatrixVector[V].init(),
    ModelMatrixVector[V].init(),
    ModelMatrixVector[V].init(),
    ModelMatrixVector[V].init()
  ]
