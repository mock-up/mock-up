#version 330 core

in vec3 vertexPositions;
in vec4 vertexColors;

in vec4 modelMatrixVec1;
in vec4 modelMatrixVec2;
in vec4 modelMatrixVec3;
in vec4 modelMatrixVec4;
mat4 modelMatrix;

uniform mat4 mvpMatrix;
out vec4 color;

void main() {
  modelMatrix = mat4(modelMatrixVec1, modelMatrixVec2, modelMatrixVec3, modelMatrixVec4);
  gl_Position = mvpMatrix * modelMatrix * vec4(vertexPositions, 1.0);
  color = vertexColors;
}