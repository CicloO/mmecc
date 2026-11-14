/* EyeHLWobble_2.fx - 眼高光颤动(细密：小幅快速)
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

#include "EyeHLWobble.fxsub"

texture2D ScnMap : MATERIALTEXTURE;
sampler2D ScnSamp = sampler_state {
    Texture = <ScnMap>;
    MinFilter = LINEAR; MagFilter = LINEAR;
    AddressU = CLAMP; AddressV = CLAMP;
};

float4 PS_Main(VS_OUTPUT In) : COLOR0 {
    float4 color = tex2D(ScnSamp, In.Tex);
    color.rgb *= Brightness;
    return color;
}

// 本影模式
technique MainTecSS < string MmdPass = "object_ss"; > {
    pass P0 {
        AlphaBlendEnable = TRUE;
        SrcBlend = SRCALPHA; DestBlend = INVSRCALPHA;
        ZWriteEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Main();
    }
}

// 普通模式
technique MainTec < string MmdPass = "object"; > {
    pass P0 {
        AlphaBlendEnable = TRUE;
        SrcBlend = SRCALPHA; DestBlend = INVSRCALPHA;
        ZWriteEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Main();
    }
}

// 兜底：不带 MmdPass 的默认 technique
technique DefaultTechnique {
    pass P0 {
        AlphaBlendEnable = TRUE;
        SrcBlend = SRCALPHA; DestBlend = INVSRCALPHA;
        ZWriteEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Main();
    }
}
