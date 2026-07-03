import SwiftUI
import Combine

// ---------------------------------------------------------------------------
// WaterShaderView — unchanged, kept for any existing call sites.
// ---------------------------------------------------------------------------
struct WaterShaderView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var time: Double = 0
    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(theme.waterColor)
                .colorEffect(
                    ShaderLibrary.waterEffect(
                        .float(time),
                        .float2(geo.size),
                        .color(theme.waterColor),
                        .float(Float(theme.waterIntensity))
                    )
                )
                .ignoresSafeArea()
                .onReceive(timer) { _ in
                    time += (1.0 / 60.0) * theme.waterSpeed
                }
        }
        .ignoresSafeArea()
    }
}

// ---------------------------------------------------------------------------
// FogShaderView
//
// KEY FIX: the Rectangle must be filled with an *opaque* colour, not
// Color.clear.  colorEffect works by recolouring each pixel the view
// already has — if the fill is transparent (alpha=0), the shader receives
// alpha=0 and can only return alpha=0, so nothing appears.
//
// We fill with the current background colour so:
//  • The shader receives a visible base pixel.
//  • The fog blends *over* that base inside the shader.
//  • Where fog density is low the base colour shows through unchanged.
// ---------------------------------------------------------------------------
struct FogShaderView: View {
    @EnvironmentObject var theme: ThemeManager

    /// Pre-scaled time: pass `rawTime * theme.fogSpeed` from the caller.
    let time: Double

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                // Must be opaque so colorEffect has a real pixel to work with.
                .fill(theme.backgroundColor)
                .colorEffect(
                    ShaderLibrary.fogEffect(
                        .float(time),
                        .float2(geo.size),
                        .color(theme.fogColor),
                        .float(Float(theme.fogIntensity)),
                        .float(Float(theme.fogSpeed))
                    )
                )
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// ---------------------------------------------------------------------------
// TunnelShaderView
//
// Raymarched fractal tunnel, ported to Metal from the Shadertoy shader
// "RayMarching starting point" by Martijn Steinrucken (The Art of Code /
// BigWings), 2020 — MIT License. See TunnelShader.metal for the full port
// and license note. Credit is also surfaced to the user in SettingsView.
//
// PERFORMANCE: this is the most expensive effect in the app (raymarching is
// a per-pixel nested loop), so unlike Water/Fog it gets its own tuning://   • Rendered at `theme.tunnelQuality.resolutionScale` of the real screen
//     size, then upscaled — the single biggest lever, since shader cost
//     scales with pixel count (half-res = 4x fewer pixels to shade).
//   • `.drawingGroup(opaque: true)` forces that smaller render to actually
//     rasterize at the reduced size before `.scaleEffect` blows it up —
//     without this, SwiftUI may just re-run the shader at the final size.
//   • March-step / fold-iteration budget also scales with quality tier
//     (passed into the shader as uniforms, not baked into the .metal file).
//   • Its own clock runs at `theme.tunnelQuality.frameInterval` (as low as
//     ~24fps) rather than the app's 60fps timer — slow ambient background
//     motion doesn't need 60fps, and this halves-to-thirds the shader
//     invocation rate on its own.
//   • Dithering uses a tiled blue-noise texture (organic grain, no
//     repeating grid) rather than a computed Bayer matrix — requires
//     "BlueNoise64" to be added to Assets.xcassets. See TunnelShader.metal.
// ---------------------------------------------------------------------------
struct TunnelShaderView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var time: Double = 0
    @State private var lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        let quality = effectiveQuality
        let scale = quality.resolutionScale

        return GeometryReader { geo in
            let renderSize = CGSize(
                width: max(1, geo.size.width * scale),
                height: max(1, geo.size.height * scale)
            )

            Rectangle()
                .fill(theme.backgroundColor)
                .colorEffect(
                    ShaderLibrary.tunnelEffect(
                        .float(time),
                        .float2(renderSize),
                        .color(theme.tunnelColor),
                        .float(Float(theme.tunnelSpeed)),
                        .float(Float(theme.tunnelIntensity)),
                        .float(Float(quality.maxSteps)),
                        .float(Float(quality.foldIterations)),
                        .image(Image("BlueNoise64"))
                    )
                )
                .frame(width: renderSize.width, height: renderSize.height)
                // Rasterize at the reduced size *before* scaling up, so the
                // shader only ever runs across renderSize pixels.
                .drawingGroup(opaque: true)
                .scaleEffect(1 / scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onReceive(
            Timer.publish(every: quality.frameInterval, on: .main, in: .common).autoconnect()
        ) { _ in
            guard scenePhase == .active else { return }
            time += quality.frameInterval
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
        ) { _ in
            lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    /// Low Power Mode always wins, regardless of the user's chosen setting —
    /// this is what actually saves battery, not just GPU headroom.
    private var effectiveQuality: TunnelQuality {
        lowPowerModeEnabled ? .low : theme.tunnelQuality
    }
}

// ---------------------------------------------------------------------------
// AppBackground
//
// Water and fog share the app's single 60fps timer (they're comparatively
// cheap — a handful of noise taps, not a raymarch). The tunnel drives its
// own clock inside TunnelShaderView so it can run at a lower frame rate and
// pause independently; see the performance notes there.
//
// Layer order:
//   1. Solid base colour   (always)
//   2. Water caustics      (if useWaterShader)
//   3. Tunnel raymarch     (if useTunnelShader)
//   4. Fog overlay         (if useFogShader)
//
// Fog stays on top since it's meant to sit over everything ("mist" look).
// The tunnel is a full replacement backdrop rather than a blend layer —
// enabling it alongside water will simply show the tunnel on top, which is
// expected if both are toggled on.
//
// Usage:  replace `theme.backgroundColor.ignoresSafeArea()` and any
//         `WaterShaderView()` call with a single `AppBackground()`.
// ---------------------------------------------------------------------------
struct AppBackground: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var time: Double = 0

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        ZStack {
            // 1. Base — always rendered, zero GPU cost.
            theme.backgroundColor.ignoresSafeArea()

            // 2. Water caustics layer.
            if theme.useWaterShader {
                GeometryReader { geo in
                    Rectangle()
                        .fill(theme.waterColor)
                        .colorEffect(
                            ShaderLibrary.waterEffect(
                                .float(time * theme.waterSpeed),
                                .float2(geo.size),
                                .color(theme.waterColor),
                                .float(Float(theme.waterIntensity))
                            )
                        )
                        .ignoresSafeArea()
                }
                .ignoresSafeArea()
            }

            // 3. Raymarched tunnel layer — owns its own clock/quality, see above.
            if theme.useTunnelShader {
                TunnelShaderView()
            }

            // 4. Fog overlay — on top of whatever is below.
            if theme.useFogShader {
                FogShaderView(time: time * theme.fogSpeed)
            }
        }
        .onReceive(timer) { _ in
            guard scenePhase == .active else { return }
            if theme.useWaterShader || theme.useFogShader {
                time += 1.0 / 60.0
            }
        }
    }
}

#Preview {
    AppBackground()
        .environmentObject(ThemeManager())
}
