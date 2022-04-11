Shader "Unlit/GlassWater"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Size("Size", Float) = 1
        _Distortion("Distortion", Range(0, 2)) = 1
        _Blur ("Blur", range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Transparent"}
        
        GrabPass{"_GrabTexture"}

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 grabUV : TEXCOORD1;
            };

            sampler2D _MainTex;
            sampler2D _GrabTexture;
            float4 _MainTex_ST;
            float _Size;
            float _Distortion;
            float _Blur;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.grabUV = UNITY_PROJ_COORD(ComputeGrabScreenPos(o.vertex)); // 使用ComputeGrabScreenPos计算屏幕坐标，因为grab涉及平台不同产生的图片翻转问题，此函数进行了相应的处理，UNITY_PROJ_COORD也是用于跨平台问题，大部分情况输入就是输出
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            // 噪声函数
            float Noise(float2 p)
            {
                p = frac(p * float2(123.57, 345.45));
                p += dot(p, p + 34.345);
                return frac(p.x * p.y);
            }

            // 提取出的计算水滴的部分
            float3 GetDrop(float2 UV, float t)
            {
                float2 aspect = float2(2, 1);
                float2 uv = UV * _Size * aspect;

                uv.y += t * 0.25;                                       // 控制uv移动配合水滴下落
                float2 gv = frac(uv) - 0.5;                             // frac (值：x - floor(x)）  gv范围 -0.5 - 0.5， gv即相对中心点的向量
                float2 id = floor(uv);                                  // 每格uv的位置
                float n = Noise(id);                                    // n 范围 0-1
                t += n * 5.345;                                         // 使每格的时间都不相同

                float w = UV.y * 10;                                  // x使用i.uv控制，因此x位置是相对固定的，与时间无关，只与i.uv.y有关
                float x = (n - 0.5) * 0.8;                              // x 随机化， -0.4 - 0.4
                float y = -sin(t + sin(t + sin(t) * 0.5)) * 0.45;       // -0.45 - 0.45

                x += (0.4 - abs(x)) * sin(3 * w) * pow(sin(w), 6) * 0.45;   // 控制水滴水平移动，0.4 - abs(x)是为了越靠近两端水平移动效果越弱
                y -= (gv.x - x) * (gv.x - x);                           // 可以理解为： gv.x - x 是当前x位置相对于此时的水滴x，t = gv.x - x, t^2 就是以 x 为水平轴原点的凹曲线，-t^2将曲线进行翻转，y += (-)t^2，通过此操作使水滴的形状发生改变，不再是纯圆形，更类似💧这个形状

                float2 dropPos = (gv - float2(x, y)) / aspect;          // 值为 uv 相对于 圆心（x + 0.5, y + 0.5） 的向量， 除aspect椭圆变正圆
                float drop = smoothstep(0.05, 0.03, length(dropPos));   // 小于0.03 为1， 大于0.05 为0， 中间平滑过渡， 圆大小0.03 - 0.05逐渐透明

                float2 dropTrailPos = (gv - float2(x, t * 0.25)) / aspect;     // 创建拖尾水滴
                dropTrailPos.y = (frac(dropTrailPos.y * 8) / 8) - 0.03; // 生成多个水滴，生成的是半圆，因为是到 最低边中点为圆心 的距离，所以减0.03就是底边加0.03为圆心
                float dropTrail = smoothstep(0.03, 0.02, length(dropTrailPos));
                float fogTrail = smoothstep(-0.05, 0.05, dropPos.y);    // 控制拖尾只显示在水滴上方，y值等于uv.y - 圆心的y，即相对圆心的距离，圆半径0.05，小于-0.05说明这个位置在圆下方
                fogTrail *= smoothstep(0.5, y, gv.y);                   // 控制拖尾颜色越靠上越透明，gv.y值等于uv.y - 中心点的y，最大为0.5，小于y，输出1，大于0.5，即y最大值，输出0，保证从水滴往上逐渐变透明，y的值就是水滴相对中心点的值，从y往上就是从1 到 0
                dropTrail *= fogTrail;
                fogTrail *= smoothstep(0.05, 0.04, abs(dropPos.x));     // 划痕（水滴后方的透明痕迹）跟水滴x方向移动有关，abs(dropPos.x) 即越靠近水滴x位置划痕越明显
                float2 offs = drop * dropPos + dropTrail * dropTrailPos;// 通过偏移值使采样偏移，越远离水滴中心，偏移值越大
                return float3(offs, fogTrail);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float t = fmod(_Time.y, 7200);
                float4 col = 0;

                // 水滴，创建多层水滴，随意对uv进行移动
                float3 drops = GetDrop(i.uv, t);
                drops += GetDrop(i.uv * 1.24 + 4.34, t);
                drops += GetDrop(i.uv * 2.23 + 6.45, t);
                drops += GetDrop(i.uv * 1.45 + 2.43, t);

                float fade = 1 - saturate(fwidth(i.uv) * 50);   // fwidth 镜头越远值越大，fade值在镜头越靠近越大，水滴采样越清晰，镜头离的远了，整体就会模糊，从而不会出现闪烁的情况（因为设置水滴大小时是固定像素大小，不会因为镜头远近变化）
                float blur = _Blur * 7 * (1 - drops.z * fade);   // 实现划痕处采样高分辨率，其它低分辨率，且镜头越远，fade趋近0，就都是低分辨率变模糊了
                
                float2 projUV = i.grabUV.xy / i.grabUV.w;   // 获取0-1的uv值
                projUV += drops.xy * _Distortion * fade;    // 采样的uv进行扰动
                blur *= 0.01;                               // 影响uv偏移的数值，因此不能太大
                const float numSamples = 32;    // 模拟lod的采样次数
                float a = Noise(i.uv) * 6.28345;// 以圆形采样周围像素，每个像素做随机化，得到a就是随机化的初始角度
                //模拟lod采样(进行模糊)
                for (float i = 0; i < numSamples; i++)
                {
                    float2 offs = float2(sin(a), cos(a)) * blur;
                    float d = frac(sin((i + 1) * 546) * 2345);  // 角度在做一次随机化，使得圆形的采样角度随机化，不是连续的角度
                    d = sqrt(d);        // 此步会使模糊效果更好
                    offs *= d;
                    col += tex2D(_GrabTexture, projUV + offs);
                    a++;
                }
                col /= numSamples;
                return col;
            }
            ENDCG
        }
    }
}
