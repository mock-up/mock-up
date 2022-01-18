#version 330 core

layout(location = 0) in vec3 vertexPosition_modelspace;
layout(location = 1) in vec4 vertexColor;
uniform mat4 mvpMatrix;
out vec4 color;

void main() {
  gl_Position = mvpMatrix * vec4(vertexPosition_modelspace, 1.0);
  color = vertexColor;
}