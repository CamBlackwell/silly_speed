#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Lightweight smoke effect
//
// Characteristics:
//  • Soft, drifting wisps instead of hard fog bands — smooth gradients,
//    no posterisation
//  • Rises upward and swirls slightly, like real smoke, using a single
//    cheap "domain warp" pass rather than many noise octaves
//  • Built on a small hash-based value noise (4 samples/octave) with only
//    3 octaves max — much cheaper than a full Perlin/simplex or texture-based
//    smoke sim, so it stays GPU-light and safe for real-time use
//  • Very light dither is kept on the softest parts of the gradient purely
//    to avoid 8-bit banding on large screens, not to fake hard edges
//  • Colour tinted from the user's fogColor so it matches the theme
//
// Function name/signature kept identical to the original fogEffect so this
// is a drop-in replacement wherever it's referenced (e.g. in SwiftUI).
// ---------------------------------------------------------------------------

// Cheap hash — no trig, just a couple of multiply/fract ops
static float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Value noise (bilinear-interpolated hash) — 4 hash samples per call
static float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f); // smoothstep interpolation
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// 3-octave fbm — capped low on purpose to keep this cheap
static float smokeFBM(float2 p) {
    float sum = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        sum += amp * valueNoise(p);
        p *= 2.02;
        amp *= 0.5;
    }
    return sum;
}

// 4×4 Bayer matrix — used here only as gentle dither to hide 8-bit banding
static float bayer4x4(uint2 pos) {
    const uint8_t matrix[4][4] = {
        {  0,  8,  2, 10 },
        { 12,  4, 14,  6 },
        {  3, 11,  1,  9 },
        { 15,  7, 13,  5 }
    };
    return float(matrix[pos.y % 4][pos.x % 4]) / 16.0;
}

[[ stitchable ]] half4 fogEffect(
    float2 position,
    half4  color,
    float  time,
    float2 size,
    half4  fogColor,
    float  intensity,
    float  speed
) {
    float2 uv = position / size;
    float aspect = size.x / max(size.y, 1.0);
    float2 aspectUV = float2(uv.x * aspect, uv.y);

    // --- Large-scale circular swirl around the screen ---
    // Instead of a straight scroll, twist coordinates around the screen
    // centre by an angle that depends on distance-from-centre and time.
    // This is just one atan2/cos/sin per pixel — cheap — but reads as
    // proper circulating motion rather than a linear drift.
    float2 center = float2(0.5 * aspect, 0.5);
    float2 rel = aspectUV - center;
    float dist = length(rel);
    float angle = atan2(rel.y, rel.x);
    float swirlAmount = sin(dist * 2.2 - time * speed * 0.25) * 0.9
                       + time * speed * 0.06; // slow continuous rotation too
    angle += swirlAmount;
    float2 swirlPos = center + dist * float2(cos(angle), sin(angle));

    // Base coordinate for the smoke field.
    float2 p = swirlPos * 3.2;

    // Gentle secondary drift so it still has some overall flow, not just
    // spinning in place
    p.y -= time * speed * 0.10;
    p.x += sin(time * speed * 0.08) * 0.15;

    // Single cheap domain-warp pass: nudge the sample point by a lower-
    // frequency noise field so the smoke swirls instead of just scrolling.
    // (One extra noise call per axis — far cheaper than a second full fbm.)
    float2 warp = float2(
        valueNoise(p * 0.6 + time * speed * 0.05),
        valueNoise(p * 0.6 - time * speed * 0.04)
    );
    p += (warp - 0.5) * 1.1;

    float smoke = smokeFBM(p);

    // Soft-edged density — smooth gradient, no hard posterisation
    float density = smoothstep(0.30, 0.85, smoke) * intensity;

    // Thin the smoke out near the very top/bottom so it reads as drifting
    // clouds rather than a flat screen-wide haze
    float verticalFalloff = smoothstep(0.0, 0.25, uv.y) * smoothstep(1.0, 0.75, uv.y);
    density *= mix(0.6, 1.0, verticalFalloff);

    density = clamp(density, 0.0, 0.9);

    // Very light dither to avoid 8-bit banding on smooth gradients —
    // subtle, unlike the original's chunky visible dither
    uint2 ditherCoord = uint2(uint(position.x) % 4, uint(position.y) % 4);
    float threshold = bayer4x4(ditherCoord);
    density += (threshold - 0.5) * 0.02;
    density = clamp(density, 0.0, 1.0);

    // --- Colour: use the user's fogColor ---
    half3 blended = mix(half3(color.rgb), half3(fogColor.rgb), half(density));

    return half4(blended, color.a);
}
