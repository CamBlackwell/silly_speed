import SwiftUI
import Combine

// ---------------------------------------------------------------------------
// WaterShaderView
//
// Raymarched water, ported to Metal from the Shadertoy shader by afl_ext
// (2017-2024, precision-hardened variant). See Water.metal for the full
// port and the specific changes made porting it (mouse-look camera removed,
// a wasted duplicate raymarch in the original's AA loop removed, iteration
// counts made uniforms instead of #defines).
//
// This follows the exact same performance pattern TunnelShaderView already
// uses below, because it has the same problem: a per-pixel raymarch is the
// most expensive thing you can put in a SwiftUI colorEffect, so:
//   • Rendered at `quality.resolutionScale` of the real screen size, then
//     upscaled via .scaleEffect.
//   • `.drawingGroup(opaque: true)` forces that smaller render to actually
//     rasterize at reduced size before the upscale, instead of SwiftUI
//     re-running the shader at full size.
//   • Its own clock runs at `quality.frameInterval` rather than the app's
//     60fps timer — water no longer shares AppBackground's timer at all.
//   • Low Power Mode always overrides to `.low`, same override rule as the
//     tunnel.
//
// Quality is a real, user-facing setting — see `WaterQuality` and
// `ThemeManager.waterQuality` in setting_View.swift, with a segmented
// picker in SettingsView's water section right alongside the tunnel one.
// ---------------------------------------------------------------------------
struct WaterShaderView: View {
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
                // Must be opaque — colorEffect recolors the pixel it's
                // given, so a transparent fill gives it nothing to work with
                // and the whole effect renders invisible.
                .fill(theme.waterColor)
                .colorEffect(
                    ShaderLibrary.waterEffect(
                        .float(time),
                        .float2(renderSize),
                        .color(theme.waterColor),
                        .float(Float(theme.waterIntensity)),
                        .float(Float(quality.raymarchSteps)),
                        .float(Float(quality.raymarchIterations)),
                        .float(Float(quality.normalIterations))
                    )
                )
                .frame(width: renderSize.width, height: renderSize.height)
                .drawingGroup(opaque: true)
                // Smooths the blocky edges the low-res render leaves once
                // stretched to full size; radius is in the low-res buffer's
                // own point space so it auto-scales with the resolution drop.
                .blur(radius: 1.0)
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
            time += quality.frameInterval * theme.waterSpeed
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
        ) { _ in
            lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    /// Low Power Mode always wins, same rule as the tunnel shader — this is
    /// what actually saves battery, not just headroom.
    private var effectiveQuality: WaterQuality {
        lowPowerModeEnabled ? .low : theme.waterQuality
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
                // Smooths the blocky edges the low-res render leaves behind
                // once it's stretched up to full size. Radius is in the
                // low-res buffer's own point space, so it scales with the
                // resolution drop automatically (lower scale → this radius
                // covers proportionally more of the final blocky edge).
                //.blur(radius: 1.2)
                .scaleEffect(1 / scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                //.clipped()
                // Re-applies crisp blue-noise grain at full resolution, after
                // the blur above — otherwise the blur would smear the dither
                // into a soft blob instead of grain. Cheap: one texture
                // sample, no raymarching.
                .colorEffect(
                    ShaderLibrary.grainOverlay(
                        .image(Image("BlueNoise64")),
                        .float(Float(theme.tunnelGrainStrength))
                    )
                )
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
// SmokeShaderView
//
// fBM colormap warp, ported to Metal from the Shadertoy shader by
// trinketMage (2019), https://www.shadertoy.com/view/tdG3Rd. See
// ColormapWarp.metal for the full port. Surfaced to the rest of the app as
// the "Smoke" effect — see `ThemeManager.useSmokeShader` / `smokeSpeed` /
// `smokeIntensity` / `smokeGrayscale` / `smokeQuality` and SettingsView's
// smokeShaderSection, right alongside Water/Fog/Tunnel.
//
// Same performance pattern as Water/Tunnel above, because it has the same
// problem: three chained fbm() calls (six noise taps each) per pixel isn't
// cheap in a SwiftUI colorEffect, so:
//   • Rendered at `quality.resolutionScale` of the real screen size, then
//     upscaled via .scaleEffect.
//   • `.drawingGroup(opaque: true)` forces that smaller render to actually
//     rasterize at reduced size before the upscale, instead of SwiftUI
//     re-running the shader at full size.
//   • Its own clock runs at `quality.frameInterval` rather than the app's
//     60fps timer.
//   • Low Power Mode always overrides to `.low`, same override rule as
//     water and tunnel.
//
// Quality is a real, user-facing setting — see `SmokeQuality` and
// `ThemeManager.smokeQuality` in setting_View.swift, with a segmented
// picker in SettingsView's smoke section alongside water and tunnel.
// ---------------------------------------------------------------------------
struct SmokeShaderView: View {
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
                // Must be opaque — colorEffect recolors the pixel it's
                // given, so a transparent fill gives it nothing to work with
                // and the whole effect renders invisible.
                .fill(theme.backgroundColor)
                .colorEffect(
                    ShaderLibrary.colormapWarpEffect(
                        .float(time),
                        .float2(renderSize),
                        .float(Float(theme.smokeIntensity)),
                        .float(Float(theme.smokeGrayscale))
                    )
                )
                .frame(width: renderSize.width, height: renderSize.height)
                .drawingGroup(opaque: true)
                // Smooths the blocky edges the low-res render leaves once
                // stretched to full size; radius is in the low-res buffer's
                // own point space so it auto-scales with the resolution drop.
                .blur(radius: 1.0)
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
            time += quality.frameInterval * theme.smokeSpeed
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
        ) { _ in
            lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    /// Low Power Mode always wins, same rule as water and tunnel — this is
    /// what actually saves battery, not just headroom.
    private var effectiveQuality: SmokeQuality {
        lowPowerModeEnabled ? .low : theme.smokeQuality
    }
}

// ---------------------------------------------------------------------------
// AppBackground
//
// Fog shares the app's single 60fps timer (it's comparatively cheap — a
// handful of noise taps, not a raymarch). Water and tunnel each drive their
// own clock inside their view so they can run at a lower frame rate and
// pause independently; see the performance notes on each.
//
// Layer order:
//   1. Solid base colour   (always)
//   2. Water raymarch      (if useWaterShader)
//   3. Tunnel raymarch     (if useTunnelShader)
//   4. Smoke colormap warp (if useSmokeShader)
//   5. Fog overlay         (if useFogShader)
//
// Fog stays on top since it's meant to sit over everything ("mist" look).
// Water, tunnel, and smoke are all full replacement backdrops rather than
// blend layers — enabling more than one together will simply show
// whichever is later in the ZStack on top, which is expected.
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

            // 2. Water layer — owns its own clock/quality, see WaterShaderView.
            if theme.useWaterShader {
                WaterShaderView()
            }

            // 3. Raymarched tunnel layer — owns its own clock/quality, see above.
            if theme.useTunnelShader {
                TunnelShaderView()
            }

            // 4. Smoke colormap-warp layer — owns its own clock/quality, see
            //    SmokeShaderView.
            if theme.useSmokeShader {
                SmokeShaderView()
            }

            // 5. Fog overlay — on top of whatever is below.
            if theme.useFogShader {
                FogShaderView(time: time * theme.fogSpeed)
            }
        }
        .onReceive(timer) { _ in
            guard scenePhase == .active else { return }
            if theme.useFogShader {
                time += 1.0 / 60.0
            }
        }
    }
}

#Preview {
    AppBackground()
        .environmentObject(ThemeManager())
}
