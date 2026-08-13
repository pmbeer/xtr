import SwiftUI
import AppKit

/// Геометрия aspect-fit для превью окна
struct PreviewAspectFit {
    let containerSize: CGSize
    let imageSize: CGSize

    var fittedRect: CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(
            x: (containerSize.width - w) / 2,
            y: (containerSize.height - h) / 2,
            width: w,
            height: h
        )
    }

    func normalizedRect(from viewRect: CGRect) -> NormalizedRect {
        let fit = fittedRect
        guard fit.width > 0, fit.height > 0 else {
            return NormalizedRect(x: 0, y: 0, width: 0.1, height: 0.1)
        }
        let x = (viewRect.minX - fit.minX) / fit.width
        let y = (viewRect.minY - fit.minY) / fit.height
        let w = viewRect.width / fit.width
        let h = viewRect.height / fit.height
        return NormalizedRect(
            x: max(0, min(1, x)),
            y: max(0, min(1, y)),
            width: max(0.03, min(1, w)),
            height: max(0.03, min(1, h))
        )
    }

    func viewRect(for zone: NormalizedRect) -> CGRect {
        let fit = fittedRect
        return CGRect(
            x: fit.minX + zone.x * fit.width,
            y: fit.minY + zone.y * fit.height,
            width: zone.width * fit.width,
            height: zone.height * fit.height
        )
    }
}

struct LivePreviewPanel: View {
    let image: CGImage?
    let cropSize: CGSize
    let captureFrames: Int
    var captureBackend: String = "—"
    var windowTitle: String?
    @Binding var zones: GameWindowZones
    var isCalibrating: Bool = false
    var selectedZoneKind: EditableZoneKind = .results
    var isAnalyzing: Bool = false
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(isCalibrating ? "Калибровка зон" : "Окно игры (live)", systemImage: isCalibrating ? "scope" : "macwindow")
                    .font(.caption.weight(.semibold))
                if isAnalyzing && !isCalibrating {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Text("\(captureBackend) · \(captureFrames) fps · \(Int(cropSize.width))×\(Int(cropSize.height))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let windowTitle {
                Text(windowTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if isCalibrating {
                Text("Выберите зону и выделите её на превью (перетаскивание)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if let img = image {
                GeometryReader { geo in
                    let fit = PreviewAspectFit(containerSize: geo.size, imageSize: cropSize)

                    ZStack {
                        Image(decorative: img, scale: 1.0)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)

                        if isCalibrating {
                            InteractiveZoneEditor(
                                zones: $zones,
                                selectedKind: selectedZoneKind,
                                aspectFit: fit
                            )
                        } else {
                            ZoneOverlayView(zones: zones, aspectFit: fit)
                        }
                    }
                }
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                    isCalibrating ? Color.orange.opacity(0.6) : Color.green.opacity(0.4),
                    lineWidth: isCalibrating ? 2 : 1
                ))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 100)
                    .overlay {
                        Text("Нет кадра — выберите окно Safari с fon.bet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }

            HStack(spacing: 8) {
                zoneLegend(color: .red, label: "Результаты")
                zoneLegend(color: .green, label: "Игрок")
                zoneLegend(color: .blue, label: "Доска")
            }
            .font(.caption2)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func zoneLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.7))
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

struct InteractiveZoneEditor: View {
    @Binding var zones: GameWindowZones
    let selectedKind: EditableZoneKind
    let aspectFit: PreviewAspectFit

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    var body: some View {
        ZStack {
            ForEach(EditableZoneKind.allCases) { kind in
                if kind != selectedKind {
                    zoneOutline(kind: kind, dashed: true)
                }
            }
            zoneOutline(kind: selectedKind, dashed: false)

            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            if dragStart == nil {
                                dragStart = value.startLocation
                            }
                            dragCurrent = value.location
                        }
                        .onEnded { value in
                            applyDrag(from: value.startLocation, to: value.location)
                            dragStart = nil
                            dragCurrent = nil
                        }
                )
        }
    }

    private func zoneOutline(kind: EditableZoneKind, dashed: Bool) -> some View {
        let rect = aspectFit.viewRect(for: kind.rect(in: zones))
        let color = zoneColor(kind)
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(color.opacity(dashed ? 0.45 : 0.95), style: StrokeStyle(lineWidth: dashed ? 1 : 2, dash: dashed ? [4, 3] : []))
                .background(color.opacity(dashed ? 0.04 : 0.12))
                .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                .position(x: rect.midX, y: rect.midY)
            if !dashed {
                Text(kind.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.9))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(x: rect.minX + 40, y: rect.minY + 10)
            }
        }
        .allowsHitTesting(false)
    }

    private func applyDrag(from start: CGPoint, to end: CGPoint) {
        let fit = aspectFit.fittedRect
        guard fit.width > 0, fit.height > 0 else { return }

        let clampedStart = clamp(start, to: fit)
        let clampedEnd = clamp(end, to: fit)
        let viewRect = CGRect(
            x: min(clampedStart.x, clampedEnd.x),
            y: min(clampedStart.y, clampedEnd.y),
            width: abs(clampedEnd.x - clampedStart.x),
            height: abs(clampedEnd.y - clampedStart.y)
        )
        guard viewRect.width >= 8, viewRect.height >= 8 else { return }

        let normalized = aspectFit.normalizedRect(from: viewRect)
        selectedKind.setRect(normalized, in: &zones)
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func zoneColor(_ kind: EditableZoneKind) -> Color {
        switch kind {
        case .results: return .red
        case .player: return .green
        case .dartboard: return .blue
        }
    }
}

