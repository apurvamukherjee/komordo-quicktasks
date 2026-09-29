import KomodoCore
import SwiftUI

/// Celebration (Settings.dc.html): what plays on Done, with a small version of the moment that Preview replays.
struct SettingsCelebrationPage: View {
    @Bindable var store: BoardStore

    @State private var plays = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                SettingsGroup(title: "WHEN YOU FINISH A TASK") {
                    SettingsRow(
                        "Success screen", detail: "A big check and a line about how you did.",
                        isOn: $store.settings.showsSuccessScreen)
                    SettingsRow(
                        "Fun GIF", detail: "A random GIF on the success screen.", isOn: $store.settings.showsGIF)
                    SettingsRow(
                        "Success sound", detail: "A short chime on Done.", isOn: $store.settings.playsSuccessSound)
                    SettingsRow("Try it", detail: "Plays the moment with your current choices.") {
                        Button {
                            plays += 1
                            if store.settings.playsSuccessSound {
                                KomodoSound.playSuccess(volume: store.settings.volume)
                            }
                        } label: {
                            Label("Preview", systemImage: "party.popper")
                        }
                        .buttonStyle(KomodoButtonStyle(kind: .secondary, size: .small))
                    }
                }
                CelebrationPreview(
                    plays: plays, isOn: store.settings.showsSuccessScreen, showsGIF: store.settings.showsGIF,
                    playsSound: store.settings.playsSuccessSound
                )
                .frame(width: 300)
                .padding(.top, 38)
            }
            Text(
                store.settings.showsSuccessScreen
                    ? "Shown in the Focus Panel for about 2 seconds, then the next task starts."
                    : "Success screen is off: finishing a task goes straight to the next one."
            )
            .font(.system(size: 12))
            .foregroundStyle(Palette.textMuted)
            .padding(.horizontal, Space.s1)
            .padding(.top, 10)
        }
        .environment(\.settingsTint, Palette.amber)
    }
}

/// `.st-cel`: the check, the GIF's place and the sound line inside the celebration's rainbow edge. Each Preview
/// rebuilds it so the pop and confetti play again.
private struct CelebrationPreview: View {
    var plays: Int
    var isOn: Bool
    var showsGIF: Bool
    var playsSound: Bool

    @State private var hasPlayed = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14.5, style: .continuous)
        ZStack {
            if !reduceMotion, plays > 0 {
                CelebrationBurst(hasPlayed: hasPlayed, isHero: false)
            }
            VStack(spacing: Space.s2) {
                HStack(spacing: Space.s3) {
                    CelebrationCheck(hasPlayed: hasPlayed, side: 52, isStill: reduceMotion)
                    if showsGIF {
                        Text("GIF")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Palette.textMuted)
                            .frame(width: 84, height: 52)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3]))
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text("Nailed it. 12min early.")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(Palette.textPrimary)
                Group {
                    if playsSound {
                        Label("Success sound", systemImage: "speaker.wave.1.fill").foregroundStyle(Palette.limeText)
                    } else {
                        Text("Silent").foregroundStyle(Palette.textSecondary)
                    }
                }
                .font(.system(size: 11.5))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 187)
        .background {
            ZStack {
                Palette.panel
                EllipticalGradient(
                    colors: [Palette.lime.opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0.3),
                    startRadiusFraction: 0, endRadiusFraction: 0.7)
            }
        }
        .clipShape(shape)
        .padding(1.5)
        .background(
            LinearGradient(
                colors: [Palette.teal, Palette.lime, Palette.amber, Palette.pink, Palette.violet],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: Palette.lime.opacity(0.6), radius: 20)
        .saturation(isOn ? 1 : 0)
        .opacity(isOn ? 1 : 0.45)
        .animation(Motion.base, value: isOn)
        .animation(Motion.spring, value: showsGIF)
        .onChange(of: plays) {
            hasPlayed = false
            Task {
                // One frame at rest so the pop has somewhere to start from.
                try? await Task.sleep(for: .milliseconds(30))
                hasPlayed = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Celebration") {
    SettingsCelebrationPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .padding(28)
        .frame(width: 864)
        .background(Palette.bg)
}
