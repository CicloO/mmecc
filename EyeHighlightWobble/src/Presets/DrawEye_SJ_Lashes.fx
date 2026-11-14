// DrawEye_SJ by Sanjin. Eyelash variant for PostAlphaEye's EyeRT.
// Use on Face_Lashes only. Defaults match DrawEye_SJ_Alpha.fx.
static const float Speed = 2.0;
static const float Offset = 0.0;
static const float alpha = 0.5;

//Edit by Sanjin

float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 head_bone : CONTROLOBJECT < string name = "(self)"; string item = "“ª"; >;
float3 cameraDirection : DIRECTION < string Object = "Camera";> ;
float4 Diffuse : DIFFUSE < string Object = "Geometry";> ;

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT2
{
    float4 Pos        : POSITION;
    float2  Coord 		  : TEXCOORD0;
};

texture TexMap : MATERIALTEXTURE;
sampler TexMapSamp = sampler_state
{
	texture = <TexMap>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	MIPFILTER = LINEAR;
	ADDRESSU = WRAP;
	ADDRESSV = WRAP;
};


VS_OUTPUT2 Mask_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out = (VS_OUTPUT2)0;
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Coord = Tex;
    return Out;
}

float4 Mask_PS( VS_OUTPUT2 IN ) : COLOR0
{
    float3 head_foward = head_bone._31_32_33; 
    float4 Color = tex2D(TexMapSamp, IN.Coord);
    // Reject empty texture coverage before applying the camera fade.
    clip(Color.a * Diffuse.a - (1.0 / 255.0));
    float x = dot(head_foward, cameraDirection);
    x = saturate((x + Offset) * Speed);

    return float4(Color.rgb, Color.a * x * Diffuse.a * alpha);
}


technique MaskTec < string MMDPass = "object"; > {
    pass DrawObject {
        AlphaBlendEnable = true;
        // Keep the source blend factors, but discard the underlying EyeRT color and alpha.
        BlendOp = ADD;
        DestBlend = ZERO;
        BlendOpAlpha = ADD;
        DestBlendAlpha = ZERO;
        AlphaTestEnable = false;
        VertexShader = compile vs_2_0 Mask_VS();
        PixelShader  = compile ps_2_0 Mask_PS();
    }
}


technique MaskTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        AlphaBlendEnable = true;
        // Keep the source blend factors, but discard the underlying EyeRT color and alpha.
        BlendOp = ADD;
        DestBlend = ZERO;
        BlendOpAlpha = ADD;
        DestBlendAlpha = ZERO;
        AlphaTestEnable = false;
        VertexShader = compile vs_2_0 Mask_VS();
        PixelShader  = compile ps_2_0 Mask_PS();
    }
}
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTech < string MMDPass = "shadow";  > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
