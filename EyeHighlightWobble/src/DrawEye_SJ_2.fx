/* DrawEye_SJ_2.fx - 眼高光颤动 + 三金角度透明 (细密)
   眼睛高光颤动。参数由控制器 EyeHLWobbleCtrl.pmx 的表情调节（见 README.txt），
   下面 #define 为控制器全 0 时的默认值。
*/
#define HL_CONTROLLER "EyeHLWobbleCtrl.pmx"
#define HL_NOISE_FILE "Noise2.png"

// --- 整体晃动 (Wiggle) ---
#define HL_WIGGLE_POWER  0.030    // 整体位移的幅度
#define HL_WIGGLE_SPEED  1.5    // 整体位移的速度
// --- 边缘形变 (Tremble) ---
#define HL_TREMBLE_POWER 0.010    // 局部形变的幅度
#define HL_TREMBLE_SPEED 0.2    // 局部形变的速度
#define HL_NOISE_TILING  1.2    // 噪波在物体表面的缩放
// --- 防穿模 (Anti-Clipping) ---
#define HL_MAX_OFFSET    0.08    // 总位移上限(模型单位)，<=0 关闭
#define HL_DEPTH_BIAS    0.02    // 沿视线朝相机拉近的距离，防止被眼球/眼白遮住
#define HL_BLINK_DAMP    1.0     // 眨眼时抖动衰减，1=闭眼完全停止，0=不衰减
// --- 自发光 ---
#define HL_BRIGHTNESS    1.2

// --- 三金眼透：角度透明/消失 ---
#define HL_FADE_SPEED    1.5     // 消失速度
#define HL_FADE_OFFSET   0.0     // 消失起始点 [-1, 1]
#define HL_FADE_ALPHA    1.0     // 基础透明度

#include "EyeHLWobble.fxsub"

float HL_FadeSpdUp : CONTROLOBJECT < string name = HL_CONTROLLER; string item = "\x5B\x93\xA7\x5D\x8F\xC1\x91\xAC\x2B"; >;
float HL_FadeSpdDn : CONTROLOBJECT < string name = HL_CONTROLLER; string item = "\x5B\x93\xA7\x5D\x8F\xC1\x91\xAC\x2D"; >;
float HL_FadeOffUp : CONTROLOBJECT < string name = HL_CONTROLLER; string item = "\x5B\x93\xA7\x5D\x8B\x4E\x93\x5F\x2B"; >;
float HL_FadeOffDn : CONTROLOBJECT < string name = HL_CONTROLLER; string item = "\x5B\x93\xA7\x5D\x8B\x4E\x93\x5F\x2D"; >;
float HL_AlphaUp : CONTROLOBJECT < string name = HL_CONTROLLER; string item = "\x5B\x93\xA7\x5D\x93\xA7\x96\xBE\x2B"; >;
float HL_AlphaDn : CONTROLOBJECT < string name = HL_CONTROLLER; string item = "\x5B\x93\xA7\x5D\x93\xA7\x96\xBE\x2D"; >;
static float Speed  = HL_FADE_SPEED * HL_SCALE(HL_FadeSpdUp, HL_FadeSpdDn);
static float Offset = HL_FADE_OFFSET + HL_FadeOffUp - HL_FadeOffDn;
static float alpha  = saturate(HL_FADE_ALPHA + HL_AlphaUp - HL_AlphaDn);

// 头部骨骼朝向 (用于计算角度)
float4x4 head_bone : CONTROLOBJECT < string name = "(self)"; string item = "\x93\xAA"; >;
float3 cameraDirection : DIRECTION < string Object = "Camera"; >;
float4 MaterialDiffuse : DIFFUSE < string Object = "Geometry"; >;

texture TexMap : MATERIALTEXTURE;
sampler TexMapSamp = sampler_state {
    texture = <TexMap>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR;
    AddressU = WRAP; AddressV = WRAP;
};

float4 PS_Main(VS_OUTPUT In) : COLOR0 {
    float4 Color = tex2D(TexMapSamp, In.Tex);
    Color.rgb *= Brightness;

    float3 head_foward = head_bone._31_32_33;
    float x = dot(head_foward, cameraDirection);   // 面朝向与相机的夹角
    x = saturate((x + Offset) * Speed);            // 映射消失范围

    return float4(Color.rgb, Color.a * x * MaterialDiffuse.a * alpha);
}

// 普通模式
technique MaskTec < string MMDPass = "object"; > {
    pass DrawObject {
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        ZWriteEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Main();
    }
}

// 本影模式
technique MaskTecBS < string MMDPass = "object_ss"; > {
    pass DrawObject {
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        ZWriteEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Main();
    }
}

// 高光不投影、不描边
technique ShadowTech < string MMDPass = "shadow"; > { }
technique EdgeTec < string MMDPass = "edge"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }
