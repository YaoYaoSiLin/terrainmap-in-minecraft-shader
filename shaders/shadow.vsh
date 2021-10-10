#version 130

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;

uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform ivec2 atlasSize;

in vec3 mc_Entity;
in vec2 mc_midTexCoord;

out int vertexID;

out float vtileID;

out vec2 vtexcoord;
out vec2 midcoord;

out vec4 shadowCoord;
out vec3 worldPosition;
out vec3 vworldNormal;

out vec4 vcolor;

void main() {
    gl_Position = shadowModelViewInverse * shadowProjectionInverse * ftransform();
    worldPosition = gl_Position.xyz;

    gl_Position = shadowProjection * shadowModelView * gl_Position;
    shadowCoord = gl_Position;

    vertexID = gl_VertexID % 4;

    vtileID = mc_Entity.x;

    vworldNormal = gl_Normal;

    vcolor = gl_Color;

    vtexcoord = gl_MultiTexCoord0.st;
    midcoord = mc_midTexCoord;
}