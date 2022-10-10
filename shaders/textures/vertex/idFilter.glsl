#version 330 core

in vec3 vertex;
in vec2 texCoord0;

in vec4 modelMatrixVec1;
in vec4 modelMatrixVec2;
in vec4 modelMatrixVec3;
in vec4 modelMatrixVec4;
mat4 modelMatrix;

uniform mat4 mvpMatrix;
out vec2 texCoord;

void main() {
	modelMatrix = mat4(modelMatrixVec1, modelMatrixVec2, modelMatrixVec3, modelMatrixVec4);
	gl_Position = mvpMatrix * modelMatrix * vec4(vertex, 1.0);
	texCoord = texCoord0;
}
