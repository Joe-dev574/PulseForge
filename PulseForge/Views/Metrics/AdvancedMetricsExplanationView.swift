//
//  AdvancedMetricsExplanationView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/21/26.
//
//  Apple App Store Compliance (required for review):
//  - Explains premium metrics shown in JournalEntryView and ProgressBoardView.
//  - No data collection or HealthKit access — purely informational.
//  - Full VoiceOver accessibility with clear headers and dynamic type support.
//  - Consistent with app-wide theming and dark mode.
//  - Used as a popover/sheet for user education.
//

import SwiftUI

/// Reusable sheet explaining the exact calculation and fitness context of each
/// premium metric: Intensity Score, Progress Pulse, and Dominant Zone.
struct AdvancedMetricsExplanationView: View {

    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"

    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader
                intensityCard
                progressPulseCard
                dominantZoneCard
                footerNote
            }
            .padding(20)
            .padding(.bottom, 8)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(themeColor)
                Text("Advanced Metrics")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            Text("Understand exactly how each score is calculated and what it means for your training progress.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Intensity Score Card

    private var intensityCard: some View {
        MetricCard(accent: .orange) {
            MetricCardHeader(
                icon: "flame.fill",
                title: "Intensity Score",
                badge: "0 – 100%",
                color: .orange
            )

            MetricSectionLabel("HOW IT'S CALCULATED")

            VStack(alignment: .leading, spacing: 10) {
                Text("Uses the **Heart Rate Reserve** method — the gold-standard for measuring true cardiovascular effort:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                FormulaView(
                    numerator: "Avg HR  −  Resting HR",
                    denominator: "Max HR  −  Resting HR",
                    multiplier: "× 100"
                )

                VStack(alignment: .leading, spacing: 6) {
                    FormulaTermRow(term: "Avg HR", definition: "Average heart rate during your session (from HealthKit)")
                    FormulaTermRow(term: "Resting HR", definition: "Your resting heart rate (from HealthKit)")
                    FormulaTermRow(term: "Max HR", definition: "Your maximum heart rate (from HealthKit or age formula)")
                }
            }

            Divider().padding(.vertical, 4)

            MetricSectionLabel("WHAT YOUR SCORE MEANS")

            ScoreRangeGuide(bands: [
                ScoreBand(range: "0 – 30%",  label: "Recovery",  detail: "Light effort, active rest. Promotes circulation and recovery.", color: .teal),
                ScoreBand(range: "30 – 60%", label: "Aerobic",   detail: "Fat-burning zone. Builds your endurance base over time.", color: .green),
                ScoreBand(range: "60 – 80%", label: "Tempo",     detail: "Challenging but sustainable. Improves aerobic capacity.", color: .yellow),
                ScoreBand(range: "80 – 100%",label: "Max Effort",detail: "High-intensity push. Builds peak performance and VO₂ max.", color: .red),
            ])

            Divider().padding(.vertical, 4)

            MetricSectionLabel("WHY IT MATTERS")
            Text("Tracking intensity over time shows whether you are training hard enough to drive adaptation — or overdoing it. A well-periodised program mixes all four bands across the week.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Progress Pulse Card

    private var progressPulseCard: some View {
        MetricCard(accent: themeColor) {
            MetricCardHeader(
                icon: "heart.text.clipboard",
                title: "Progress Pulse",
                badge: "0 – 100",
                color: themeColor
            )

            MetricSectionLabel("HOW IT'S CALCULATED")

            Text("Three pillars of a quality session, each contributing points toward a maximum of **90**:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                PulsePointRow(
                    icon: "flag.checkered",
                    color: .orange,
                    title: "Base Score",
                    subtitle: "Every completed session starts here",
                    points: "50 pts"
                )
                Divider().padding(.leading, 44)
                PulsePointRow(
                    icon: "trophy.fill",
                    color: .yellow,
                    title: "Personal Best",
                    subtitle: "Beat or match your fastest recorded session",
                    points: "+15 pts"
                )
                Divider().padding(.leading, 44)
                PulsePointRow(
                    icon: "calendar.badge.checkmark",
                    color: .green,
                    title: "Weekly Frequency",
                    subtitle: "+5 pts per session this week (target: 3×/week)",
                    points: "+15 pts"
                )
                Divider().padding(.leading, 44)
                PulsePointRow(
                    icon: "bolt.heart.fill",
                    color: .red,
                    title: "Zone Intensity",
                    subtitle: "Zone 4–5 = +10 pts  ·  Zone 3 = +5 pts",
                    points: "+10 pts"
                )
            }
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Divider().padding(.vertical, 4)

            MetricSectionLabel("WHAT YOUR SCORE MEANS")

            ScoreRangeGuide(bands: [
                ScoreBand(range: "0 – 50",  label: "Building",    detail: "You finished — that is what counts. Consistency is the goal.", color: .gray),
                ScoreBand(range: "50 – 65", label: "On Track",    detail: "Solid session. Frequency or effort can still be pushed.", color: .blue),
                ScoreBand(range: "65 – 80", label: "Strong",      detail: "Frequency, effort, and performance all trending well.", color: themeColor),
                ScoreBand(range: "80 – 90", label: "Peak",        detail: "You hit your PB at high intensity, consistently this week.", color: .orange),
            ])

            Divider().padding(.vertical, 4)

            MetricSectionLabel("WHY IT MATTERS")
            Text("A single metric cannot tell the full story. Progress Pulse combines consistency, performance, and effort into one number — so you can see at a glance whether this week is moving you forward.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Dominant Zone Card

    private var dominantZoneCard: some View {
        MetricCard(accent: .purple) {
            MetricCardHeader(
                icon: "waveform.path.ecg",
                title: "Dominant Zone",
                badge: "Zones 1 – 5",
                color: .purple
            )

            MetricSectionLabel("HOW IT'S CALCULATED")

            Text("Every heart rate sample during your session is assigned to a zone based on **% of your maximum heart rate**. The zone where you spent the most cumulative time becomes your Dominant Zone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(ZoneInfo.all) { zone in
                    ZoneRow(zone: zone)
                }
            }

            Divider().padding(.vertical, 4)

            MetricSectionLabel("READING YOUR DOMINANT ZONE")

            VStack(alignment: .leading, spacing: 10) {
                ZoneInsightRow(icon: "moon.zzz.fill",  color: .teal,   text: "Zone 1–2 dominant: Recovery session. Ideal after intense days to flush fatigue and maintain frequency.")
                ZoneInsightRow(icon: "figure.run",     color: .green,  text: "Zone 3 dominant: Aerobic base work. The backbone of endurance — do more of this.")
                ZoneInsightRow(icon: "flame.fill",     color: .orange, text: "Zone 4 dominant: Threshold training. Pushes your lactate threshold higher, making hard efforts feel easier.")
                ZoneInsightRow(icon: "bolt.fill",      color: .red,    text: "Zone 5 dominant: VO₂ max work. Rare, short, and powerful. Limit to 1–2 sessions per week to avoid burnout.")
            }

            Divider().padding(.vertical, 4)

            MetricSectionLabel("WHY IT MATTERS")
            Text("Most improvements come from training the right zones on the right days. Use this metric to ensure your week contains variety — not just all-out efforts — and to confirm that easy days are truly easy.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Footer

    private var footerNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("All calculations are performed on-device using your HealthKit data. Nothing is sent to external servers.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - MetricCard Container

private struct MetricCard<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accent.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - MetricCardHeader

private struct MetricCardHeader: View {
    let icon: String
    let title: String
    let badge: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text(badge)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - MetricSectionLabel

private struct MetricSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
            .tracking(1.5)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - FormulaView

private struct FormulaView: View {
    let numerator: String
    let denominator: String
    let multiplier: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 3) {
                Text(numerator)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(height: 1)
                Text(denominator)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            Text(multiplier)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Formula: \(numerator) divided by \(denominator), multiplied by 100")
    }
}

// MARK: - FormulaTermRow

private struct FormulaTermRow: View {
    let term: String
    let definition: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(term)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 90, alignment: .leading)
            Text(definition)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(term): \(definition)")
    }
}

// MARK: - ScoreRangeGuide

private struct ScoreBand {
    let range: String
    let label: String
    let detail: String
    let color: Color
}

private struct ScoreRangeGuide: View {
    let bands: [ScoreBand]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(bands.indices, id: \.self) { i in
                let band = bands[i]
                HStack(alignment: .top, spacing: 10) {
                    Capsule()
                        .fill(band.color)
                        .frame(width: 4)
                        .padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(band.range)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(band.color)
                            Text(band.label.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                                .tracking(0.8)
                        }
                        Text(band.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(band.range): \(band.label). \(band.detail)")
            }
        }
    }
}

// MARK: - PulsePointRow

private struct PulsePointRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let points: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(points)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(points). \(subtitle)")
    }
}

// MARK: - ZoneInfo

private struct ZoneInfo: Identifiable {
    let id: Int
    let name: String
    let range: String
    let training: String
    let color: Color

    static let all: [ZoneInfo] = [
        ZoneInfo(id: 1, name: "Very Light",  range: "< 60% max HR",    training: "Recovery · Warm-up",              color: .teal),
        ZoneInfo(id: 2, name: "Light",       range: "60 – 70% max HR", training: "Fat burn · Aerobic base",         color: .green),
        ZoneInfo(id: 3, name: "Moderate",    range: "70 – 80% max HR", training: "Aerobic capacity · Tempo",        color: .yellow),
        ZoneInfo(id: 4, name: "Hard",        range: "80 – 90% max HR", training: "Lactate threshold · Performance", color: .orange),
        ZoneInfo(id: 5, name: "Maximum",     range: "≥ 90% max HR",    training: "VO₂ max · Anaerobic power",       color: .red),
    ]
}

// MARK: - ZoneRow

private struct ZoneRow: View {
    let zone: ZoneInfo

    var body: some View {
        HStack(spacing: 10) {
            Text("Z\(zone.id)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(zone.color)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(zone.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(zone.range)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(zone.training)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(zone.color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Zone \(zone.id), \(zone.name), \(zone.range). Trains: \(zone.training)")
    }
}

// MARK: - ZoneInsightRow

private struct ZoneInsightRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
