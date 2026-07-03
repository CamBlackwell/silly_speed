//
//  Water.metal
//
//  Mobile port of afl_ext's raymarched water (2017–2024, precision-hardened
//  variant), adapted from Shadertoy GLSL to a SwiftUI [[ stitchable ]]
//  colorEffect. Called as ShaderLibrary.waterEffect(...) from WaterShaderView
//  in ShaderEffects.swift.
//
//  Changes from the Shadertoy source, and why:
//
//  1. No mouse-driven camera rotation. `getRay()` in the original only
//     builds a rotation matrix above 600px width (a desktop/mouse branch);
//     there's no mouse on a phone, so that branch, its matrix multiply, and
//     `createRotationMatrixAxisAngle` are gone. Camera is fixed.
//
//  2. No wasted center sample. The original's `mainImage` renders one full
//     `mainImage0` pass into `color` labeled "center sample," then the
//     antialiasing loop immediately overwrites `color` before it's ever
//     added to `fragColor` — with MULTISAMPLING == 1 that first raymarch
//     is pure dead work, done on every pixel, every frame. Removed; this
//     file always renders exactly one sample per pixel.
//
//  3. Iteration counts and raymarch step count are uniforms, not #defines,
//     so WaterShaderView can hand it a cheaper tier under Low Power Mode —
//     same approach already used for the tunnel shader's maxSteps /
//     foldIterations.
//
//  4. `mod()` doesn't exist in MSL and Metal's `fmod` has different sign
//     behavior than GLSL's `mod` for negative inputs (which this shader
//     relies on for the drift-phase wrap). Reimplemented as `glslMod`.
//
//  5. Global mutable state (nTime, camDriftX in the original) doesn't
//     translate to MSL's per-thread execution model — threaded through as
//     explicit parameters instead.
//
//  Wave-precision behavior (the mod-wrapping of time/camera-drift phase
//  before it hits sin/cos) is preserved as-is: that's what keeps the
//  finite-difference normal stable at long runtimes, and it's cheap.
//

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Tunables that stay fixed regardless of quality tier.
// ---------------------------------------------------------------------------
constant float kDragMult      = 0.38;
constant float kWaterDepth    = 1.0;
constant float kCameraHeight  = 1.5;
constant float kTau           = 6.28318530718;

// GLSL-compatible mod: always takes the sign of y. Metal's fmod takes the
// sign of x, which breaks the phase-wrap trick for negative drift terms.
inline float glslMod(float x, float y) {
    return x - y * floor(x / y);
}

inline float2 wavedx(float2 position, float2 direction, float frequency, float timeshift) {
    float x = dot(direction, position) * frequency + timeshift;
    float wave = exp(sin(x) - 1.0);
    float dx = wave * cos(x);
    return float2(wave, -dx);
}

// iterations: octave count, quality-scaled (12 on desktop -> as low as 4-6 on phone).
inline float getwaves(float2 position, int iterations, float nTime, float camDriftX) {
    float wavePhaseShift = length(position) * 0.1;
    float iter = 0.0;
    float frequency = 1.0;
    float timeMultiplier = 2.0;
    float weight = 1.0;
    float sumOfValues = 0.0;
    float sumOfWeights = 0.0;

    for (int i = 0; i < iterations; i++) {
        float2 p = float2(sin(iter), cos(iter));

        // Phase terms wrapped independently before summing/entering sin/cos —
        // keeps the finite-difference normal precise at long runtimes.
        float tPhase = glslMod(nTime * timeMultiplier, kTau);
        float cPhase = glslMod(camDriftX * p.x * frequency, kTau);
        float phase  = tPhase + cPhase + wavePhaseShift;

        float2 res = wavedx(position, p, frequency, phase);

        position += p * res.y * weight * kDragMult;

        sumOfValues  += res.x * weight;
        sumOfWeights += weight;

        weight = mix(weight, 0.0, 0.2);
        frequency      *= 1.18;
        timeMultiplier *= 1.07;

        iter = glslMod(iter + 1232.399963, kTau);
    }
    return sumOfValues / sumOfWeights;
}

