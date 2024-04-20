#ifndef GRASSFIELD_GRAPHIC_INCLUDE
#define GRASSFIELD_GRAPHIC_INCLUDE
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "../INCLUDE/HL_GraphicsHelper.hlsl"
#include "../INCLUDE/HL_Noise.hlsl"
#include "../INCLUDE/HL_ShadowHelper.hlsl"

struct VertexInput
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    
};
struct VertexOutput
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float3 groundNormalWS : TEXCOOR2;
    float3 tangentWS : TEXCOORD3;
    float3 positionWS : TEXCOORD4;
    float4 clumpInfo : TEXCOORD5;
    float4 debug : TEXCOOR6;
    float height : TEXCOOR7;
    float3 bakedGI : TEXCOORD8;
};
////////////////////////////////////////////////
// Spawn Data
struct SpawnData
{
    float3 positionWS;
    float hash;
    float4 clumpInfo;
};
StructuredBuffer<SpawnData> _SpawnBuffer;
////////////////////////////////////////////////

////////////////////////////////////////////////
// Field Data
StructuredBuffer<float3> _GroundNormalBuffer;
StructuredBuffer<float2> _WindBuffer;
Texture2D<float> _InteractionTexture;
int _NumTilePerClusterSide;
float _ClusterBotLeftX, _ClusterBotLeftY, _TileSize;
////////////////////////////////////////////////

////////////////////////////////////////////////
// Debug
float3 _ChunkColor, _LOD_Color;
////////////////////////////////////////////////

float4 _TopColor, _BotColor, _VariantTopColor, _SpecularColor;
TEXTURE2D( _MainTex);SAMPLER (sampler_MainTex);float4 _MainTex_ST;
TEXTURE2D( _Normal);SAMPLER (sampler_Normal);float4 _Normal_ST;
float _GrassScale, _GrassRandomLength,
_GrassTilt, _GrassHeight, _GrassBend, _GrassWaveAmplitude, _GrassWaveFrequency, _GrassWaveSpeed,
_ClumpEmergeFactor, _ClumpThreshold, _ClumpHeightOffset, _ClumpHeightMultiplier, _ClumpTopThreshold,
_GrassRandomFacing,
_SpecularTightness,
_NormalScale,
_BladeThickenFactor;

void CalculateGrassCurve(float t, float interaction,float wind, float hash, out float3 pos, out float3 tan)
{
    float lengthMult = 1 + _GrassRandomLength * frac(hash * 78.233);
    float waveAmplitudeMult = 1 - interaction;
    float offset = hash * 12.9898;
    float bendFactor = wind * 0.5 + 0.5;
    float tiltFactor = wind + interaction;
    // Maximum tilt angle
    tiltFactor *= -50;
    tiltFactor = max(-50, tiltFactor);
    float2 tiltHeight = float2(_GrassTilt, _GrassHeight) * lengthMult;
    tiltHeight = Rotate2D(tiltHeight, tiltFactor);

  
    float2 waveDir = normalize(tiltHeight);
    float propg = dot(waveDir, tiltHeight);
    float grassWave = 0;
    float freq = 5 * _GrassWaveFrequency;
    float amplitude = _GrassWaveAmplitude * waveAmplitudeMult * bendFactor ; 
    float speed = _Time.y * _GrassWaveSpeed * 10 ;
    [unroll]
    for (int i = 0; i < 3; i++)
    {

        grassWave += sin(t * freq - speed + offset) * amplitude * lengthMult;
        freq *= 1.2;
        amplitude *= 0.8;
        speed *= 1.4;
        offset *= 78.233;
    }
        
    float2 P3 = tiltHeight;
    float2 P2 = tiltHeight * 0.6 + normalize(float2(-tiltHeight.y, tiltHeight.x)) * (_GrassBend * 2 * frac((hash * 0.5 + 0.5) * 39.346) + bendFactor);
    P2 = float2(P2.x, P2.y) + normalize(float2(-P3.y, P3.x)) * grassWave * lengthMult;
    P3 = float2(P3.x, P3.y) + normalize(float2(-P3.y, P3.x)) * grassWave * 1.2* lengthMult;
    CubicBezierCurve_Tilt_Bend(float3(0, P2.y, P2.x), float3(0, P3.y, P3.x), t, pos, tan);
}


