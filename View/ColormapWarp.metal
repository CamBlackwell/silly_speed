#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Colormap Warp fBM (Shadertoy-style port)
// Created by trinketMage in 2019-10-10
// https://www.shadertoy.com/view/tdG3Rd
// Port of the provided GLSL snippet to Metal as a SwiftUI-compatible
// [[ stitchable ]] colorEffect.  The shader computes a fractal Brownian
// motion field and maps its shade through a custom colormap.  It blends over
// the incoming pixel colour using an `intensity` uniform so it can layer
// alongside existing effects.
//
// Usage from SwiftUI (example):
//   Rectangle()
//     .fill(theme.backgroundColor)
//     .colorEffect(
//         ShaderLibrary.colormapWarpEffect(
//             .float(time),
//             .float2(geo.size),
//             .float(0.8) // intensity 0…1
//         )
//     )
// ---------------------------------------------------------------------------

// --- Colormap (exact port of the provided functions) -----------------------
static float colormap_red(float x) {
    if (x < 0.0) {
        return 54.0 / 255.0;
    } else if (x < 20049.0 / 82979.0) {
        return (829.79 * x + 54.51) / 255.0;
    } else {
        return 1.0;
    }
}

static float colormap_green(float x) {
    if (x < 20049.0 / 82979.0) {
        return 0.0;
    } else if (x < 327013.0 / 810990.0) {
        return (8546482679670.0 / 10875673217.0 * x - 2064961390770.0 / 10875673217.0) / 255.0;
    } else if (x <= 1.0) {
        return (103806720.0 / 483977.0 * x + 19607415.0 / 483977.0) / 255.0;
    } else {
        return 1.0;
    }
}

static float colormap_blue(float x) {
    if (x < 0.0) {
        return 54.0 / 255.0;
    } else if (x < 7249.0 / 82979.0) {
        return (829.79 * x + 54.51) / 255.0;
    } else if (x < 20049.0 / 82979.0) {
        return 127.0 / 255.0;
    } else if (x < 327013.0 / 810990.0) {
        return (792.02249341361393720147485376583 * x - 64.364790735602331034989206222672) / 255.0;
    } else {
        return 1.0;
    }
}

static float3 colormap(float x) {
    return float3(colormap_red(x), colormap_green(x), colormap_blue(x));
}

// --- Noise helpers ----------------------------------------------------------
static float rand(float2 n) {
    return fract(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
}

static float noise(float2 p) {
    float2 ip = floor(p);
    float2 u  = fract(p);
    u = u * u * (3.0 - 2.0 * u);

    float a = rand(ip);
    float b = rand(ip + float2(1.0, 0.0));
    float c = rand(ip + float2(0.0, 1.0));
    float d = rand(ip + float2(1.0, 1.0));

    float mixX1 = mix(a, b, u.x);
    float mixX2 = mix(c, d, u.x);
    float res   = mix(mixX1, mixX2, u.y);
    return res * res;
}

constant float2x2 kWarpMtx = float2x2( 0.80,  0.60,
                                       -0.60,  0.80 ); // column-major

static float fbm(float2 p, float time) {
    float f = 0.0;

    f += 0.500000 * noise(p + time); p = (kWarpMtx * p) * 2.02;
    f += 0.031250 * noise(p);        p = (kWarpMtx * p) * 2.01;
    f += 0.250000 * noise(p);        p = (kWarpMtx * p) * 2.03;
    f += 0.125000 * noise(p);        p = (kWarpMtx * p) * 2.01;
    f += 0.062500 * noise(p);        p = (kWarpMtx * p) * 2.04;
    f += 0.015625 * noise(p + sin(time));

    return f / 0.96875;
}

static float pattern(float2 p, float time) {
    float a = fbm(p, time);
    float b = fbm(p + float2(a), time);
    float c = fbm(p + float2(b), time);
    return c;
}

// --- Stitchable entry -------------------------------------------------------
// Parameters mirror the other effects: position/color are implicit, followed
// by time, size (in pixels), and an intensity crossfade.
[[ stitchable ]] half4 colormapWarpEffect(
    float2 position,
    half4  color,
    float  time,
    float2 size,
    float  intensity,
    float  grayscale
) {
    // Match the original shader's aspect handling: uv = fragCoord / iResolution.x
    float2 uv = position / max(size.x, 1.0);

    float shade = pattern(uv, time);

    // Base mapped colour from the provided colormap
    float3 mapped = colormap(shade);

    // Greyscale version (smoke-like) — simple luminance ~ shade ramp
    float3 grey = float3(shade);

    // Mix toward greyscale by `grayscale` in [0,1]
    float3 smokeRGB = mix(mapped, grey, clamp(grayscale, 0.0, 1.0));

    // Crossfade over the incoming pixel to play nicely with other layers.
    half  k = half(clamp(intensity, 0.0, 1.0));
    half3 outRGB = mix(half3(color.rgb), half3(smokeRGB), k);

    return half4(outRGB, color.a);
}