struct ZoneOverlayView: View {
    let zones: GameWindowZones
    var aspectFit: PreviewAspectFit?

    var body: some View {
        GeometryReader { geo in
            let fit = aspectFit ?? PreviewAspectFit(containerSize: geo.size, imageSize: geo.size)
            zoneBox(zones.dartboardZone, color: .blue, label: "Доска", fit: fit)
            zoneBox(zones.playerZone, color: .green, label: "Игрок", fit: fit)
            zoneBox(zones.resultsZone, color: .red, label: "Результаты", fit: fit)
        }
        .allowsHitTesting(false)
    }

    private func zoneBox(_ zone: NormalizedRect, color: Color, label: String, fit: PreviewAspectFit) -> some View {
        let rect = fit.viewRect(for: zone)
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(color.opacity(0.9), lineWidth: 2)
                .background(color.opacity(0.1))
                .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                .position(x: rect.midX, y: rect.midY)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(color.opacity(0.85))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .position(x: rect.minX + 36, y: rect.minY + 10)
        }
    }
}

struct AIStatusPanel: View {
    let phase: GamePhase
    let sceneState: GameSceneState
    let insight: AIActionInsight
    let resultHistory: [Int]
    let bettingSeconds: Double?
    let throwInProgress: Bool
    let dartboardMotion: Double
    let playerMotion: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ИИ-анализ (online)", systemImage: "brain.head.profile")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Label(phase.rawValue, systemImage: phase.icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(phaseColor)

                if throwInProgress {
                    Label("Бросок", systemImage: "figure.handball")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }

                if let sec = bettingSeconds {
                    Label("\(String(format: "%.1f", sec))с", systemImage: "timer")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.blue)
                }
            }

            Text(insight.aiDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("🔴 История бросков:")
                        .font(.caption2.weight(.semibold))
                    Text(resultHistory.isEmpty ? "—" : resultHistory.map(String.init).joined(separator: " → "))
                        .font(.caption.monospacedDigit())
                }
                HStack {
                    Text("🟢 Игрок:")
                        .font(.caption2.weight(.semibold))
                    Text("\(insight.detectedAction.rawValue) · движение \(Int(playerMotion * 100))%")
                        .font(.caption2)
                }
                HStack {
                    Text("🔵 Доска:")
                        .font(.caption2.weight(.semibold))
                    Text(motionLabel(dartboardMotion))
                        .font(.caption2)
                }
            }

            ProgressView(value: insight.throwPhaseProgress) {
                Text("Фаза броска")
                    .font(.caption2)
            }
            .tint(.orange)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var phaseColor: Color {
        switch phase {
        case .bettingWindow: return .blue
        case .throwing: return .orange
        case .resultShown: return .green
        default: return .secondary
        }
    }

    private func motionLabel(_ motion: Double) -> String {
        if motion > 0.18 { return "бросок! \(Int(motion * 100))%" }
        if motion > 0.08 { return "движение \(Int(motion * 100))%" }
        return "стабильна \(Int(motion * 100))%"
    }
}

struct CombinationDisplayView: View {
    let combination: PredictedCombination

    var body: some View {
        if !combination.numbers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("КОМБИНАЦИЯ")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(combination.formatted)
                    .font(.title2.weight(.bold).monospacedDigit())

                HStack {
                    Text("Совместная вероятность:")
                        .font(.caption)
                    Text(String(format: "%.1f%%", combination.jointProbability))
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
            }
        }
    }
}

struct PredictionDisplayView: View {
    let predictions: [TopPrediction]
    let combination: PredictedCombination
    let confidence: ConfidenceLevel
    let confidenceScore: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("СЛЕДУЮЩИЙ ПРОГНОЗ")
                .font(.headline)
                .foregroundStyle(.secondary)

            CombinationDisplayView(combination: combination)

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(predictions) { pred in
                        Text("# \(pred.number)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(predictions) { pred in
                        Text("\(pred.number) — \(String(format: "%.1f", pred.probability))%")
                            .font(.title3)
                            .monospacedDigit()
                    }
                }
            }

            HStack {
                Text("Уверенность: \(confidence.localizedName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(confidenceColor)

                Spacer()

                Text("\(Int(confidenceScore))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}

struct StatusBarView: View {
    let lastResult: Int?
    let top4Accuracy: String
    let outcome: PredictionOutcome

    var body: some View {
        HStack(spacing: 20) {
            if let result = lastResult {
                Text("Последний результат: \(result)")
                    .font(.subheadline)
            }

            Text("Точность TOP-4: \(top4Accuracy)")
                .font(.subheadline)

            Text("Прогноз: \(outcomeSymbol)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(outcomeColor)
        }
    }

    private var outcomeSymbol: String {
        switch outcome {
        case .success: return "✓"
        case .miss: return "✗"
        case .pending: return "—"
        }
    }

    private var outcomeColor: Color {
        switch outcome {
        case .success: return .green
        case .miss: return .red
        case .pending: return .secondary
        }
    }
}
