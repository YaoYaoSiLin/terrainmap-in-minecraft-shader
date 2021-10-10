#version 130

uniform sampler2D tex;

in vec2 texcoord;

in vec4 color;

void main() {
    gl_FragData[0] = texture(tex, texcoord) * color;
}
/* DRAWBUFFERS:0 */