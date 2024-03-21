Shader "Procedural/S_GrassField"
{
    Properties
    {
        [KeywordEnum(Off,MainWave,DetailedWave,ChunkID,LOD,ClumpCell,GlobalWind)] _Debug("DebugMode", Float) = 0

        _MainTex ("Texture", 2D) = "white" {}
        _Scale("Scale", Range(0,1)) = 1
        _Bend("Bend", Range(0,1)) = 0
        _RandomBendOffset("RandomBendOffset", Range(0,1)) = 0
        _TopColor("TopColor", Color) = (1,1,1,1)
        _BotColor("BotColor", Color) = (0,0,0,1)
        [Toggle(_USE_MAINWAVE_ON)]_USE_MAINWAVE_ON("Use_Main_Wave", Float) = 1
        _WindSpeed("WindSpeed", Range(0,1)) = 0.5
        _WindFrequency("WindFrequency", Range(0,1)) = 0.5
        _WindDirection("WindDirection", Range(0,360)) = 0
        _WindAmplitude("WindAmplitude", Range(0,1)) = 0.5
        _WindNoiseFrequency("WindNoiseFrequency", Range(0,1)) = 0.5
        _WindNoiseAmplitude("WindNoiseAmplitude", Range(0,1)) = 0.5
        [Toggle(_USE_DETAIL_ON)]_USE_DETAIL_ON("Use_Detail_Wave", Float) = 1
        _DetailSpeed("DetailSpeed", Range(0,1)) = 0.5
        _DetailFrequency("DetailFrequency", Range(0,1)) = 0.5
        _DetailAmplitude("DetailAmplitude", Range(0,1)) = 0.5
        [Toggle(_USE_RANDOM_HEIGHT_ON)]_USE_RANDOM_HEIGHT_ON("Use_Random_Height", Float) = 1
        _HeightRandomnessAmplitude("RandomHeightAmplitude", Range(0,1)) = 0.5

        _Tilt("GrassTilt",Float) = 1
        _Height("GrassHeight",Float) = 1
        _Bend("GrassBend",Range(-1,1)) = 0
         _GrassWaveAmplitude("GrassWaveAmplitude",Range(0,1)) = 0.1
         _GrassWaveFrequency("GrassWaveFrequency",Range(0,1)) = 0.1
         _GrassWaveSpeed("GrassWaveSpeed",Range(0,1)) = 0.1


        _BladeThickenFactor("BladeThickenFactor",Range(0,1)) = 0



    }
    SubShader
    {
        Tags {"RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"}
        Pass 
        {
            Name "ForwardLit"
            Tags {"LightMode" = "UniversalForward"}
            Cull off
            HLSLPROGRAM
            #pragma target 5.0

            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _ _USE_MAINWAVE_ON
            #pragma shader_feature _ _USE_DETAIL_ON
            #pragma shader_feature _ _USE_RANDOM_HEIGHT_ON
            #pragma shader_feature _DEBUG_OFF _DEBUG_MAINWAVE _DEBUG_DETAILEDWAVE _DEBUG_CHUNKID _DEBUG_LOD _DEBUG_CLUMPCELL _DEBUG_GLOBALWIND
            
            #include "HL_GrassField.hlsl"
            
            ENDHLSL
        }
    }
}
