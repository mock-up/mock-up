#version 330 core
out vec4 frag_color;
in vec4 color;

void main(){
  vec3 changedColor = vec3(1.0, 1.0, 1.0) - color.rgb;
  frag_color = vec4(changedColor, 1.0);
}

//各ピクセルの色を決めてる