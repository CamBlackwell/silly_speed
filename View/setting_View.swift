import SwiftUI
import Combine

// MARK: - Tunnel Shader Quality
//
// Bundles the three performance levers for the raymarched tunnel effect
// (render resolution, march-step budget, fractal-fold budget) plus its
// frame rate into named tiers, so Settings can offer one simple picker
// instead of four separate sliders. See TunnelShaderView / TunnelShader.metal
// for how each value is used.

enum TunnelQuality: String, CaseIterable, Identifiable {
    case low     = "Low"
    case balanced = "Balanced"
    case high    = "High"

    var id: String { rawValue }

    /// Fraction of the real screen resolution the shader renders at.
    /// The single biggest cost lever — cost scales with pixel count.
    var resolutionScale: CGFloat {
        switch self {
        case .low:      return 0.35
        case .balanced: return 0.55
        case .high:     return 0.8
        }
    }

    /// Max raymarch steps per pixel.
    var maxSteps: Int {
        switch self {
        case .low:      return 75
        case .balanced: return 130
        case .high:     return 200
        }
    }

    /// Fractal fold iterations per march step (this loop is nested inside
    /// the step loop, so it's the most expensive knob per-unit-change).
    var foldIterations: Int {
        switch self {
        case .low:      return 5
        case .balanced: return 7
        case .high:     return 9
        }
    }

    /// Seconds between frame updates — a slow ambient background doesn't
    /// need 60fps.
    var frameInterval: Double {
        switch self {
        case .low:      return 1.0 / 24.0
        case .balanced: return 1.0 / 30.0
        case .high:     return 1.0 / 60.0
        }
    }
}

// MARK: - Water Shader Quality
//
// Same idea as TunnelQuality above: bundles the raymarch performance levers
// for the water effect into named tiers so Settings offers one picker
// instead of three sliders. See WaterShaderView / Water.metal for how each
// value is used.

enum WaterQuality: String, CaseIterable, Identifiable {
    case low     = "Low"
    case balanced = "Balanced"
    case high    = "High"

    var id: String { rawValue }

    /// Fraction of the real screen resolution the shader renders at.
    var resolutionScale: CGFloat {
        switch self {
        case .low:      return 0.35
        case .balanced: return 0.5
        case .high:     return 0.75
        }
    }

    /// Max raymarch steps per pixel.
    var raymarchSteps: Int {
        switch self {
        case .low:      return 16
        case .balanced: return 22
        case .high:     return 32
        }
    }

    /// Wave octaves sampled per raymarch step.
    var raymarchIterations: Int {
        switch self {
        case .low:      return 4
        case .balanced: return 6
        case .high:     return 8
        }
    }

    /// Wave octaves sampled per normal() call — called 3x per pixel, so
    /// this is the single most expensive knob per shaded pixel.
    var normalIterations: Int {
        switch self {
        case .low:      return 8
        case .balanced: return 12
        case .high:     return 18
        }
    }

    /// Seconds between frame updates — water motion is slow and ambient,
    /// it doesn't need 60fps.
    var frameInterval: Double {
        switch self {
        case .low:      return 1.0 / 15.0
        case .balanced: return 1.0 / 24.0
        case .high:     return 1.0 / 30.0
        }
    }
}

// MARK: - Theme Preset

struct ThemePreset {
    var background: Color
    var text: Color
    var secondaryText: Color
    var accent: Color
    var tint: Color
    var gonioSides: Color
    var gonioMids: Color
    var playButton: Color
    // Water
    var useWaterShader: Bool
    var waterSpeed: Double
    var waterIntensity: Double
    var waterQuality: WaterQuality
    // Fog
    var useFogShader: Bool
    var fogColor: Color
    var fogSpeed: Double
    var fogIntensity: Double
    // Tunnel (raymarched fractal tunnel — see credit in SettingsView)
    var useTunnelShader: Bool
    var tunnelColor: Color
    var tunnelSpeed: Double
    var tunnelIntensity: Double
    var tunnelQuality: TunnelQuality
    var tunnelGrainStrength: Double
    // Smoke (colormap-warp effect used behind SpectrumView)
    var useSmokeShader: Bool
    var smokeSpeed: Double
    var smokeIntensity: Double
    var smokeGrayscale: Double

    /// Convenience init that back-fills fog/tunnel/smoke defaults so every
    /// existing ThemePreset call site compiles without change.
    init(
        background: Color, text: Color, secondaryText: Color,
        accent: Color, tint: Color, gonioSides: Color, gonioMids: Color,
        playButton: Color,
        useWaterShader: Bool, waterSpeed: Double, waterIntensity: Double,
        waterQuality: WaterQuality = .balanced,
        useFogShader: Bool = false,
        fogColor: Color = Color(hex: "#b0c8e0"),
        fogSpeed: Double = 0.6,
        fogIntensity: Double = 0.7,
        useTunnelShader: Bool = false,
        tunnelColor: Color = Color(hex: "#54a8ff"),
        tunnelSpeed: Double = 1.0,
        tunnelIntensity: Double = 1.0,
        tunnelQuality: TunnelQuality = .balanced,
        tunnelGrainStrength: Double = 0.12,
        useSmokeShader: Bool = false,
        smokeSpeed: Double = 1.0,
        smokeIntensity: Double = 1.0,
        smokeGrayscale: Double = 0.0
    ) {
        self.background     = background
        self.text           = text
        self.secondaryText  = secondaryText
        self.accent         = accent
        self.tint           = tint
        self.gonioSides     = gonioSides
        self.gonioMids      = gonioMids
        self.playButton     = playButton
        self.useWaterShader = useWaterShader
        self.waterSpeed     = waterSpeed
        self.waterIntensity = waterIntensity
        self.waterQuality   = waterQuality
        self.useFogShader   = useFogShader
        self.fogColor       = fogColor
        self.fogSpeed       = fogSpeed
        self.fogIntensity   = fogIntensity
        self.useTunnelShader = useTunnelShader
        self.tunnelColor     = tunnelColor
        self.tunnelSpeed     = tunnelSpeed
        self.tunnelIntensity = tunnelIntensity
        self.tunnelQuality   = tunnelQuality
        self.tunnelGrainStrength = tunnelGrainStrength
        self.useSmokeShader  = useSmokeShader
        self.smokeSpeed      = smokeSpeed
        self.smokeIntensity  = smokeIntensity
        self.smokeGrayscale  = smokeGrayscale
    }