// steps: raymarch step budget, quality-scaled (64 on desktop -> ~20-24 on phone).
inline float raymarchwater(float3 camera, float3 start, float3 end, float depth,
                            int steps, int raymarchIterations, float nTime, float camDriftX) {
    float3 pos = start;
    float3 dir = normalize(end - start);
    for (int i = 0; i < steps; i++) {
        float height = getwaves(pos.xz, raymarchIterations, nTime, camDriftX) * depth - depth;
        if (height + 0.01 > pos.y) {
            return distance(pos, camera);
        }
        pos += dir * (pos.y - height);
    }
    return distance(start, camera);
}

inline float3 waterNormal(float2 pos, float e, float depth, int normalIterations,
                           float nTime, float camDriftX) {
    float2 ex = float2(e, 0.0);
    float H = getwaves(pos.xy, normalIterations, nTime, camDriftX) * depth;
    float3 a = float3(pos.x, H, pos.y);
    float3 b = float3(pos.x - e, getwaves(pos.xy - ex.xy, normalIterations, nTime, camDriftX) * depth, pos.y);
    float3 c = float3(pos.x,     getwaves(pos.xy + ex.yx, normalIterations, nTime, camDriftX) * depth, pos.y + e);
    return normalize(cross(a - b, a - c));
}

// Fixed camera, no mouse look — the desktop-only branch in the source is dropped.
//
// Note the uv.y flip: SwiftUI's colorEffect passes `position` with y=0 at
// the TOP of the view, increasing downward. The original Shadertoy source
// assumes OpenGL's convention (y=0 at the BOTTOM). Without this flip, sky
// (ray.y >= 0) renders at the bottom of the screen and water at the top —
// inverted from what it should be.
inline float3 getRay(float2 fragCoord, float2 resolution) {
    float2 uv = ((fragCoord / resolution) * 2.0 - 1.0) * float2(resolution.x / resolution.y, 1.0);
    uv.y = -uv.y - 0.3;
    return normalize(float3(uv.x, uv.y, 1.5));
}

inline float intersectPlane(float3 origin, float3 direction, float3 point, float3 normalVec) {
    return clamp(dot(point - origin, normalVec) / dot(direction, normalVec), -1.0, 9991999.0);
}

inline float3 extraCheapAtmosphere(float3 raydir, float3 sundir) {
    float specialTrick  = 1.0 / (raydir.y * 1.0 + 0.1);
    float specialTrick2 = 1.0 / (sundir.y * 11.0 + 1.0);
    float raysundt = pow(abs(dot(sundir, raydir)), 2.0);
    float sundt    = pow(max(0.0, dot(sundir, raydir)), 8.0);
    float mymie    = sundt * specialTrick * 0.2;
    float3 suncolor = mix(float3(1.0), max(float3(0.0), float3(1.0) - float3(5.5, 13.0, 22.4) / 22.4), specialTrick2);
    float3 bluesky  = float3(5.5, 13.0, 22.4) / 22.4 * suncolor;
    float3 bluesky2 = max(float3(0.0), bluesky - float3(5.5, 13.0, 22.4) * 0.002 * (specialTrick + -6.0 * sundir.y * sundir.y));
    bluesky2 *= specialTrick * (0.24 + raysundt * 0.24);
    return bluesky2 * (1.0 + 1.0 * pow(1.0 - raydir.y, 3.0)) + mymie * suncolor;
}

inline float3 getSunDirection(float nTime) {
    // The 0.2 multiplier in the original gives roughly a 31-second full
    // swing (sin period = 2π / 0.2) between near-horizon and near-zenith —
    // fast enough to read as visible bobbing. Slowed ~7x to a ~215-second
    // swing, closer to a slow ambient drift than a repeating bob. Push this
    // lower still (e.g. 0.01, ~10.5 min) for an even calmer sky, or back
    // toward 0.2 if you want the motion more noticeable.
    return normalize(float3(-0.0773502691896258,
                             0.5 + sin(glslMod(nTime * 0.029, kTau) + 2.6) * 0.45,
                             0.5773502691896258));
}

inline float3 getAtmosphere(float3 dir, float nTime) {
    return extraCheapAtmosphere(dir, getSunDirection(nTime)) * 0.5;
}

inline float getSun(float3 dir, float nTime) {
    return pow(max(0.0, dot(dir, getSunDirection(nTime))), 720.0) * 210.0;
}

