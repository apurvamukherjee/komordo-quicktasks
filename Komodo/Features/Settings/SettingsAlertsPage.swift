import KomodoCore
import SwiftUI

/// Alerts & sounds (Settings.dc.html): the timed nudge while a task is live, then reminders and the volume every
/// Komodo sound plays at.
struct SettingsAlertsPage: View {
    @Bindable var store: BoardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "TIMED ALERTS") {
                SettingsRow(
                    "Timed alerts during a task", detail: "A soft nudge on a fixed interval while a task is live.",
                    isOn: $store.settings.timedAlerts)
                Group {
                    SettingsRow("Every", isIndented: true) {
                        SettingsMenuPicker(
                            title: "Every", selection: $store.settings.timedAlertInterval,
                            options: AppSettings.timedAlertIntervals.map { ($0, "\(Int($0 / 60)) min") })
                    }
                    SettingsRow("Sound", isIndented: true) {
                        soundPicker("Sound", selection: $store.settings.timedAlertSound)
                        SoundPreviewButton(title: "Preview alert sound") {
                            store.settings.timedAlertSound.play(volume: store.settings.volume)
                        }
                    }
                    SettingsRow(
                        "Pulse timer", detail: "The timer glows once with each alert.", isIndented: true,
                        isOn: $store.settings.pulsesTimer)
                }
                .opacity(store.settings.timedAlerts ? 1 : 0.4)
                .disabled(!store.settings.timedAlerts)
            }
            SettingsGroup(title: "REMINDERS") {
                SettingsRow("Reminder sound", detail: "For scheduled tasks and meetings.") {
                    soundPicker("Reminder sound", selection: $store.settings.reminderSound)
                    SoundPreviewButton(title: "Preview reminder sound") {
                        store.settings.reminderSound.play(volume: store.settings.volume)
                    }
                }
                SettingsRow("Volume", detail: "For every Komodo sound.") {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textMuted)
                    VolumeSlider(volume: $store.settings.volume)
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textMuted)
                    Text("\(Int((store.settings.volume * 100).rounded()))%")
                        .font(.system(size: 12.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(Palette.limeText)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }

    private func soundPicker(_ title: String, selection: Binding<KomodoSound>) -> some View {
        SettingsMenuPicker(title: title, selection: selection, options: KomodoSound.allCases.map { ($0, $0.title) })
    }
}

/// `.st-range`: a 210 pt teal-to-lime track under a white thumb.
private struct VolumeSlider: View {
    @Binding var volume: Double

    private static let width: CGFloat = 210
    private static let thumb: CGFloat = 18

    var body: some View {
        let travel = Self.width - Self.thumb
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.1))
            Capsule()
                .fill(LinearGradient(colors: [Palette.teal, Palette.lime], startPoint: .leading, endPoint: .trailing))
                .frame(width: Self.thumb / 2 + travel * volume)
                .shadow(color: Palette.lime.opacity(0.5), radius: 7)
        }
        .frame(width: Self.width, height: 6)
        .overlay(alignment: .leading) {
            Circle()
                .fill(.white)
                .frame(width: Self.thumb, height: Self.thumb)
                .background(Circle().fill(Palette.lime.opacity(0.2)).padding(-4))
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .offset(x: travel * volume)
        }
        .frame(height: Self.thumb + 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0).onChanged { value in
                volume = min(1, max(0, (value.location.x - Self.thumb / 2) / travel))
            }
        )
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int((volume * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            volume = min(1, max(0, volume + (direction == .increment ? 0.1 : -0.1)))
        }
    }
}

#Preview("Alerts & sounds") {
    SettingsAlertsPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .padding(28)
        .frame(width: 864)
        .background(Palette.bg)
}
