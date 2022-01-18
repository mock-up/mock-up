#version 330 core
out vec4 frag_color;
in vec4 color;

void main(){
  frag_color = vec4(color.rgb, 1.0);
}
