#if DEBUG
    import SwiftUI

    /// Backlog is cold, This week is warm, Today is hot and sits on its own stage (DESIGN_SYSTEM §2.5).
    struct TemperatureSection: View {
        var body: some View {
            GallerySection(label: "TIME TEMPERATURE · COLUMN IDENTITIES") {
                WeightedHStack(weights: Layout.columnWeights, spacing: Space.columnGutter) {
                    ColdColumn(
                        tint: Palette.violet, iconText: Palette.violetText, symbol: "moon",
                        bar: [.clear, Palette.violet, Palette.violet, .clear],
                        title: "Backlog · Cold", subtitle: "Someday. Parked, quiet.",
                        detail: "Violet 3pt top bar, 18% ambient, titles in textBody, violet hover light. "
                            + "Icon: moon. Width 1fr.",
                        ambientOpacity: 0.2)
                    ColdColumn(
                        tint: Palette.blue, iconText: Palette.blueText, symbol: "calendar",
                        bar: [.clear, Palette.blue, Palette.cyan, .clear],
                        title: "This week · Warm", subtitle: "Planned. Week strip on top.",
                        detail: "Blue to cyan bar, 20% ambient, dated chips in blue, 7-day load strip with today "
                            + "ringed lime. Width 1.06fr.",
                        ambientOpacity: 0.22)
                    TodayStage()
                }
            }
        }
    }

    private struct ColdColumn: View {
        var tint: Color
        var iconText: Color
        var symbol: String
        var bar: [Color]
        var title: String
        var subtitle: String
        var detail: String
        var ambientOpacity: Double

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.column, style: .continuous)
            let iconShape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconText)
                        .frame(width: 36, height: 36)
                        .background(tint.opacity(0.16), in: iconShape)
                        .overlay(iconShape.strokeBorder(tint.opacity(0.34), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(Typography.heading).foregroundStyle(Palette.textPrimary)
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.textMuted)
                    }
                }
                Text(detail).font(.system(size: 12.5)).lineSpacing(4).foregroundStyle(Palette.textSecondary)
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .spotlight(tint, radius: Radius.column, lifts: false) {
                ZStack(alignment: .top) {
                    shape.fill(Palette.panel)
                    EllipticalGradient(
                        stops: [
                            .init(color: tint.opacity(ambientOpacity), location: 0),
                            .init(color: .clear, location: 0.7),
                        ],
                        center: UnitPoint(x: 0.5, y: -0.3), endRadiusFraction: 1.4
                    )
                    .clipShape(shape)
                    LinearGradient(colors: bar, startPoint: .leading, endPoint: .trailing)
                        .frame(height: 3)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipShape(shape)
                    shape.strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                }
            }
        }
    }

    private struct TodayStage: View {
        private static let borderWidth: CGFloat = 1.5

        var body: some View {
            let inner = RoundedRectangle(cornerRadius: Radius.stage - Self.borderWidth, style: .continuous)
            let outer = RoundedRectangle(cornerRadius: Radius.stage, style: .continuous)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(
                                colors: [Palette.teal, Palette.lime], startPoint: .topLeading,
                                endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .shadow(color: Palette.lime.opacity(0.6), radius: 10, y: 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today · Hot")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Palette.textPrimary)
                        Text("Now. A raised stage, 1.52× wider.")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textMuted)
                    }
                }
                Text(
                    "Its own material: gradient border, drifting aurora, outer glow. Hosts the day meter, the live "
                        + "card with the focus dial and beam, and the Focus queue. The 18pt gutter plus the stage "
                        + "border is the separation from This week."
                )
                .font(.system(size: 12.5))
                .lineSpacing(4)
                .foregroundStyle(Palette.textSecondary)
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .spotlight(SpotlightTint.today, radius: Radius.stage - Self.borderWidth, lifts: false) {
                ZStack {
                    inner.fill(Palette.panel)
                    EllipticalGradient(
                        stops: [
                            .init(color: Palette.teal.opacity(0.26), location: 0),
                            .init(color: .clear, location: 0.7),
                        ],
                        center: UnitPoint(x: 0.3, y: -0.3), endRadiusFraction: 1.4
                    )
                    .clipShape(inner)
                }
            }
            .padding(Self.borderWidth)
            .background {
                outer.fill(
                    LinearGradient(
                        stops: [
                            .init(color: Palette.teal.opacity(0.75), location: 0),
                            .init(color: Palette.lime.opacity(0.45), location: 0.3),
                            .init(color: .white.opacity(0.06), location: 0.6),
                            .init(color: Palette.lime.opacity(0.25), location: 1),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: Palette.lime.opacity(0.3), radius: 40)
            }
        }
    }

    #Preview("Time temperature") {
        TemperatureSection()
            .padding(64)
            .frame(width: GalleryCanvas.width)
            .background(Palette.bg)
    }
#endif
