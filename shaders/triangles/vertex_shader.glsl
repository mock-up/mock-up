#version 330 core

in vec3 vertex;
in vec2 texCoord0;
uniform mat4 mvpMatrix;
out vec2 texCoord;

void main() {
	gl_Position = mvpMatrix * vec4(vertex, 1.0);
	texCoord = texCoord0;
}