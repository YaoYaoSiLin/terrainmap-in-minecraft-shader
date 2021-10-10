#version 330 compatibility

layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform ivec2 atlasSize;

in int[3] vertexID;

in float[3] vtileID;

in vec2[3] vtexcoord;
in vec2[3] midcoord;
in vec2[3] texelcoord;

in vec4[3] vcolor;

in vec4[3] shadowCoord;
in vec3[3] worldPosition;
in vec3[3] vworldNormal;

out float isTerrainMap;
out vec3 terrainData;

out vec2 texcoord;

out vec4 color;

//#define Shadow_Map

const int shadowMapResolution = 2048;
const float shadowDistance = 128.0;

float shadowTexelSize = 1.0 / float(shadowMapResolution);

float voxelRenderDistance_radius = 50.0;
float voxelRenderHeight_radius = 32.0;

vec3 boxMin = vec3(-voxelRenderDistance_radius, -64.0, -voxelRenderDistance_radius);
vec3 boxMax = vec3( voxelRenderDistance_radius, 319.0,  voxelRenderDistance_radius);

//vec2 GetFragBox(in vec3 )

float GetFragMinDistance(float p0, float p1, float p2) {
    return min(abs(p0), min(abs(p1), abs(p2)));
}

vec4 nvec4(in vec3 x) {
    return vec4(x, 1.0);
}

vec3 nvec3(in vec4 x) {
    return x.xyz / x.w;
}

float sdBox( vec3 p, vec3 b ) {
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

vec2 IntersectCube(in vec3 position, in vec3 direction, in vec3 size){
    vec3 dr = 1.0 / direction;
    vec3 n = position * dr;
    vec3 k = size * abs(dr);

    vec3 pin = -k - n;
    vec3 pout = k - n;

    float near = max(pin.x, max(pin.y, pin.z));
    float far = min(pout.x, min(pout.y, pout.z));

    if(far > 0.0 || near > 0.0) {
        return vec2(near, far);
    }else{
        return vec2(-1.0);
    }
}

void main() {
    isTerrainMap = 0.0;
    terrainData = vec3(0.0);

    vec3 fragPosition = (worldPosition[0] + worldPosition[1] + worldPosition[2]) / 3.0;
/*
    if(max(GetFragMinDistance(worldPosition[0].x, worldPosition[1].x, worldPosition[2].x), GetFragMinDistance(worldPosition[0].z, worldPosition[1].z, worldPosition[2].z)) > voxelRenderDistance_radius
    || GetFragMinDistance(worldPosition[0].y, worldPosition[1].y, worldPosition[2].y) > voxelRenderHeight_radius) {
        gl_Position = vec4(-1.0);
        EmitVertex();
        gl_Position = vec4(-1.0);
        EmitVertex();
        gl_Position = vec4(-1.0);
        EmitVertex();
        EndPrimitive();
    }
*/
    #ifdef Shadow_Map
    for(int i = 0; i < 3; i++) {
        texcoord = vtexcoord[i];

        color = vcolor[i];

        gl_Position = shadowCoord[i];

        EmitVertex();
    } EndPrimitive();
    #endif

    const vec2[4] offset = vec2[4](vec2(-1, -1), vec2(1, -1), vec2(1, 1),vec2(-1, 1));

    float tileID = vtileID[0];

    vec2 atla = vec2(atlasSize);

    float tileSizeX = min(abs(vtexcoord[0].x - vtexcoord[1].x), abs(vtexcoord[0].x - vtexcoord[2].x)) * atla.x;
    float tileSizeY = min(abs(vtexcoord[0].y - vtexcoord[1].y), abs(vtexcoord[0].y - vtexcoord[2].y)) * atla.y;
    float tileSize = round(min(tileSizeX, tileSizeY));

    float fragSize = min(distance(worldPosition[0], worldPosition[1]), distance(worldPosition[0], worldPosition[2]));

    vec3 blockCenter = floor(fragPosition + cameraPosition - vworldNormal[0] * 0.001) + 0.5;
    float cubeDistance0 = sdBox(worldPosition[0] + cameraPosition - blockCenter, vec3(0.0));
    float cubeDistance1 = sdBox(worldPosition[1] + cameraPosition - blockCenter, vec3(0.0));
    float cubeDistance2 = sdBox(worldPosition[2] + cameraPosition - blockCenter, vec3(0.0));
    float cubeDistanceA = sdBox(fragPosition + cameraPosition - blockCenter, vec3(0.0));

    vec2 mappingToTexel = floor(floor(fragPosition.xz + cameraPosition.xz - vworldNormal[0].xz * 0.001) - cameraPosition.xz);

    bool OutsideCube = max(cubeDistance0, max(cubeDistance1, cubeDistance2)) >= 1.0;
    bool InsideCube = cubeDistanceA < 0.5;
    bool isWater = tileID == 8 || tileID == 9;

    vec3 netherFogColor = vec3(0.0);
    vec3 sanstormColor = vec3(0.0);

    vec3 fogcolor = vec3(0.0);
    if(tileID == 7) fogcolor = netherFogColor;
    if(tileID == 12) fogcolor = sanstormColor;

    float waterfog = isWater ? 1.0 : 0.0;

    float temperature = 0.5;
    if(tileID == 78 || tileID == 80 || tileID == 79 || tileID == 174) temperature = 0.0;
    if(tileID == 2) temperature = 0.8;
    if(tileID == 18) temperature = 0.7;
    if(tileID == 12) temperature = 1.0;

    float rainfall = 0.;
    if(isWater) rainfall = 1.0;
    if(tileID == 2) rainfall = 0.7;
    if(tileID == 18) rainfall = 0.8;
    if(tileID == 12 || tileID == 172.0 || tileID == 159) rainfall = 0.0;

    if((tileID > 0 && !OutsideCube && !InsideCube) || isWater) {  
    for(int i = 0; i < 3; i++) {
        gl_Position.xy = (mappingToTexel - offset[vertexID[i]] * 0.5 + 0.5) * shadowTexelSize * 2.0;
        gl_Position.z = (1.0 - (worldPosition[i].y + cameraPosition.y + 65.0) / 384.0) * 2.0 - 1.0;
        gl_Position.w = 1.0;

        isTerrainMap = 1.0;
        terrainData.r = rainfall;
        terrainData.g = temperature;
        terrainData.b = gl_Position.z * 0.5 + 0.5;

        texcoord = vtexcoord[i];

        color = vec4(fogcolor, 1.0);

        EmitVertex();
    } EndPrimitive();    
    }else{
        gl_Position = vec4(-1.0);
        EmitVertex();
        gl_Position = vec4(-1.0);
        EmitVertex();
        gl_Position = vec4(-1.0);
        EmitVertex();
        EndPrimitive();  
    }
}
