#version 130


const int shadowMapResolution = 2048;
const float shadowDistance = 128.0;

float shadowTexelSize = 1.0 / float(shadowMapResolution);

const int noiseTextureResolution = 64;
float noiseTexelSize = 1.0 / float(noiseTextureResolution);

/*

const float shadowIntervalSize = 2.0;
const bool shadowcolor0Nearest = true;
const bool shadowcolor1Nearest = true;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;

const float ambientOcclusionLevel = 0.0;
*/
const float sunPathRotation = -35.0;

uniform sampler2D gcolor;

uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler2D shadowtex0;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform sampler2D noisetex;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

in vec2 texcoord;

const float Pi = 3.14159265;

vec4 nvec4(in vec3 x) {
    return vec4(x, 1.0);
}

vec3 nvec3(in vec4 x) {
    return x.xyz / x.w;
}

float IntersectPlane(vec3 origin, vec3 direction, vec3 point, vec3 normal) {
    return dot(point - origin, normal) / dot(direction, normal);
}

float R2sq(in vec2 coord) {
  float a1 = 1.0 / 0.75487766624669276;
  float a2 = 1.0 / 0.569840290998;

  return fract(coord.x * a1 + coord.y * a2);
}   

float hash(in vec2 p) { // replace this by something better
    p  = 50.0*fract( p*0.3183099 + vec2(0.71,0.113));
    return -1.0+2.0*fract( p.x*p.y*(p.x+p.y) );
}

float hash(in vec3 p) { // replace this by something better
    p  = fract( p*0.3183099+.1 );
	p *= 17.0;
    return fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
}

float noise(in vec2 x){
    return texture(noisetex, x / noiseTextureResolution).x;
}

float noise(in vec3 x) {
    x = x.xzy;

    vec3 i = floor(x);
    vec3 f = fract(x);

	f = f*f*(3.0-2.0*f);

	vec2 uv = (i.xy + i.z * vec2(17.0)) + f.xy;
    uv += 0.5;

	vec2 rg = vec2(noise(uv), noise(uv+17.0));

	return mix(rg.x, rg.y, f.z);
}

void main() {
    vec3 color = texture(gcolor, texcoord).rgb;

    vec3 fragCoord = vec3(texcoord, texture(depthtex0, texcoord).x);
    vec3 viewPosition = nvec3(gbufferProjectionInverse * nvec4(fragCoord * 2.0 - 1.0));
    vec3 worldPosition = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;

    vec3 shadowCoord = mat3(shadowModelView) * worldPosition + shadowModelView[3].xyz;
         shadowCoord = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowCoord + shadowProjection[3].xyz;
         shadowCoord = shadowCoord * 0.5 + 0.5;
         shadowCoord.xy = clamp(shadowCoord.xy, shadowTexelSize, 1.0 - shadowTexelSize);

    vec3 sigma_a = vec3(0.0001);
    vec3 sigma_s = vec3(0.003);
    vec3 sigma_t = sigma_a + sigma_s;

    color = pow(color, vec3(2.2));

    vec3 direction = normalize(worldPosition);

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    float stepLength = 12.0;

    float dither = R2sq(texcoord * vec2(viewWidth, viewHeight));
    float dither2 = R2sq((1.0 - texcoord) * vec2(viewWidth, viewHeight));

    vec3 rayOrigin = direction * stepLength * (1.0 - dither);

    float CosTheta = sqrt((1 - dither) / ( 1 + (0.999 - 1) * dither));
	float SinTheta = sqrt(1 - CosTheta * CosTheta);

    for(int i = 0; i < 16; i++) {
        vec3 position = rayOrigin + direction * (stepLength * float(i));
        float current = length(position);
        vec3 currentWorldPosition = position + cameraPosition;

        if(current > length(worldPosition)) break;

        float H = position.y + cameraPosition.y;

        float t = max(0.0, IntersectPlane(vec3(0.0), direction, vec3(0.0, position.y, 0.0), vec3(0.0, 1.0, 0.0)));

        vec2 terrainCoord = ((floor(direction.xz * t + cameraPosition.xz) - cameraPosition.xz) * shadowTexelSize * 2.0) * 0.5 + 0.5;
/*
        float rainfall = texture(shadowcolor1, terrainCoord).r;
              rainfall *= clamp(1.0 - abs((H + 65.0) - terrainHeight) * 0.05, 0.0, 1.0);
*/
        float rainfall = 0.0;

        //for(float ii = -1.0; ii <= 1.0; ii += 1.0) {
        //    for(float ij = -1.0; ij <= 1.0; ij += 1.0) {
        //        rainfall += texture(shadowcolor1, terrainCoord + vec2(ii, ij) * shadowTexelSize).r;
        //    }
        //}

        
        vec3 randomDirection = vec3(0.0);
        randomDirection.x = hash(round(currentWorldPosition.yz));
        randomDirection.z = hash(round(currentWorldPosition.xy));
        //randomDirection.y = 1.0 - sqrt(dot(randomDirection.xz, randomDirection.xz));

        for(int j = 0; j < 3; j++){
            float dist = exp2(float(j));
            vec2 coord = terrainCoord + round(randomDirection.xz * dist) * shadowTexelSize;
            float terrainHeight = (1.0 - texture(shadowtex0, coord).x) * 384.0;
            float terrainRainFall = texture(shadowcolor1, coord).r;
            rainfall += terrainRainFall * terrainRainFall * clamp(1.0 - abs((H + 65.0) - terrainHeight) * 0.05, 0.0, 1.0) / dist;
        }

        rainfall /= (1.0 + 0.5, 0.25);

        float density = (noise(currentWorldPosition * 0.1) + noise(currentWorldPosition * 0.2) * 0.5 + noise(currentWorldPosition * 0.4) * 0.25) / (1.0 + 0.5 + 0.25);
              density = clamp((density - 0.3) / (1.0 - 0.3), 0.0, 1.0);
              density *= exp(-max(0.0, H - 63.0) / 20.0);

        vec3 T = sigma_t * (density * rainfall);

        vec3 alpha = exp(-stepLength * T);

        color *= alpha;
        scattering += (vec3(1.0) - alpha) * transmittance / max(vec3(1e-5), T) * density * rainfall;
        //scattering += transmittance * density * rainfall * stepLength;
    }

    color += scattering * sigma_s;

    //color = vec3(step(shadowCoord.z - shadowTexelSize, texture(shadowtex0, shadowCoord.xy).x)) * color;

    //color = mix(color, texture(shadowcolor0, vec2(0.5)).rgb, 0.9);
/*
    vec3 randomDirection = vec3(cos(dither2 * 2.0 * Pi), 0.0, sin(dither2 * 2.0 * Pi)) / length(viewPosition) * 8.0;

    randomDirection = normalize(randomDirection + direction);

    float t = max(0.0, IntersectPlane(vec3(0.0), randomDirection, vec3(0.0, worldPosition.y, 0.0), vec3(0.0, 1.0, 0.0)));

    color = mix(color * 0.0, texture(shadowcolor1, ((floor(randomDirection.xz * t + cameraPosition.xz) - cameraPosition.xz) * shadowTexelSize * 2.0) * 0.5 + 0.5).rrr, 0.9);
*/

    //vec3 randomDirection = abs(vec3(hash(floor(worldPosition.zx + cameraPosition.zx)), 0.0, hash(floor(worldPosition.xz + cameraPosition.xz))));
    //color = randomDirection;

    color = pow(color, vec3(1.0 / 2.2));

    gl_FragColor = vec4(color, 1.0);
}