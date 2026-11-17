import Charts
import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: \AlarmHistory.completedAt, order: .reverse) private var history: [AlarmHistory]

    private var completedHistory: [AlarmHistory] {
        history.filter { $0.outcome == .completed }
    }

    private var activity: [InsightCalculator.DailyActivity] {
        InsightCalculator.weeklyActivity(from: history)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RISETheme.Spacing.lg) {
                header

                if history.isEmpty {
                    RISEEmptyState(
                        icon: "chart.bar.xaxis",
                        title: "No history yet.",
                        message: "Complete a wake-up challenge and your streaks, wake-up times and trends appear here."
                    )
                } else {
                    metricsGrid
                    activityChart
                    recentOutcomes
                }
            }
            .padding(RISETheme.Layout.screenPadding)
            .padding(.bottom, RISETheme.Spacing.xl)
        }
        .riseScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.xs) {
            Text("Insights")
                .font(RISETheme.Typography.screenTitle)
                .foregroundStyle(RISETheme.Colors.text)

            Text("Your morning consistency over time.")
                .font(RISETheme.Typography.caption)
                .foregroundStyle(RISETheme.Colors.muted)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: RISETheme.Spacing.sm), GridItem(.flexible(), spacing: RISETheme.Spacing.sm)], spacing: RISETheme.Spacing.sm) {
            StatCard(
                title: "Average wake-up",
                value: InsightCalculator.averageWakeTime(from: completedHistory) ?? "—",
                caption: "From completed alarms",
                symbol: "sunrise"
            )

            StatCard(
                title: "Successful alarms",
                value: "\(InsightCalculator.successfulCount(from: history))",
                caption: "All time",
                symbol: "checkmark.circle"
            )

            StatCard(
                title: "Current streak",
                value: streakLabel,
                caption: "Consecutive days",
                symbol: "flame"
            )

            StatCard(
                title: "Challenge success",
                value: successRateLabel,
                caption: "Correct answers",
                symbol: "target"
            )
        }
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.md) {
            RISESectionHeader(title: "Last 7 Days")

            Chart(activity) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Completed", day.completed)
                )
                .foregroundStyle(RISETheme.Colors.primary)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(RISETheme.Colors.muted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(RISETheme.Colors.elevated)
                    AxisValueLabel().foregroundStyle(RISETheme.Colors.muted)
                }
            }
            .frame(height: 160)
            .accessibilityLabel("Completed wake-ups in the last seven days")
        }
        .padding(RISETheme.Spacing.md)
        .background(RISETheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous))
    }

    private var recentOutcomes: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.md) {
            RISESectionHeader(title: "Recent Wake-ups")

            VStack(spacing: 0) {
                ForEach(history.prefix(8)) { entry in
                    HStack(spacing: RISETheme.Spacing.md) {
                        Image(systemName: entry.outcome == .completed ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(entry.outcome == .completed ? RISETheme.Colors.success : RISETheme.Colors.muted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? entry.scheduledFor.formatted(date: .abbreviated, time: .shortened))
                                .font(RISETheme.Typography.body)
                                .foregroundStyle(RISETheme.Colors.text)

                            Text("\(entry.alarmLabel) · \(entry.challengeType.title)")
                                .font(RISETheme.Typography.caption)
                                .foregroundStyle(RISETheme.Colors.muted)
                        }

                        Spacer()

                        if entry.totalQuestions > 0 {
                            Text("\(entry.correctAnswers)/\(entry.totalQuestions)")
                                .font(RISETheme.Typography.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(RISETheme.Colors.muted)
                        }
                    }
                    .padding(.vertical, RISETheme.Spacing.sm)
                    .accessibilityElement(children: .combine)

                    if entry.id != history.prefix(8).last?.id {
                        Divider().overlay(RISETheme.Colors.elevated)
                    }
                }
            }
            .padding(.horizontal, RISETheme.Spacing.md)
            .background(RISETheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous))
        }
    }

    private var streakLabel: String {
        let streak = InsightCalculator.streak(from: history)
        return streak == 1 ? "1 day" : "\(streak) days"
    }

    private var successRateLabel: String {
        guard let rate = InsightCalculator.challengeSuccessRate(from: history) else { return "—" }
        return rate.formatted(.percent.precision(.fractionLength(0)))
    }
}