VertexOutput vert(VertexInput v, uint instanceID : SV_INSTANCEID)
{
    VertexOutput o;
    ////////////////////////////////////////////////
    // Fetch Input
    float3 spawnPosWS = _SpawnBuffer[instanceID].positionWS;
    
    int x = (spawnPosWS.x - _ClusterBotLeftX) / _TileSize;
    int y = (spawnPosWS.z - _ClusterBotLeftY) / _TileSize;
    // Sample Buffers Based on xy
    float3 groundNormalWS = _GroundNormalBuffer[x * _NumTilePerClusterSide + y];
    float windStrength = _WindBuffer[x * _NumTilePerClusterSide + y].x; // [-1,1]
    float windDir = _WindBuffer[x * _NumTilePerClusterSide + y].y * 360; // [0,360]
    float interaction = saturate(_InteractionTexture[int2(x, y)]);
    
    float2 uv = TRANSFORM_TEX(v.uv, _MainTex);
    float rand = _SpawnBuffer[instanceID].hash * 2 - 1; // [-1,1]
    float3 clumpCenter = float3(_SpawnBuffer[instanceID].clumpInfo.x, 0, _SpawnBuffer[instanceID].clumpInfo.y);
    float2 dirToClump = normalize((spawnPosWS).xz - _SpawnBuffer[instanceID].clumpInfo.xy);
    float distToClump = _SpawnBuffer[instanceID].clumpInfo.z;
    float clumpHash = _SpawnBuffer[instanceID].clumpInfo.w; // [0,1]
    float3 posOS = v.positionOS;
    float viewDist = length(_WorldSpaceCameraPos - spawnPosWS);
    float nearGrass = 20;
    float farGrass = 120;
    float mask = 1 - smoothstep(nearGrass, farGrass, viewDist);
    ////////////////////////////////////////////////


    ////////////////////////////////////////////////
    // Apply Curve
    float3 curvePosOS = 0;
    float3 curveTangentOS = 0;
    float3 windAffectDegree = 45;
    CalculateGrassCurve(uv.y, interaction, windStrength * 0.55, rand, curvePosOS, curveTangentOS);
    float3 curveNormalOS = cross(float3(-1, 0, 0), normalize(curveTangentOS));
    posOS.yz = curvePosOS.yz;
    ////////////////////////////////////////////////
    
    
    ////////////////////////////////////////////////
    // Apply Transform
    float3 posWS = posOS * _GrassScale + spawnPosWS;
    float3 curvePosWS = curvePosOS * _GrassScale + spawnPosWS;
    ////////////////////////////////////////////////
    
    ////////////////////////////////////////////////
    // Apply Clump
    float windAngle = -windDir + 90;
    float clumpAngle = degrees(atan2(dirToClump.x, dirToClump.y)) * clumpHash * step(_ClumpThreshold, clumpHash);
    float randomRotationMaxSpan = 180;
    float reverseWind01 = 1 - (windStrength * 0.5  + 0.5);
    float rotAngle = lerp(windAngle, clumpAngle, mask * _ClumpEmergeFactor * reverseWind01) - (frac(rand * 12.9898) - 0.5) * randomRotationMaxSpan * _GrassRandomFacing * (reverseWind01+0.2);
    float scale = 1 + (_ClumpHeightOffset * 5 - distToClump) * _ClumpHeightMultiplier * clumpHash * step(_ClumpThreshold, clumpHash) * rand;
    posWS = ScaleWithCenter(posWS, scale, spawnPosWS);
    posWS = RotateAroundAxis(float4(posWS, 1), float3(0,1,0),rotAngle,spawnPosWS).xyz;
    curvePosWS = ScaleWithCenter(curvePosWS, scale, spawnPosWS);
    curvePosWS = RotateAroundAxis(float4(curvePosWS, 1), float3(0, 1, 0), rotAngle, spawnPosWS).xyz;
    float3 normalWS = normalize(RotateAroundYInDegrees(float4(curveNormalOS, 0), rotAngle).xyz);
    float3 tangentWS = normalize(RotateAroundYInDegrees(float4(curveTangentOS, 0), rotAngle).xyz);
    ////////////////////////////////////////////////
    
    
    ////////////////////////////////////////////////
    // Apply View Space Adjustment
    float offScreenFactor =  1 - abs(dot(normalWS, normalize(_WorldSpaceCameraPos - posWS)));
    float3 posVS = mul(UNITY_MATRIX_V, float4(posWS, 1)).xyz;
    float3 curvePosVS = mul(UNITY_MATRIX_V, float4(curvePosWS, 1)).xyz;
    float3 shiftDistVS = posVS - curvePosVS;
    float3 projectedShiftDistVS = normalize(ProjectOntoPlane(shiftDistVS, float3(0, 0, 1)));
    posVS.xy += length(posWS - curvePosWS) > 0.0001 ?
    projectedShiftDistVS.xy *  _BladeThickenFactor * 0.05 : 0;
    ////////////////////////////////////////////////

    ////////////////////////////////////////////////
    // GI
    float2 lightmapUV;
    OUTPUT_LIGHTMAP_UV(v.uv1, unity_LightmapST, lightmapUV);
    float3 vertexSH;
    OUTPUT_SH(normalWS, vertexSH);
    ////////////////////////////////////////////////

    o.bakedGI = SAMPLE_GI(lightmapUV, vertexSH, normalWS);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    o.positionWS = posWS;
    o.normalWS = normalWS;
    o.tangentWS = tangentWS;
    o.groundNormalWS = groundNormalWS;
    o.clumpInfo = _SpawnBuffer[instanceID].clumpInfo;
    o.debug = float4(lerp(float2(0, 1), float2(1, 0), windStrength + 0.5), interaction,rand);
    o.height = max(scale, _GrassRandomLength * rand) * clumpHash;
    #ifdef SHADOW_CASTER_PASS
        o.positionCS = CalculatePositionCSWithShadowCasterLogic(posWS,normalWS);
    #else
        o.positionCS = mul(UNITY_MATRIX_P, float4(posVS, 1));
    #endif
    return o;
   
}

