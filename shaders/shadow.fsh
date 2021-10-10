#version 130

uniform sampler2D tex;
uniform sampler2D specular;

in float isTerrainMap;
in vec3 terrainData;

in vec2 texcoord;

in vec4 color;

void main() {
    gl_FragData[0] = texture(tex, texcoord).aaaa * color;
    gl_FragData[1] = vec4(terrainData, 1.0);
}
/* DRAWBUFFERS:01 */