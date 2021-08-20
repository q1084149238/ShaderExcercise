Shader "GameEffect/ToonShading/CelRender"
{
    Properties
    {
        _MainColor ("MainColor", Color) = (1, 1, 1, 1)
        _MainTex ("MainTex", 2D) = "white" {}
        _ShadowColor("ShadowColor", Color) = (0.7, 0.7, 0.8, 1)
        _ShadowRange("ShadowRange", Range(0, 1)) = 0.5
        _ShadowSmooth("ShadowSmooth", Range(0, 0.2)) = 0.2

        [space(10)]
        _OutlineColor("OutlineColor", Color) = (0.5, 0.5, 0.5, 1)
        _OutlineWidth("OutlineWidth", Range(0.01, 1)) = 0.25
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
        }
        pass
        {
           Tags {"LightMode"="ForwardBase"}
			 
            Cull Back
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _MainTex; 
            float4 _MainTex_ST;
            half3 _MainColor;
            half3 _ShadowColor;
            half _ShadowRange;
            half _ShadowSmooth;

            struct a2v 
            {
                    float4 vertex : POSITION;
                    float3 normal : NORMAL;
                    float2 uv : TEXCOORD0;
                };

            struct v2f
            {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                    float3 worldNormal : TEXCOORD1;
            float3 worldPos : TEXCOORD2; 
            };


            v2f vert(a2v v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            half4 frag(v2f i) : SV_TARGET 
            {
                half4 col = 1;
                half4 mainTex = tex2D(_MainTex, i.uv);
                //视角方向
                // half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                half3 worldNormal = normalize(i.worldNormal);
                half3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                /*根据兰伯特定律依靠顶点的法线方向和光照方向计算顶点受光程度，
                因为dot的计算结果范围为（-1, 1）所以通过计算将区间固定在（0, 1）*/
                half halfLambert = dot(worldNormal, worldLightDir) * 0.5 + 0.5;
                //双色阶，大于阈值叠加亮面色调，否则叠加暗面色调。
                // half3 diffuse = halfLambert > _ShadowRange ? _MainColor : _ShadowColor;
                /*使用smoothstep函数实现这个效果。这个函数可以在根据输入数据，
                计算一个范围在0到1区间的平滑过渡曲线。通过这个函数的结果对明面和暗面的颜色进行插值，
                来实现明暗边界的软硬控制*/
                half ramp = smoothstep(0, _ShadowSmooth, halfLambert - _ShadowRange);
                half3 diffuse = lerp(_ShadowColor, _MainColor, ramp);

                diffuse *= mainTex;
                col.rgb = _LightColor0 * diffuse;
                return col;
            }
                ENDCG
            }

        // 描边
        pass
        {
            Tags
            {
                "LightMode"="ForwardBase"
            }

            Cull Front

            CGPROGRAM
            #pragma vertex Vertex
            #pragma fragment Pixel
            #include "UnityCG.cginc"

            half4 _OutlineColor;
            half _OutlineWidth;

            struct vertexOutput
            {
                float4 pos: SV_POSITION;
            };

            vertexOutput Vertex(appdata_base v)
            {
                vertexOutput o;
                
                float4 pos = UnityObjectToClipPos(v.vertex);
                float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal.xyz);
                viewNormal = normalize(TransformViewToProjection(viewNormal.xyz));

                /*因为NDC空间的xy是范围是[0,1]。但是我这里的窗口分辨率是16：9，
                所以直接用NDC空间的距离外扩，不能适配宽屏窗口。所以需要根据窗口
                的宽高比再进行修正。这里再对描边进行修改*/
                //将近裁剪面右上角位置的顶点变换到观察空间
                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));
                //计算屏幕宽高比
                float aspect = abs(nearUpperRight.x / nearUpperRight.y);
                //求出宽高比根据宽高比对x或者y进行修正，使其与另一坐标比例相等。
                viewNormal.y *= aspect;
                
                /*轮廓线宽度乘以w值，在渲染管线的后续计算中会将剪
                裁空间中的坐标除以w转换为ndc空间坐标，这样两个w互相抵消，
                就能得到ndc空间中的固定宽度的轮廓线*/
                pos.xy += 0.01 * _OutlineWidth * viewNormal.xy * pos.w;
                o.pos = pos;

                return o;
            }

            half4 Pixel(vertexOutput i): SV_TARGET
            {
                return _OutlineColor;
            }

            ENDCG
        }
        //描边End
    }
    FallBack "Diffuse"
}
  