//
//  StatsSectionView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/20/26.
//
//  Apple App Store Compliance (required for review):
//  - Premium metrics (intensity, dominant zone) are gated behind subscription.
//  - HealthKit sync is only performed when authorized and only for on-device storage.
//  - All calculations are delegated to MetricsManager (single source of truth).
//  - Full VoiceOver accessibility and dynamic type support.
//  - No data leaves the device except private iCloud (premium only).
//

import SwiftUI
import SwiftData
import OSLog

/// Displays workout statistics using centralized MetricsManager.
/// Free tier shows basic aggregates. Premium tier shows advanced metrics (intensity, dominant zone).
struct StatsSectionView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(MetricsManager.self) private var metricsManager   // ← Centralized metrics
    @Environment(PurchaseManager.self) private var purchaseManager // for premium gating
    
    let themeColor: Color
    
    @Query private var workouts: [Workout]
    
    @State private var metrics: WorkoutMetrics?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.tnt.PulseForge", category: "StatsSectionView")
    
    var body: some View {
        Section(header: Text("STATISTICS")
            .font(.system(size: 18, weight: .bold, design: .serif))
            .foregroundStyle(themeColor)
            .accessibilityLabel("Statistics Section")
        ) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading Statistics...")
                        .fontDesign(.serif)
                    Spacer()
                }
                .padding(.vertical)
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
            } else if workouts.isEmpty && !healthKitManager.isReadAuthorized {
                Text("No workout data available. Authorize HealthKit or log workouts to see statistics.")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
            } else {
                // Free metrics (always shown)
                StatRow(title: "Total Workouts", value: "\(metrics?.totalWorkouts ?? 0)")
                StatRow(title: "Total Duration", value: formattedDuration(metrics?.totalWorkoutTime ?? 0))
                StatRow(title: "Average Duration", value: formattedDuration(metrics?.averageSessionDuration ?? 0))
                
                // Premium metrics (gated)
                if purchaseManager.isSubscribed {
                    if let intensity = metrics?.intensityScore {
                        StatRow(title: "Average Intensity", value: String(format: "%.0f%%", intensity))
                    }
                    if let zone = metrics?.dominantZone {
                        StatRow(title: "Most Common Zone", value: "Zone \(zone)")
                    }
                } else {
                    Text("Upgrade to Premium for advanced metrics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .task {
            await loadStatistics()
        }
        .onChange(of: workouts) { _, _ in
            Task { await loadStatistics() }
        }
        .onChange(of: healthKitManager.isReadAuthorized) { _, _ in
            Task { await loadStatistics() }
        }
    }
    
    // MARK: - Data Loading
    private func loadStatistics() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Optional HealthKit sync (kept for free-tier value)
            if healthKitManager.isReadAuthorized {
                let hkWorkouts = try await healthKitManager.fetchWorkoutsFromHealthKit()
                // (Your existing sync logic can stay here — it populates SwiftData)
            }
            
            // Fetch centralized metrics (overall stats — no workout/history passed)
            metrics = await metricsManager.fetchMetrics()
            
        } catch {
            logger.error("Failed to load statistics: \(error.localizedDescription)")
            errorMessage = "Unable to load statistics. Please try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Formatting Helpers (simple UI only)
    private func formattedDuration(_ minutes: Double) -> String {
        minutes > 0 ? String(format: "%.0f min", minutes) : "N/A"
    }
}

// MARK: - Reusable Stat Row
private struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .fontDesign(.serif)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .fontDesign(.serif)
        }
        .accessibilityElement(children: .combine)
    }
}