    static let empty = ThemePreset(
        background: .black, text: .white, secondaryText: .gray,
        accent: .blue, tint: .blue, gonioSides: .red, gonioMids: .purple,
        playButton: .white, useWaterShader: false, waterSpeed: 1.0, waterIntensity: 0.5
    )
}

// MARK: - Named Themes

enum AppTheme: String, CaseIterable, Identifiable {
    // Dark
    case minimalDark    = "Default"
    case atom           = "Atom"
    case ayu            = "Ayu"
    case catppuccin     = "Catppuccin"
    case dracula        = "Dracula"
    case eink           = "E-ink"
    case everforestDark = "Everforest"
    case flexoki        = "Flexoki"
    case gruvboxDark    = "Gruvbox"
    case macos          = "macOS"
    case nord           = "Nord"
    case rosePineDark   = "Rosé Pine"
    case sky            = "Sky"
    case solarizedDark  = "Solarized"
    case things         = "Things"
    case water          = "Water"
    case fog            = "Fog"
    case mist           = "Mist"
    case tunnel         = "Tunnel"
    case tokyoNight    = "Tokyo Night"

    // Light
    case minimalLight    = "Default (Light)"
    case atomLight       = "Atom (Light)"
    case ayuLight        = "Ayu (Light)"
    case catppuccinLight = "Catppuccin (Light)"
    case einkLight       = "E-ink (Light)"
    case everforestLight = "Everforest (Light)"
    case flexokiLight    = "Flexoki (Light)"
    case gruvboxLight    = "Gruvbox (Light)"
    case macosLight      = "macOS (Light)"
    case nordLight       = "Nord (Light)"
    case rosePineLight   = "Rosé Pine Dawn"
    case skyLight        = "Sky (Light)"
    case solarizedLight  = "Solarized (Light)"
    case thingsLight     = "Things (Light)"
    case tokyoDay       = "Tokyo Day"

    var id: String { rawValue }

    static var darkThemes: [AppTheme] {
        [.minimalDark, .atom, .ayu, .catppuccin, .dracula, .eink,
         .everforestDark, .flexoki, .gruvboxDark, .macos, .nord,
         .rosePineDark, .sky, .solarizedDark, .things, .water, .fog, .mist, .tunnel, .tokyoNight]
    }

    static var lightThemes: [AppTheme] {
        [.minimalLight, .atomLight, .ayuLight, .catppuccinLight, .einkLight,
         .everforestLight, .flexokiLight, .gruvboxLight, .macosLight, .nordLight,
         .rosePineLight, .skyLight, .solarizedLight, .thingsLight, .tokyoDay]
    }

    // MARK: Colour values for each theme

