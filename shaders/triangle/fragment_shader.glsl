#version 330 core
uniform sampler2D frameTex;
in vec2 texCoord;
out vec4 fragColor;
void main() {
  fragColor = texture(frameTex, texCoord);
  float ave = (fragColor.x + fragColor.y + fragColor.z) / 3;
  fragColor = vec4(ave, ave, ave, 1.0);
}