struct CustomInputData
{
    float3 normalWS;
    float3 groundNormalWS;
    float3 positionWS;
    float3 viewDir;
    float viewDist;
    
    float3 albedo;
    float3 specularColor;
    float smoothness;
    
    float3 bakedGI;
    float4 shadowCoord;
};
float3 CustomLightHandling(CustomInputData d, Light l)
{
    // Shadow in Project Setting set to 30 meters
    float atten = lerp(l.shadowAttenuation, 1, smoothstep(20, 30, d.viewDist)) * l.distanceAttenuation;
    float3 radiance = l.color * atten;
    float diffuse = saturate(dot(l.direction, d.normalWS));
    float diffuseGround = saturate(dot(l.direction, d.groundNormalWS));
    float specularDot = saturate(dot(d.normalWS, normalize(l.direction + d.viewDir)));
    float specularDotGround = saturate(dot(d.groundNormalWS, normalize(l.direction + d.viewDir)));
    float specular = pow(specularDotGround * 0.4 + specularDot * 0.6, d.smoothness) * diffuse;
    float3 phong = saturate ((diffuseGround * 0.5 + diffuse * 0.5) * d.albedo + specular * d.specularColor);
    return phong * radiance;
}
float3 CustomCombineLight(CustomInputData d)
{
    Light mainLight = GetMainLight(d.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, d.normalWS, d.bakedGI);
    float3 color = d.bakedGI * d.albedo;
    color += CustomLightHandling(d, mainLight);
    uint numAdditionalLights = GetAdditionalLightsCount();
    for (uint lightI = 0; lightI < numAdditionalLights; lightI++)
        color += CustomLightHandling(d, GetAdditionalLight(lightI, d.positionWS, d.shadowCoord));
    return color;
}

float4 frag(VertexOutput v, bool frontFace : SV_IsFrontFace) : SV_Target
{
#ifdef SHADOW_CASTER_PASS
    return 0;
#else
    float3 normalWS = normalize(v.normalWS);
    float3 tangentWS = normalize(v.tangentWS);
    float3 bitangentWS = cross(normalWS, tangentWS);
    float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal, sampler_Normal, v.uv), -_NormalScale);
    normalTS.xyz = normalTS.xzy;
    normalWS = normalize(
    normalTS.x * tangentWS +
    normalTS.y * normalWS +
    normalTS.z * bitangentWS);
    normalWS = frontFace ? normalWS : -normalWS;
    CustomInputData d = (CustomInputData) 0;
    d.normalWS = normalize(normalWS);
    d.groundNormalWS = normalize(v.groundNormalWS);
    d.positionWS = v.positionWS;
    d.shadowCoord = CalculateShadowCoord(v.positionWS, v.positionCS);
    d.viewDir = normalize(_WorldSpaceCameraPos - v.positionWS);
    d.viewDist = length(_WorldSpaceCameraPos - v.positionWS);
    d.smoothness = exp2(_SpecularTightness * 10 + 1);
    d.albedo = lerp(_BotColor, lerp(_TopColor, _VariantTopColor, saturate(v.height + _ClumpTopThreshold * 2 - 1)), v.uv.y).xyz;
    d.specularColor = _SpecularColor.xyz;
    d.bakedGI = v.bakedGI;

    float3 finalColor = CustomCombineLight(d) ;
#if _DEBUG_OFF
        return finalColor.xyzz;
#elif _DEBUG_CHUNKID
        return _ChunkColor.xyzz;
#elif _DEBUG_LOD
        return _LOD_Color.xyzz;
#elif _DEBUG_CLUMPCELL
        return v.clumpInfo.wwzz;
#elif _DEBUG_GLOBALWIND
        return float4 (v.debug.xy,0,0);
#elif _DEBUG_HASH
        return v.debug.wwww;
#elif _DEBUG_INTERACTION
        return v.debug.zzzz;
#else 
    return d.albedo.xyzz;
#endif
#endif
   
}
#endif