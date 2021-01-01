Shader "OnScreenEffect/InterlaceCRTEffect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Distortion("Distortion - Main Parameter", Range (-.25, .75)) = 0.1
        _Distortion2("Distortion - Secondary Parameter", Float) = 0  
        //_TangentDistortion("TangentDistortion", Range (-.25, .75)) = 0.1
        //_TangentDistortion2("TangentDistortion2", Float) = 0  
        _NoiseWeight("NoiseWeight", Range(0,1)) = 0.5
        _LuminanceCorrectionFactor("_LuminanceCorrectionFactor", Range(0,1)) = 0.5
        
        u_green_offset("Green Color Offset", Range(-0.007,0.007)) = 0.15
        u_red_offset("Red Color Offset", Range(-0.007,0.007)) = 0.15
        u_blue_offset("Blue Color Offset", Range(-0.007,0.007)) = 0.15
        
        _ScanlineWidth("ScanlineWidth", Float) = 0  
        _ScanlineNumbers("Number of Lines", Float) = 0  
        
        _NoiseStrokesMax("Noise Stroikes Max Thickness", Range(0,0.001)) = 0.000178
        _NoiseStrokesMin("Noise Stroikes Min Thickness", Range(0,0.0002)) = 0.0001
        
        _BorderMinBound("Black Border Start", Range(0,1)) = 0.95
        _BorderMaxBound("Black Border End", Range(0,1)) = 1
        
        _VigneteRadius("Vignete Radius", Range(0,1)) = 0.707
        
        
        //_ScanlinePhase("Scanline phase", Float) = 0  //Use this to animate the interalacing effect 
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            
            uniform float2 _InputSize;
            uniform float2 _OutputSize;
            uniform float2 _TextureSize;
            uniform float2 _One;
            uniform float _BorderMinBound;
            uniform float _BorderMaxBound;
            uniform float _VigneteRadius;
            uniform float _NoiseStrokesMax;
            uniform float _NoiseStrokesMin;
            uniform float _Distortion,_Distortion2, _TangentDistortion, _TangentDistortion2;
            uniform float _ScanlineWidth, _ScanlineNumbers, _ScanlinePhase, _LuminanceCorrectionFactor, _PollockPaint;
            uniform float _NoiseWeight, _frameCount;
            uniform float u_green_offset, u_red_offset, u_blue_offset;
            
            float2 bcDistortion(float2 coord){
            
                coord = coord * 2 - 1.0;
                
                float r2 =  coord.x * coord.x + coord.y * coord.y;
                coord *= 1.0 + _Distortion * r2 + _Distortion2 * r2 * r2;
                
                //potential tangential terms can go here -- UNUSED, did not seem useful to intended effect
                //coord.x += (2 * _TangentDistortion * coord.x * coord.y + _TangentDistortion2 * (r2 * r2 + 2 * coord.x * coord.x));
                //coord.y += (2 * _TangentDistortion2 * coord.x * coord.y + _TangentDistortion * (r2 * r2 + 2 * coord.y * coord.y));  
                coord = (coord * .5 + .5);
                return coord; 
            }
            
            float hash1(float2 p2, float p) {
                float3 p3 = frac(float3(5.3983 * p2.x, 5.4427 * p2.y, 6.9371 * p));
                p3 += dot(p3, p3.yzx + 19.19);
                return frac((p3.x + p3.y) * p3.z);
            }
            
            float noise1(float2 p2, float p) {
                float2 i = floor(p2);
                float2 f = frac(p2);
                float2 u = f * f * (3.0 - 2.0 * f);
                return 1.0 - 2.0 * lerp(lerp(hash1(i + float2(0.0, 0.0), p), 
                                           hash1(i + float2(1.0, 0.0), p), u.x),
                                       lerp(hash1(i + float2(0.0, 1.0), p), 
                                           hash1(i + float2(1.0, 1.0), p), u.x), u.y);
            }
            
            float rand(half2 co)
            {
                return frac((sin( dot(co.xy , float2(12.345 * _Time.w, 67.890 * _Time.w) )) * 12345.67890+_Time.w));
            }
            
            float luminanceCalc( fixed4 col){
                return  0.299 * col.x + 0.587 * col.y + 0.114 * col.z;
            }
            
            uniform float2x2 m = float2x2 (1.616, 1.212, -1.212, 1.616);
            
            float fbm1(float2 p2, float p) {
                float f = noise1(p2, p); 
                p2 = mul(m,p2);
                f += 0.5 * noise1(p2, p); 
                p2 = mul(m,p2);
                f += 0.25 * noise1(p2, p); 
                p2 = mul(m,p2);
                f += 0.125 * noise1(p2, p); 
                p2 = mul(m,p2);
                f += 0.0625 * noise1(p2, p); 
                p2 = mul(m,p2);
                f += 0.03125  * noise1(p2, p);
                return f / 1.96875 ;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //declarations
                
                half2 center = 0.5;
                //coordinate transform
                float4 screenPos = ComputeScreenPos(i.vertex);
                half2 coords = bcDistortion(i.uv);
                //correct coordinates for scaling 
                float scale = 1./ (_Distortion + 1.);    
                coords = coords * scale - (scale * .5) + .5;
                
                fixed4 col = tex2D(_MainTex, coords);
                col.g = tex2D(_MainTex, coords + u_green_offset).g;
                col.r = tex2D(_MainTex, coords + u_red_offset).r;
                col.b = tex2D(_MainTex, coords + u_blue_offset).b;
                // noise
                _ScanlinePhase += _Time.w;
                float luminance = luminanceCalc(col);
                float bAlpha =  1 * sin((_Time.x + coords.y * _ScanlineWidth )* _ScanlineNumbers + _ScanlinePhase);
                bAlpha = sign(bAlpha) * step(0.4, abs(bAlpha));
                //create pollock like strokes as noise 
                fixed4 col2 = fixed4(0,0,0,0);
                col2= lerp(col, 0.1 , smoothstep(_NoiseStrokesMax, _NoiseStrokesMin, abs(fbm1(coords + _frameCount * 0.8 , 0.5))) );
                //blend noises
                col *= ((1-_NoiseWeight) * (bAlpha) + (rand(coords) * _NoiseWeight)); 
                //correct pixel luminance
                col += (luminance - luminanceCalc(col)) * _LuminanceCorrectionFactor;
                //add pollock like line noise
                col *= col2; 
                
                
                //borders
                half2 coords2 = abs(coords * 2 - 1);
                half2 border = 1 - smoothstep(_BorderMinBound, _BorderMaxBound, coords2);
                col *= lerp(.2, 1., border.x * border.y);

                // Vigneting
                float vigneteRange = clamp(_Distortion, 0., 0.2);
                float distanceFromCenter = distance(coords, center); 
                float dist = (distanceFromCenter - (_VigneteRadius - vigneteRange))/ vigneteRange;
                col *= smoothstep(1, 0, dist);
                
                return col;
            }
            ENDCG
        }
    }
}