inline float3 acesTonemap(float3 color) {
    float3x3 m1 = float3x3(0.59719, 0.07600, 0.02840,
                            0.35458, 0.90834, 0.13383,
                            0.04823, 0.01566, 0.83777);
    float3x3 m2 = float3x3(1.60475, -0.10208, -0.00327,
                            -0.53108, 1.10813, -0.07276,
                            -0.07367, -0.00605, 1.07602);
    float3 v = m1 * color;
    float3 a = v * (v + 0.0245786) - 0.000090537;
    float3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return pow(clamp(m2 * (a / b), 0.0, 1.0), float3(1.0 / 2.2));
}

// ---------------------------------------------------------------------------
// waterEffect — SwiftUI colorEffect entry point.
//
// Call site (WaterShaderView):
//   ShaderLibrary.waterEffect(
//       .float(time), .float2(renderSize), .color(theme.waterColor),
//       .float(intensity), .float(raymarchSteps), .float(raymarchIterations),
//       .float(normalIterations)
//   )
//
// Quality knobs come in as floats (SwiftUI's shader uniform system doesn't
// pass ints) and are truncated to int locally.
// ---------------------------------------------------------------------------
[[ stitchable ]]
half4 waterEffect(float2 position,
                   half4 color,
                   float time,
                   float2 size,
                   half4 tint,
                   float intensity,
                   float raymarchStepsF,
                   float raymarchIterationsF,
                   float normalIterationsF) {

    int raymarchSteps      = max(4, int(raymarchStepsF));
    int raymarchIterations = max(2, int(raymarchIterationsF));
    int normalIterations   = max(2, int(normalIterationsF));

    // No FF time offset here (that existed to precision-harden Shadertoy's
    // huge accumulated iTime on a page left open for hours). This shader's
    // `time` starts at 0 each app launch, and the mod-wrap below still
    // protects it if the app runs for days.
    float nTime     = time;
    float camDriftX = nTime * 0.2;

    float3 ray = getRay(position, size);

    float3 outColor;

    if (ray.y >= 0.0) {
        float3 C = getAtmosphere(ray, nTime) + getSun(ray, nTime);
        outColor = acesTonemap(C * 2.0);
    } else {
        float3 waterPlaneHigh = float3(0.0, 0.0, 0.0);
        float3 waterPlaneLow  = float3(0.0, -kWaterDepth, 0.0);
        float3 origin = float3(0.0, kCameraHeight, 1.0);

        float highPlaneHit = intersectPlane(origin, ray, waterPlaneHigh, float3(0.0, 1.0, 0.0));
        float lowPlaneHit  = intersectPlane(origin, ray, waterPlaneLow,  float3(0.0, 1.0, 0.0));
        float3 highHitPos = origin + ray * highPlaneHit;
        float3 lowHitPos  = origin + ray * lowPlaneHit;

        float dist = raymarchwater(origin, highHitPos, lowHitPos, kWaterDepth,
                                    raymarchSteps, raymarchIterations, nTime, camDriftX);
        float3 waterHitPos = origin + ray * dist;

        float3 N = waterNormal(waterHitPos.xz, 0.01, kWaterDepth, normalIterations, nTime, camDriftX);
        N = mix(N, float3(0.0, 1.0, 0.0), 0.8 * min(1.0, sqrt(dist * 0.01) * 1.1));

        float fresnel = 0.04 + (1.0 - 0.04) * pow(1.0 - max(0.0, dot(-N, ray)), 5.0);

        float3 R = normalize(reflect(ray, N));
        R.y = abs(R.y);

        float3 reflection = getAtmosphere(R, nTime) + getSun(R, nTime);
        float3 scattering = float3(0.0293, 0.0698, 0.1717) * 0.1
                           * (0.2 + (waterHitPos.y + kWaterDepth) / kWaterDepth);

        float3 C = fresnel * reflection + scattering;
        outColor = acesTonemap(C * 2.0);
    }

    // theme.waterColor tints the result; intensity blends between the raw
    // rendered water and that tint so the effect can be pushed toward the
    // app's theme color without losing the shading detail underneath.
    half3 shaded = half3(outColor);
    half3 tinted = mix(shaded, shaded * half3(tint.rgb) * 2.0, half(clamp(intensity, 0.0, 1.0)));

    return half4(tinted, 1.0);
}
