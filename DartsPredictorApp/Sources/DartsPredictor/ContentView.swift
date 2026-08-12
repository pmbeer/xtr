import SwiftUI

struct ContentView: View {
    @StateObject private var engine = Engine()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 14) {
            header
            bestBetBanner
            HStack(alignment: .top, spacing: 14) {
                PlayerPanel(state: engine.leftPlayer)
                PlayerPanel(state: engine.rightPlayer)
            }
            logView
        }
        .padding(16)
        .frame(minWidth: 700, minHeight: 620)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: $engine.settings)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    Task { await engine.selectRegions() }
                } label: {
                    Label("Области счёта", systemImage: "rectangle.dashed")
                }

                if engine.isRunning {
                    Button {
                        engine.stop()
                    } label: {
                        Label("Стоп", systemImage: "stop.fill")
                    }
                    .tint(.red)
                } else {
                    Button {
                        engine.start()
                    } label: {
                        Label("Старт", systemImage: "play.fill")
                    }
                    .tint(.green)
                    .disabled(!engine.regionsConfigured)
                }

                Button {
                    showSettings = true
                } label: {
                    Label("Коэффициенты", systemImage: "slider.horizontal.3")
                }

                Spacer()

                if engine.isRunning {
                    Label("\(engine.lastAnalysisMs) мс", systemImage: "bolt.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.borderedProminent)

            Text(engine.status)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var bestBetBanner: some View {
        if let best = engine.bestRecommendation {
            VStack(spacing: 4) {
                Text(best.market)
                    .font(.system(size: 40, weight: .black))
                Text(String(format: "вероятность %.0f%%  ·  кэф %.2f  ·  EV %+.2f",
                            best.probability * 100, best.odds, best.ev))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(best.ev > 0 ? Color.green.opacity(0.18) : Color.orange.opacity(0.15))
            )
        } else {
            Text("Здесь появится рекомендация после первого броска")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
                .foregroundStyle(.secondary)
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(engine.logLines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 140)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
            .onChange(of: engine.logLines.count) {
                proxy.scrollTo(engine.logLines.count - 1, anchor: .bottom)
            }
        }
    }
}

struct PlayerPanel: View {
    let state: PlayerPanelState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(state.name)
                    .font(.headline)
                Spacer()
                Text(state.score.map(String.init) ?? "—")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }

            if state.history.isEmpty {
                Text("Бросков пока нет")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(state.history.suffix(12).enumerated()), id: \.offset) { _, sector in
                            Text(sector == PlayerModel.bull ? "🎯" : "\(sector)")
                                .font(.system(.caption, design: .rounded).bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Circle().fill(Color.blue.opacity(0.15)))
                        }
                    }
                }
            }

            Divider()

            if state.recommendations.isEmpty {
                Text("Рекомендации появятся после броска")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(state.recommendations) { recommendation in
                    HStack {
                        Circle()
                            .fill(recommendation.ev > 0 ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(recommendation.displayText)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
    }
}

struct SettingsView: View {
    @Binding var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Коэффициенты из линии")
                .font(.title3.bold())
            Text("Впишите реальные коэффициенты букмекера — от них зависит расчёт EV. Если EV < 0, ставка математически убыточна.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    oddsField("ЧЕТ", $settings.oddsEven)
                    oddsField("НЕЧЕТ", $settings.oddsOdd)
                }
                GridRow {
                    oddsField("1-10", $settings.oddsLow)
                    oddsField("11-20", $settings.oddsHigh)
                }
                GridRow {
                    oddsField("Точное число", $settings.oddsExact)
                    oddsField("Буллсай", $settings.oddsBull)
                }
            }

            Divider()

            Toggle("Голосовые подсказки", isOn: $settings.voiceEnabled)

            HStack {
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func oddsField(_ title: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .frame(width: 110, alignment: .leading)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
        }
    }
}
