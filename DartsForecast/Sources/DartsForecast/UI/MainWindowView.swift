import SwiftUI

public struct MainWindowView: View {
    @ObservedObject var pipeline: PipelineCoordinator
    @State private var selectedTab = 0
    @State private var testNumber = "17"

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $selectedTab) {
                forecastTab.tabItem { Text("Прогноз") }.tag(0)
                HistoryView(records: pipeline.history.records).tabItem { Text("История") }.tag(1)
                TrainingView(pipeline: pipeline).tabItem { Text("Обучение") }.tag(2)
                settingsTab.tabItem { Text("Настройки") }.tag(3)
            }
            .padding(16)
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(background)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.12, blue: 0.14),
                Color(red: 0.10, green: 0.18, blue: 0.20),
                Color(red: 0.05, green: 0.08, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Darts Forecast")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(pipeline.statusText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            if pipeline.settings.paperMode {
                Text("PAPER")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.teal.opacity(0.35))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Button(pipeline.isRunning ? "Стоп" : "Старт") {
                pipeline.isRunning ? pipeline.stop() : pipeline.start()
            }
            .buttonStyle(.borderedProminent)
            .tint(pipeline.isRunning ? .orange : .teal)
        }
        .padding(16)
    }

    private var forecastTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("СЛЕДУЮЩИЙ ПРОГНОЗ")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.teal)

                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(pipeline.lastPrediction.items) { item in
                            Text("# \(item.number)")
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        if pipeline.lastPrediction.items.isEmpty {
                            Text("—")
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(pipeline.lastPrediction.items) { item in
                            HStack {
                                Text("\(item.number)")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("—")
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(item.percentText)
                                    .font(.title3.monospacedDigit())
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                    Spacer()
                }

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow {
                        label("Уверенность")
                        Text(pipeline.lastPrediction.confidence.displayName)
                            .foregroundStyle(confidenceColor)
                            .font(.headline)
                    }
                    GridRow {
                        label("Последний результат")
                        Text(pipeline.lastResult.map(String.init) ?? "—")
                            .foregroundStyle(.white)
                            .font(.title3.bold())
                    }
                    GridRow {
                        label("Точность TOP-4")
                        Text(pct(pipeline.learning.accuracy.snapshot.top4Accuracy))
                            .foregroundStyle(.white)
                    }
                    GridRow {
                        label("Прогноз")
                        Text(verifyText)
                            .foregroundStyle(pipeline.lastVerified == true ? .green : (pipeline.lastVerified == false ? .red : .gray))
                            .font(.title2.bold())
                    }
                    GridRow {
                        label("Обработка")
                        Text("\(pipeline.lastProcessingMs) мс")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    if pipeline.decisionDeadline != nil {
                        GridRow {
                            label("Таймер")
                            DecisionTimerView(deadline: pipeline.decisionDeadline)
                        }
                    }
                }

                if !pipeline.ocrProbeText.isEmpty {
                    Text("OCR: \(pipeline.ocrProbeText)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }
        }
    }

    private var settingsTab: some View {
        Form {
            Section("Области экрана") {
                Button("Выбрать область результата") { pipeline.selectResultRegion() }
                Button("Выбрать область игрока") { pipeline.selectPlayerRegion() }
                LabeledContent("Результат") {
                    Text(pipeline.settings.regions.resultRegion == nil ? "не задано" : "задано")
                }
                LabeledContent("Игрок") {
                    Text(pipeline.settings.regions.playerRegion == nil ? "не задано" : "задано")
                }
            }
            Section("Режим") {
                Toggle("Paper Prediction (без ставок)", isOn: Binding(
                    get: { pipeline.settings.paperMode },
                    set: {
                        pipeline.settings.paperMode = $0
                        pipeline.settings.persist()
                    }
                ))
                Toggle("Плавающее окно", isOn: Binding(
                    get: { pipeline.settings.floatingOverlayVisible },
                    set: {
                        pipeline.settings.floatingOverlayVisible = $0
                        pipeline.settings.persist()
                    }
                ))
            }
            Section("Тест без OCR") {
                HStack {
                    TextField("Число", text: $testNumber)
                        .frame(width: 80)
                    Button("Ввести результат") {
                        if let n = Int(testNumber), DartNumber.parse(n) != nil {
                            pipeline.injectResultForTesting(n)
                        }
                    }
                }
                Text("Только анализ и прогноз. Автоставки отключены.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func label(_ t: String) -> some View {
        Text(t).foregroundStyle(.white.opacity(0.6))
    }

    private var verifyText: String {
        switch pipeline.lastVerified {
        case true: return "✓"
        case false: return "✗"
        default: return "—"
        }
    }

    private var confidenceColor: Color {
        switch pipeline.lastPrediction.confidence {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }

    private func pct(_ v: Double) -> String {
        String(format: "%.1f%%", v * 100)
    }
}

public struct DecisionTimerView: View {
    let deadline: Date?
    @State private var remaining: Double = 0

    var body: some View {
        Text(String(format: "%.1f сек", max(0, remaining)))
            .foregroundStyle(remaining < 1.5 ? .orange : .white)
            .font(.title3.monospacedDigit())
            .onAppear { tick() }
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                tick()
            }
    }

    private func tick() {
        guard let deadline else { remaining = 0; return }
        remaining = deadline.timeIntervalSinceNow
    }
}