    var preset: ThemePreset {
        switch self {

        // ── Dark themes ──────────────────────────────────────────────────────

        case .minimalDark:
            return ThemePreset(
                background:    Color(hex: "#1a1a1a"),
                text:          Color(hex: "#dadada"),
                secondaryText: Color(hex: "#888888"),
                accent:        Color(hex: "#7b6cd4"),
                tint:          Color(hex: "#7b6cd4"),
                gonioSides:    Color(hex: "#c9a8f5"),
                gonioMids:     Color(hex: "#7b6cd4"),
                playButton:    Color(hex: "#dadada"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .atom:
            return ThemePreset(
                background:    Color(hex: "#282c34"),
                text:          Color(hex: "#abb2bf"),
                secondaryText: Color(hex: "#5c6370"),
                accent:        Color(hex: "#61afef"),
                tint:          Color(hex: "#61afef"),
                gonioSides:    Color(hex: "#e06c75"),
                gonioMids:     Color(hex: "#c678dd"),
                playButton:    Color(hex: "#abb2bf"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .ayu:
            return ThemePreset(
                background:    Color(hex: "#0d1017"),
                text:          Color(hex: "#bfbdb6"),
                secondaryText: Color(hex: "#5c6773"),
                accent:        Color(hex: "#ffb454"),
                tint:          Color(hex: "#ffb454"),
                gonioSides:    Color(hex: "#f07178"),
                gonioMids:     Color(hex: "#d2a6ff"),
                playButton:    Color(hex: "#bfbdb6"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .catppuccin:
            return ThemePreset(
                background:    Color(hex: "#1e1e2e"),
                text:          Color(hex: "#cdd6f4"),
                secondaryText: Color(hex: "#6c7086"),
                accent:        Color(hex: "#cba6f7"),
                tint:          Color(hex: "#cba6f7"),
                gonioSides:    Color(hex: "#f38ba8"),
                gonioMids:     Color(hex: "#89b4fa"),
                playButton:    Color(hex: "#cdd6f4"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .dracula:
            return ThemePreset(
                background:    Color(hex: "#282a36"),
                text:          Color(hex: "#f8f8f2"),
                secondaryText: Color(hex: "#6272a4"),
                accent:        Color(hex: "#bd93f9"),
                tint:          Color(hex: "#bd93f9"),
                gonioSides:    Color(hex: "#ff79c6"),
                gonioMids:     Color(hex: "#8be9fd"),
                playButton:    Color(hex: "#f8f8f2"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .eink:
            return ThemePreset(
                background:    Color(hex: "#1c1c1c"),
                text:          Color(hex: "#e8e8e8"),
                secondaryText: Color(hex: "#888888"),
                accent:        Color(hex: "#aaaaaa"),
                tint:          Color(hex: "#aaaaaa"),
                gonioSides:    Color(hex: "#cccccc"),
                gonioMids:     Color(hex: "#888888"),
                playButton:    Color(hex: "#e8e8e8"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .everforestDark:
            return ThemePreset(
                background:    Color(hex: "#2d353b"),
                text:          Color(hex: "#d3c6aa"),
                secondaryText: Color(hex: "#7a8478"),
                accent:        Color(hex: "#a7c080"),
                tint:          Color(hex: "#a7c080"),
                gonioSides:    Color(hex: "#e67e80"),
                gonioMids:     Color(hex: "#83c092"),
                playButton:    Color(hex: "#d3c6aa"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .flexoki:
            return ThemePreset(
                background:    Color(hex: "#100f0f"),
                text:          Color(hex: "#cecdc3"),
                secondaryText: Color(hex: "#575653"),
                accent:        Color(hex: "#d0a215"),
                tint:          Color(hex: "#d0a215"),
                gonioSides:    Color(hex: "#af3029"),
                gonioMids:     Color(hex: "#8b7ec8"),
                playButton:    Color(hex: "#cecdc3"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .gruvboxDark:
            return ThemePreset(
                background:    Color(hex: "#282828"),
                text:          Color(hex: "#ebdbb2"),
                secondaryText: Color(hex: "#928374"),
                accent:        Color(hex: "#fabd2f"),
                tint:          Color(hex: "#fabd2f"),
                gonioSides:    Color(hex: "#fb4934"),
                gonioMids:     Color(hex: "#b8bb26"),
                playButton:    Color(hex: "#ebdbb2"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .macos:
            return ThemePreset(
                background:    Color(hex: "#1e1e1e"),
                text:          Color(hex: "#ffffff"),
                secondaryText: Color(hex: "#8e8e93"),
                accent:        Color(hex: "#0a84ff"),
                tint:          Color(hex: "#0a84ff"),
                gonioSides:    Color(hex: "#ff453a"),
                gonioMids:     Color(hex: "#30d158"),
                playButton:    Color(hex: "#ffffff"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .nord:
            return ThemePreset(
                background:    Color(hex: "#2e3440"),
                text:          Color(hex: "#eceff4"),
                secondaryText: Color(hex: "#4c566a"),
                accent:        Color(hex: "#88c0d0"),
                tint:          Color(hex: "#88c0d0"),
                gonioSides:    Color(hex: "#bf616a"),
                gonioMids:     Color(hex: "#b48ead"),
                playButton:    Color(hex: "#eceff4"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .rosePineDark:
            return ThemePreset(
                background:    Color(hex: "#191724"),
                text:          Color(hex: "#e0def4"),
                secondaryText: Color(hex: "#6e6a86"),
                accent:        Color(hex: "#c4a7e7"),
                tint:          Color(hex: "#c4a7e7"),
                gonioSides:    Color(hex: "#eb6f92"),
                gonioMids:     Color(hex: "#9ccfd8"),
                playButton:    Color(hex: "#e0def4"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .sky:
            return ThemePreset(
                background:    Color(hex: "#1b2433"),
                text:          Color(hex: "#cdd9e5"),
                secondaryText: Color(hex: "#545d68"),
                accent:        Color(hex: "#539bf5"),
                tint:          Color(hex: "#539bf5"),
                gonioSides:    Color(hex: "#e5534b"),
                gonioMids:     Color(hex: "#57ab5a"),
                playButton:    Color(hex: "#cdd9e5"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .solarizedDark:
            return ThemePreset(
                background:    Color(hex: "#002b36"),
                text:          Color(hex: "#839496"),
                secondaryText: Color(hex: "#586e75"),
                accent:        Color(hex: "#268bd2"),
                tint:          Color(hex: "#268bd2"),
                gonioSides:    Color(hex: "#dc322f"),
                gonioMids:     Color(hex: "#2aa198"),
                playButton:    Color(hex: "#839496"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .things:
            return ThemePreset(
                background:    Color(hex: "#1c1c1e"),
                text:          Color(hex: "#f2f2f7"),
                secondaryText: Color(hex: "#636366"),
                accent:        Color(hex: "#4f8ef7"),
                tint:          Color(hex: "#4f8ef7"),
                gonioSides:    Color(hex: "#ff6b6b"),
                gonioMids:     Color(hex: "#5ac8fa"),
                playButton:    Color(hex: "#f2f2f7"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .water:
            return ThemePreset(
                background:    Color(hex: "#020e1e"),
                text:          Color(hex: "#cceeff"),
                secondaryText: Color(hex: "#4d8fa8"),
                accent:        Color(hex: "#2dd4bf"),
                tint:          Color(hex: "#2dd4bf"),
                gonioSides:    Color(hex: "#67e8f9"),
                gonioMids:     Color(hex: "#0ea5e9"),
                playButton:    Color(hex: "#cceeff"),
                useWaterShader: true,
                waterSpeed:    1.0,
                waterIntensity: 0.8
            )

        case .fog:
            return ThemePreset(
                background:    Color(hex: "#0d0f12"),
                text:          Color(hex: "#d8dce2"),
                secondaryText: Color(hex: "#6b7280"),
                accent:        Color(hex: "#9ca3af"),
                tint:          Color(hex: "#9ca3af"),
                gonioSides:    Color(hex: "#cbd5e1"),
                gonioMids:     Color(hex: "#94a3b8"),
                playButton:    Color(hex: "#d8dce2"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5,
                useFogShader: true,
                fogColor: Color(hex: "#c8d8e8"),
                fogSpeed: 0.55,
                fogIntensity: 1.0
            )

        case .mist:
            // Water caustics with a thin fog layer on top — underwater mist.
            return ThemePreset(
                background:    Color(hex: "#020a14"),
                text:          Color(hex: "#cceeff"),
                secondaryText: Color(hex: "#4d8fa8"),
                accent:        Color(hex: "#2dd4bf"),
                tint:          Color(hex: "#2dd4bf"),
                gonioSides:    Color(hex: "#67e8f9"),
                gonioMids:     Color(hex: "#0ea5e9"),
                playButton:    Color(hex: "#cceeff"),
                useWaterShader: true,
                waterSpeed: 0.8,
                waterIntensity: 0.6,
                useFogShader: true,
                fogColor: Color(hex: "#80c8f0"),
                fogSpeed: 0.35,
                fogIntensity: 0.55
            )

        case .tunnel:
            // Raymarched fractal tunnel. Shader ported from "RayMarching
            // starting point" by Martijn Steinrucken (The Art of Code /
            // BigWings), 2020, MIT License. Credit is also shown live in
            // SettingsView when this effect is enabled.
            return ThemePreset(
                background:    Color(hex: "#05070c"),
                text:          Color(hex: "#e2ecf7"),
                secondaryText: Color(hex: "#6d7a8f"),
                accent:        Color(hex: "#54a8ff"),
                tint:          Color(hex: "#54a8ff"),
                gonioSides:    Color(hex: "#8fd3ff"),
                gonioMids:     Color(hex: "#3d7fd9"),
                playButton:    Color(hex: "#e2ecf7"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5,
                useTunnelShader: true,
                tunnelColor: Color(hex: "#54a8ff"),
                tunnelSpeed: 1.0,
                tunnelIntensity: 1.0
            )

        case .tokyoNight:
            return ThemePreset(
                background:    Color(hex: "#1a1b26"),
                text:          Color(hex: "#c0caf5"),
                secondaryText: Color(hex: "#565f89"),
                accent:        Color(hex: "#7aa2f7"),
                tint:          Color(hex: "#7aa2f7"),
                gonioSides:    Color(hex: "#f7768e"),
                gonioMids:     Color(hex: "#bb9af7"),
                playButton:    Color(hex: "#c0caf5"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        // ── Light themes ─────────────────────────────────────────────────────

        case .minimalLight:
            return ThemePreset(
                background:    Color(hex: "#f5f5f5"),
                text:          Color(hex: "#1a1a1a"),
                secondaryText: Color(hex: "#888888"),
                accent:        Color(hex: "#7b6cd4"),
                tint:          Color(hex: "#7b6cd4"),
                gonioSides:    Color(hex: "#c9a8f5"),
                gonioMids:     Color(hex: "#7b6cd4"),
                playButton:    Color(hex: "#1a1a1a"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .atomLight:
            return ThemePreset(
                background:    Color(hex: "#fafafa"),
                text:          Color(hex: "#383a42"),
                secondaryText: Color(hex: "#a0a1a7"),
                accent:        Color(hex: "#4078f2"),
                tint:          Color(hex: "#4078f2"),
                gonioSides:    Color(hex: "#e45649"),
                gonioMids:     Color(hex: "#a626a4"),
                playButton:    Color(hex: "#383a42"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .ayuLight:
            return ThemePreset(
                background:    Color(hex: "#fafafa"),
                text:          Color(hex: "#5c6166"),
                secondaryText: Color(hex: "#abb0b6"),
                accent:        Color(hex: "#ff9940"),
                tint:          Color(hex: "#ff9940"),
                gonioSides:    Color(hex: "#f07171"),
                gonioMids:     Color(hex: "#a37acc"),
                playButton:    Color(hex: "#5c6166"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .catppuccinLight:
            return ThemePreset(
                background:    Color(hex: "#eff1f5"),
                text:          Color(hex: "#4c4f69"),
                secondaryText: Color(hex: "#9ca0b0"),
                accent:        Color(hex: "#8839ef"),
                tint:          Color(hex: "#8839ef"),
                gonioSides:    Color(hex: "#d20f39"),
                gonioMids:     Color(hex: "#1e66f5"),
                playButton:    Color(hex: "#4c4f69"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .einkLight:
            return ThemePreset(
                background:    Color(hex: "#f0f0f0"),
                text:          Color(hex: "#111111"),
                secondaryText: Color(hex: "#777777"),
                accent:        Color(hex: "#555555"),
                tint:          Color(hex: "#555555"),
                gonioSides:    Color(hex: "#333333"),
                gonioMids:     Color(hex: "#777777"),
                playButton:    Color(hex: "#111111"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .everforestLight:
            return ThemePreset(
                background:    Color(hex: "#fdf6e3"),
                text:          Color(hex: "#5c6a72"),
                secondaryText: Color(hex: "#a6b0a0"),
                accent:        Color(hex: "#8da101"),
                tint:          Color(hex: "#8da101"),
                gonioSides:    Color(hex: "#f85552"),
                gonioMids:     Color(hex: "#35a77c"),
                playButton:    Color(hex: "#5c6a72"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .flexokiLight:
            return ThemePreset(
                background:    Color(hex: "#fffcf0"),
                text:          Color(hex: "#100f0f"),
                secondaryText: Color(hex: "#ad8301"),
                accent:        Color(hex: "#ad8301"),
                tint:          Color(hex: "#ad8301"),
                gonioSides:    Color(hex: "#af3029"),
                gonioMids:     Color(hex: "#5e409d"),
                playButton:    Color(hex: "#100f0f"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .gruvboxLight:
            return ThemePreset(
                background:    Color(hex: "#fbf1c7"),
                text:          Color(hex: "#3c3836"),
                secondaryText: Color(hex: "#b57614"),
                accent:        Color(hex: "#b57614"),
                tint:          Color(hex: "#b57614"),
                gonioSides:    Color(hex: "#9d0006"),
                gonioMids:     Color(hex: "#79740e"),
                playButton:    Color(hex: "#3c3836"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .macosLight:
            return ThemePreset(
                background:    Color(hex: "#f5f5f5"),
                text:          Color(hex: "#1c1c1e"),
                secondaryText: Color(hex: "#007aff"),
                accent:        Color(hex: "#007aff"),
                tint:          Color(hex: "#007aff"),
                gonioSides:    Color(hex: "#ff3b30"),
                gonioMids:     Color(hex: "#34c759"),
                playButton:    Color(hex: "#1c1c1e"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .nordLight:
            return ThemePreset(
                background:    Color(hex: "#eceff4"),
                text:          Color(hex: "#2e3440"),
                secondaryText: Color(hex: "#5e81ac"),
                accent:        Color(hex: "#5e81ac"),
                tint:          Color(hex: "#5e81ac"),
                gonioSides:    Color(hex: "#bf616a"),
                gonioMids:     Color(hex: "#b48ead"),
                playButton:    Color(hex: "#2e3440"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .rosePineLight:
            return ThemePreset(
                background:    Color(hex: "#faf4ed"),
                text:          Color(hex: "#575279"),
                secondaryText: Color(hex: "#c84b4b"),
                accent:        Color(hex: "#c84b4b"),
                tint:          Color(hex: "#c84b4b"),
                gonioSides:    Color(hex: "#d95555"),
                gonioMids:     Color(hex: "#56949f"),
                playButton:    Color(hex: "#575279"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .skyLight:
            return ThemePreset(
                background:    Color(hex: "#cdd9e5"),
                text:          Color(hex: "#1b2433"),
                secondaryText: Color(hex: "#0969da"),
                accent:        Color(hex: "#0969da"),
                tint:          Color(hex: "#0969da"),
                gonioSides:    Color(hex: "#cf222e"),
                gonioMids:     Color(hex: "#1a7f37"),
                playButton:    Color(hex: "#1b2433"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .solarizedLight:
            return ThemePreset(
                background:    Color(hex: "#fdf6e3"),
                text:          Color(hex: "#657b83"),
                secondaryText: Color(hex: "#268bd2"),
                accent:        Color(hex: "#268bd2"),
                tint:          Color(hex: "#268bd2"),
                gonioSides:    Color(hex: "#dc322f"),
                gonioMids:     Color(hex: "#2aa198"),
                playButton:    Color(hex: "#657b83"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .thingsLight:
            return ThemePreset(
                background:    Color(hex: "#f2f2f7"),
                text:          Color(hex: "#1c1c1e"),
                secondaryText: Color(hex: "#4f8ef7"),
                accent:        Color(hex: "#4f8ef7"),
                tint:          Color(hex: "#4f8ef7"),
                gonioSides:    Color(hex: "#ff6b6b"),
                gonioMids:     Color(hex: "#5ac8fa"),
                playButton:    Color(hex: "#1c1c1e"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )

        case .tokyoDay:
            return ThemePreset(
                background:    Color(hex: "#e1e2e7"),
                text:          Color(hex: "#1f2335"),
                secondaryText: Color(hex: "#737aa2"),
                accent:        Color(hex: "#2e7de9"),
                tint:          Color(hex: "#2e7de9"),
                gonioSides:    Color(hex: "#f52a65"),
                gonioMids:     Color(hex: "#7847bd"),
                playButton:    Color(hex: "#1f2335"),
                useWaterShader: false,
                waterSpeed: 1.0, waterIntensity: 0.5
            )
        }
    }
}

// MARK: - Hex colour helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case light = "Light"
    case dark  = "Dark"
}

// MARK: - UserDefaults Keys

private enum ThemeKey {
    static let backgroundColor    = "theme.backgroundColor"
    static let textColor          = "theme.textColor"
    static let secondaryTextColor = "theme.secondaryTextColor"
    static let accentColor        = "theme.accentColor"
    static let tint               = "theme.tint"
    static let gonioSidesColor    = "theme.gonioSidesColor"
    static let gonioMidsColor     = "theme.gonioMidsColor"
    static let playButtonColor    = "theme.playButtonColor"
    // Water
    static let useWaterShader     = "theme.useWaterShader"
    static let waterSpeed         = "theme.waterSpeed"
    static let waterIntensity     = "theme.waterIntensity"
    static let waterQuality       = "theme.waterQuality"
    // Fog
    static let useFogShader       = "theme.useFogShader"
    static let fogColor           = "theme.fogColor"
    static let fogSpeed           = "theme.fogSpeed"
    static let fogIntensity       = "theme.fogIntensity"
    // Tunnel
    static let useTunnelShader    = "theme.useTunnelShader"
    static let tunnelColor        = "theme.tunnelColor"
    static let tunnelSpeed        = "theme.tunnelSpeed"
    static let tunnelIntensity    = "theme.tunnelIntensity"
    static let tunnelQuality      = "theme.tunnelQuality"
    static let tunnelGrainStrength = "theme.tunnelGrainStrength"
    // Smoke
    static let useSmokeShader     = "theme.useSmokeShader"
    static let smokeSpeed         = "theme.smokeSpeed"
    static let smokeIntensity     = "theme.smokeIntensity"
    static let smokeGrayscale     = "theme.smokeGrayscale"
    // Appearance
    static let appearanceMode     = "theme.appearanceMode"
    static let selectedDarkTheme  = "theme.selectedDarkTheme"
    static let selectedLightTheme = "theme.selectedLightTheme"
}

// MARK: - Color ↔ UserDefaults helpers

private extension Color {
    var hexString: String {
        let resolved = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(r * 255), gi = Int(g * 255), bi = Int(b * 255)
        return String(format: "#%02x%02x%02x", ri, gi, bi)
    }
}

// MARK: - ThemeManager

final class ThemeManager: ObservableObject {

    // ── Published colours ────────────────────────────────────────────────────

    @Published var backgroundColor: Color {
        didSet { save(backgroundColor.hexString, for: ThemeKey.backgroundColor) }
    }
    @Published var textColor: Color {
        didSet { save(textColor.hexString, for: ThemeKey.textColor) }
    }
    @Published var secondaryTextColor: Color {
        didSet { save(secondaryTextColor.hexString, for: ThemeKey.secondaryTextColor) }
    }
    @Published var accentColor: Color {
        didSet { save(accentColor.hexString, for: ThemeKey.accentColor) }
    }
    @Published var tint: Color {
        didSet { save(tint.hexString, for: ThemeKey.tint) }
    }
    @Published var gonioSidesColor: Color {
        didSet { save(gonioSidesColor.hexString, for: ThemeKey.gonioSidesColor) }
    }
    @Published var gonioMidsColor: Color {
        didSet { save(gonioMidsColor.hexString, for: ThemeKey.gonioMidsColor) }
    }
    @Published var playButtonColor: Color {
        didSet { save(playButtonColor.hexString, for: ThemeKey.playButtonColor) }
    }

    // ── Water shader ─────────────────────────────────────────────────────────

    @Published var useWaterShader: Bool {
        didSet { UserDefaults.standard.set(useWaterShader, forKey: ThemeKey.useWaterShader) }
    }
    @Published var waterSpeed: Double {
        didSet { UserDefaults.standard.set(waterSpeed, forKey: ThemeKey.waterSpeed) }
    }
    @Published var waterIntensity: Double {
        didSet { UserDefaults.standard.set(waterIntensity, forKey: ThemeKey.waterIntensity) }
    }
    @Published var waterQuality: WaterQuality {
        didSet { UserDefaults.standard.set(waterQuality.rawValue, forKey: ThemeKey.waterQuality) }
    }

    // Fixed water tint — not user-configurable.
    let waterColor: Color = Color(hex: "#2A7FAA")

    // ── Fog shader ───────────────────────────────────────────────────────────

    @Published var useFogShader: Bool {
        didSet { UserDefaults.standard.set(useFogShader, forKey: ThemeKey.useFogShader) }
    }
    @Published var fogColor: Color {
        didSet { save(fogColor.hexString, for: ThemeKey.fogColor) }
    }
    @Published var fogSpeed: Double {
        didSet { UserDefaults.standard.set(fogSpeed, forKey: ThemeKey.fogSpeed) }
    }
    @Published var fogIntensity: Double {
        didSet { UserDefaults.standard.set(fogIntensity, forKey: ThemeKey.fogIntensity) }
    }

    // ── Tunnel shader ────────────────────────────────────────────────────────
    // Raymarched fractal tunnel, ported from "RayMarching starting point" by
    // Martijn Steinrucken (The Art of Code / BigWings), 2020, MIT License.

    @Published var useTunnelShader: Bool {
        didSet { UserDefaults.standard.set(useTunnelShader, forKey: ThemeKey.useTunnelShader) }
    }
    @Published var tunnelColor: Color {
        didSet { save(tunnelColor.hexString, for: ThemeKey.tunnelColor) }
    }
    @Published var tunnelSpeed: Double {
        didSet { UserDefaults.standard.set(tunnelSpeed, forKey: ThemeKey.tunnelSpeed) }
    }
    @Published var tunnelIntensity: Double {
        didSet { UserDefaults.standard.set(tunnelIntensity, forKey: ThemeKey.tunnelIntensity) }
    }
    @Published var tunnelQuality: TunnelQuality {
        didSet { UserDefaults.standard.set(tunnelQuality.rawValue, forKey: ThemeKey.tunnelQuality) }
    }
    /// Strength of the full-resolution blue-noise grain pass applied after
    /// upscaling — separate from the internal march-dithering, since this one
    /// is meant to be pushed harder without reintroducing blockiness.
    @Published var tunnelGrainStrength: Double {
        didSet { UserDefaults.standard.set(tunnelGrainStrength, forKey: ThemeKey.tunnelGrainStrength) }
    }

    // ── Smoke shader ─────────────────────────────────────────────────────────
    // Colormap-warp effect used behind SpectrumView.

    @Published var useSmokeShader: Bool {
        didSet { UserDefaults.standard.set(useSmokeShader, forKey: ThemeKey.useSmokeShader) }
    }
    @Published var smokeSpeed: Double {
        didSet { UserDefaults.standard.set(smokeSpeed, forKey: ThemeKey.smokeSpeed) }
    }
    @Published var smokeIntensity: Double {
        didSet { UserDefaults.standard.set(smokeIntensity, forKey: ThemeKey.smokeIntensity) }
    }
    @Published var smokeGrayscale: Double {
        didSet { UserDefaults.standard.set(smokeGrayscale, forKey: ThemeKey.smokeGrayscale) }
    }

    // ── Appearance / selected themes ─────────────────────────────────────────

    @Published var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: ThemeKey.appearanceMode) }
    }
    @Published var selectedDarkTheme: AppTheme {
        didSet { UserDefaults.standard.set(selectedDarkTheme.rawValue, forKey: ThemeKey.selectedDarkTheme) }
    }
    @Published var selectedLightTheme: AppTheme {
        didSet { UserDefaults.standard.set(selectedLightTheme.rawValue, forKey: ThemeKey.selectedLightTheme) }
    }

    // ── Init: load from UserDefaults, fall back to Nord ─────────────────────

    init() {
        let ud = UserDefaults.standard
        let nordPreset = AppTheme.nord.preset

        backgroundColor    = Self.loadColor(ud, key: ThemeKey.backgroundColor,    default: nordPreset.background)
        textColor          = Self.loadColor(ud, key: ThemeKey.textColor,           default: nordPreset.text)
        secondaryTextColor = Self.loadColor(ud, key: ThemeKey.secondaryTextColor,  default: nordPreset.secondaryText)
        accentColor        = Self.loadColor(ud, key: ThemeKey.accentColor,         default: nordPreset.accent)
        tint               = Self.loadColor(ud, key: ThemeKey.tint,                default: nordPreset.tint)
        gonioSidesColor    = Self.loadColor(ud, key: ThemeKey.gonioSidesColor,     default: nordPreset.gonioSides)
        gonioMidsColor     = Self.loadColor(ud, key: ThemeKey.gonioMidsColor,      default: nordPreset.gonioMids)
        playButtonColor    = Self.loadColor(ud, key: ThemeKey.playButtonColor,     default: nordPreset.playButton)

        useWaterShader  = ud.object(forKey: ThemeKey.useWaterShader) as? Bool   ?? nordPreset.useWaterShader
        waterSpeed      = ud.object(forKey: ThemeKey.waterSpeed)     as? Double ?? nordPreset.waterSpeed
        waterIntensity  = ud.object(forKey: ThemeKey.waterIntensity) as? Double ?? nordPreset.waterIntensity
        if let raw = ud.string(forKey: ThemeKey.waterQuality), let q = WaterQuality(rawValue: raw) {
            waterQuality = q
        } else {
            waterQuality = nordPreset.waterQuality
        }

        useFogShader    = ud.object(forKey: ThemeKey.useFogShader)   as? Bool   ?? nordPreset.useFogShader
        fogColor        = Self.loadColor(ud, key: ThemeKey.fogColor,             default: nordPreset.fogColor)
        fogSpeed        = ud.object(forKey: ThemeKey.fogSpeed)       as? Double ?? nordPreset.fogSpeed
        fogIntensity    = ud.object(forKey: ThemeKey.fogIntensity)   as? Double ?? nordPreset.fogIntensity

        useTunnelShader = ud.object(forKey: ThemeKey.useTunnelShader) as? Bool   ?? nordPreset.useTunnelShader
        tunnelColor     = Self.loadColor(ud, key: ThemeKey.tunnelColor,          default: nordPreset.tunnelColor)
        tunnelSpeed     = ud.object(forKey: ThemeKey.tunnelSpeed)     as? Double ?? nordPreset.tunnelSpeed
        tunnelIntensity = ud.object(forKey: ThemeKey.tunnelIntensity) as? Double ?? nordPreset.tunnelIntensity
        if let raw = ud.string(forKey: ThemeKey.tunnelQuality), let q = TunnelQuality(rawValue: raw) {
            tunnelQuality = q
        } else {
            tunnelQuality = nordPreset.tunnelQuality
        }
        tunnelGrainStrength = ud.object(forKey: ThemeKey.tunnelGrainStrength) as? Double ?? nordPreset.tunnelGrainStrength

        useSmokeShader  = ud.object(forKey: ThemeKey.useSmokeShader) as? Bool   ?? nordPreset.useSmokeShader
        smokeSpeed      = ud.object(forKey: ThemeKey.smokeSpeed)     as? Double ?? nordPreset.smokeSpeed
        smokeIntensity  = ud.object(forKey: ThemeKey.smokeIntensity) as? Double ?? nordPreset.smokeIntensity
        smokeGrayscale  = ud.object(forKey: ThemeKey.smokeGrayscale) as? Double ?? nordPreset.smokeGrayscale

        if let raw = ud.string(forKey: ThemeKey.appearanceMode),
           let mode = AppearanceMode(rawValue: raw) {
            appearanceMode = mode
        } else {
            appearanceMode = .dark
        }

        if let raw = ud.string(forKey: ThemeKey.selectedDarkTheme),
           let t = AppTheme(rawValue: raw) {
            selectedDarkTheme = t
        } else {
            selectedDarkTheme = .nord
        }

        if let raw = ud.string(forKey: ThemeKey.selectedLightTheme),
           let t = AppTheme(rawValue: raw) {
            selectedLightTheme = t
        } else {
            selectedLightTheme = .rosePineLight
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    func apply(_ appTheme: AppTheme) {
        let p = appTheme.preset
        backgroundColor    = p.background
        textColor          = p.text
        secondaryTextColor = p.secondaryText
        accentColor        = p.accent
        tint               = p.tint
        gonioSidesColor    = p.gonioSides
        gonioMidsColor     = p.gonioMids
        playButtonColor    = p.playButton
        useWaterShader     = p.useWaterShader
        if p.useWaterShader {
            waterSpeed     = p.waterSpeed
            waterIntensity = p.waterIntensity
            waterQuality   = p.waterQuality
        }
        useFogShader       = p.useFogShader
        if p.useFogShader {
            fogColor       = p.fogColor
            fogSpeed       = p.fogSpeed
            fogIntensity   = p.fogIntensity
        }
        useTunnelShader    = p.useTunnelShader
        if p.useTunnelShader {
            tunnelColor         = p.tunnelColor
            tunnelSpeed         = p.tunnelSpeed
            tunnelIntensity     = p.tunnelIntensity
            tunnelQuality       = p.tunnelQuality
            tunnelGrainStrength = p.tunnelGrainStrength
        }
        useSmokeShader     = p.useSmokeShader
        if p.useSmokeShader {
            smokeSpeed      = p.smokeSpeed
            smokeIntensity  = p.smokeIntensity
            smokeGrayscale  = p.smokeGrayscale
        }
        if AppTheme.darkThemes.contains(appTheme) {
            selectedDarkTheme  = appTheme
        } else {
            selectedLightTheme = appTheme
        }
    }

    func applyActiveTheme() {
        apply(appearanceMode == .dark ? selectedDarkTheme : selectedLightTheme)
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private func save(_ hex: String, for key: String) {
        UserDefaults.standard.set(hex, forKey: key)
    }

    private static func loadColor(_ ud: UserDefaults, key: String, default fallback: Color) -> Color {
        guard let hex = ud.string(forKey: key) else { return fallback }
        return Color(hex: hex)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        ZStack {
            // Live animated background — shows exactly what the rest of the
            // app sees, including water and/or fog if either is enabled.
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    themePreview
                    themeSelectorsSection
                    waterShaderSection
                    tunnelShaderSection
                    fogShaderSection
                    smokeShaderSection
                }
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Theme Preview

    private var themePreview: some View {
        VStack(spacing: 14) {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(theme.textColor)

            HStack(spacing: 12) {
                previewSwatch("Background",  theme.backgroundColor)
                previewSwatch("Text",        theme.textColor)
                previewSwatch("Secondary",   theme.secondaryTextColor)
                previewSwatch("Accent",      theme.accentColor)
            }
            HStack(spacing: 12) {
                previewSwatch("Tint",        theme.tint)
                previewSwatch("Sides",       theme.gonioSidesColor)
                previewSwatch("Mids",        theme.gonioMidsColor)
                previewSwatch("Play",        theme.playButtonColor)
            }

            // Badge row showing active effects
            if theme.useWaterShader || theme.useFogShader {
                HStack(spacing: 8) {
                    if theme.useWaterShader {
                        Label("Water", systemImage: "drop.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(hex: "#2dd4bf"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#2dd4bf").opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if theme.useFogShader {
                        Label("Fog", systemImage: "cloud.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.fogColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(theme.fogColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if theme.useTunnelShader {
                        Label("Tunnel", systemImage: "tornado")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.tunnelColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(theme.tunnelColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.backgroundColor.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(theme.textColor.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: theme.useWaterShader)
        .animation(.easeInOut(duration: 0.2), value: theme.useFogShader)
        .animation(.easeInOut(duration: 0.2), value: theme.useTunnelShader)
    }

    private func previewSwatch(_ label: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 36)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Theme Selectors

    private var themeSelectorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Colour Scheme")
                .font(.headline)
                .foregroundStyle(theme.textColor)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 6) {
                Text("Appearance")
                    .font(.subheadline)
                    .foregroundStyle(theme.textColor.opacity(0.7))
                    .padding(.horizontal)

                Picker("Appearance", selection: $theme.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: theme.appearanceMode) { _, _ in
                    theme.applyActiveTheme()
                }
            }

            VStack(spacing: 12) {
                if theme.appearanceMode == .dark {
                    themeDropdown(
                        label: "Dark Theme",
                        selected: theme.selectedDarkTheme,
                        options: AppTheme.darkThemes,
                        onSelect: { theme.apply($0) }
                    )
                } else {
                    themeDropdown(
                        label: "Light Theme",
                        selected: theme.selectedLightTheme,
                        options: AppTheme.lightThemes,
                        onSelect: { theme.apply($0) }
                    )
                }
            }
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.15), value: theme.appearanceMode)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.backgroundColor.opacity(0.2))
        )
        .padding(.horizontal)
    }

    private func themeDropdown(
        label: String,
        selected: AppTheme,
        options: [AppTheme],
        onSelect: @escaping (AppTheme) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.textColor.opacity(0.7))

            Menu {
                ForEach(options) { option in
                    Button(option.rawValue) { onSelect(option) }
                }
            } label: {
                HStack {
                    Circle()
                        .fill(selected.preset.background)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().strokeBorder(theme.textColor.opacity(0.2), lineWidth: 1)
                        )
                    Text(selected.rawValue)
                        .font(.body)
                        .foregroundStyle(theme.textColor)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(theme.textColor.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.backgroundColor.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(theme.textColor.opacity(0.12), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Water Shader Section

    private var waterShaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Water Effect")
                        .font(.headline)
                        .foregroundStyle(theme.textColor)
                    Text("Uses the current background colour")
                        .font(.caption)
                        .foregroundStyle(theme.textColor.opacity(0.5))
                }
                Spacer()
                Toggle("", isOn: $theme.useWaterShader)
                    .tint(theme.accentColor)
                    .labelsHidden()
            }

            if theme.useWaterShader {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quality")
                        .font(.subheadline)
                        .foregroundStyle(theme.textColor.opacity(0.7))
                    Picker("Quality", selection: $theme.waterQuality) {
                        ForEach(WaterQuality.allCases) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(spacing: 14) {
                    sliderRow(label: "Speed",     value: $theme.waterSpeed,     range: 0.1...3.0, format: "%.1fx")
                    sliderRow(label: "Intensity", value: $theme.waterIntensity, range: 0.1...2.0, format: "%.1f")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                Text("Lower quality renders at a smaller resolution with a lighter raymarch budget — much easier on the GPU and battery. \"Low\" automatically applies when Low Power Mode is on.")
                    .font(.caption2)
                    .foregroundStyle(theme.textColor.opacity(0.4))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.backgroundColor.opacity(0.2))
        )
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: theme.useWaterShader)
    }

    // MARK: - Tunnel Shader Section

    private var tunnelShaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tunnel Effect")
                        .font(.headline)
                        .foregroundStyle(theme.textColor)
                    Text("Raymarched fractal tunnel")
                        .font(.caption)
                        .foregroundStyle(theme.textColor.opacity(0.5))
                }
                Spacer()
                Toggle("", isOn: $theme.useTunnelShader)
                    .tint(theme.accentColor)
                    .labelsHidden()
            }

            if theme.useTunnelShader {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quality")
                        .font(.subheadline)
                        .foregroundStyle(theme.textColor.opacity(0.7))
                    Picker("Quality", selection: $theme.tunnelQuality) {
                        ForEach(TunnelQuality.allCases) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(spacing: 14) {
                    sliderRow(label: "Speed",     value: $theme.tunnelSpeed,     range: 0.1...3.0, format: "%.1fx")
                    sliderRow(label: "Intensity", value: $theme.tunnelIntensity, range: 0.1...2.0, format: "%.1f")
                    sliderRow(label: "Grain",     value: $theme.tunnelGrainStrength, range: 0.0...0.4, format: "%.2f")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                Text("Lower quality renders at a smaller resolution with a lighter raymarch budget — much easier on the GPU and battery. \"Low\" automatically applies when Low Power Mode is on.")
                    .font(.caption2)
                    .foregroundStyle(theme.textColor.opacity(0.4))
            }

            // Attribution — required by the shader's MIT License and shown
            // here regardless of whether the effect is currently enabled.
            Text("Shader based on \"RayMarching starting point\" by Martijn Steinrucken (The Art of Code / BigWings), MIT License.")
                .font(.caption2)
                .foregroundStyle(theme.textColor.opacity(0.4))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.backgroundColor.opacity(0.2))
        )
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: theme.useTunnelShader)
    }

    // MARK: - Fog Shader Section

    private var fogShaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fog Effect")
                        .font(.headline)
                        .foregroundStyle(theme.textColor)
                    Text("PS2-style depth fog with Bayer dithering")
                        .font(.caption)
                        .foregroundStyle(theme.textColor.opacity(0.5))
                }
                Spacer()
                Toggle("", isOn: $theme.useFogShader)
                    .tint(theme.accentColor)
                    .labelsHidden()
            }

            if theme.useFogShader {
                VStack(spacing: 14) {
                    sliderRow(label: "Density", value: $theme.fogIntensity, range: 0.1...2.0, format: "%.1f")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.backgroundColor.opacity(0.2))
        )
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: theme.useFogShader)
    }

    // MARK: - Smoke Shader Section
    //
    // Colormap-warp fBM effect (see ColormapWarp.metal) rendered behind the
    // SpectrumView audio visualizer, not as an AppBackground layer — so it
    // doesn't get a badge in themePreview like Water/Fog/Tunnel, which are
    // all full-screen backdrops.

    private var smokeShaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smoke Effect")
                        .font(.headline)
                        .foregroundStyle(theme.textColor)
                    Text("Colormap-warp fBM behind the spectrum view")
                        .font(.caption)
                        .foregroundStyle(theme.textColor.opacity(0.5))
                }
                Spacer()
                Toggle("", isOn: $theme.useSmokeShader)
                    .tint(theme.accentColor)
                    .labelsHidden()
            }

            if theme.useSmokeShader {
                VStack(spacing: 14) {
                    sliderRow(label: "Speed",     value: $theme.smokeSpeed,     range: 0.1...3.0, format: "%.1fx")
                    sliderRow(label: "Intensity", value: $theme.smokeIntensity, range: 0.0...1.0, format: "%.1f")
                    sliderRow(label: "Grayscale", value: $theme.smokeGrayscale, range: 0.0...1.0, format: "%.1f")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.backgroundColor.opacity(0.2))
        )
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: theme.useSmokeShader)
    }

    // MARK: - Shared slider helper

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(theme.textColor)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.textColor.opacity(0.6))
            }
            Slider(value: value, in: range)
                .tint(theme.accentColor)
        }
    }
}
