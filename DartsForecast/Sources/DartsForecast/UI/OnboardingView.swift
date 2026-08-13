import SwiftUI
import CoreGraphics

struct OnboardingView: View {
    @ObservedObject var pipeline: PipelineCoordinator
    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Darts Forecast")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Group {
                switch step {
                case 0:
                    textBlock(
                        title: "Как это работает",
                        body: "Приложение локально читает область результата и поведение игрока, обучается после каждого броска и показывает ТОП-4 наиболее вероятных следующих чисел. Автоставки отключены."
                    )
                case 1:
                    textBlock(
                        title: "Разрешение экрана",
                        body: "macOS запросит доступ к записи экрана. Разрешите его в Системных настройках → Конфиденциальность → Запись экрана."
                    )
                case 2:
                    VStack(spacing: 12) {
                        textBlock(title: "Область результата", body: "Выделите зону, где букмекер показывает последние числа.")
                        Button("Выбрать область результата") { pipeline.selectResultRegion() }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                    }
                case 3:
                    VStack(spacing: 12) {
                        textBlock(title: "Область игрока", body: "Выделите видео с игроком. Можно пропустить, если пока не нужно.")
                        Button("Выбрать область игрока") { pipeline.selectPlayerRegion() }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                    }
                case 4:
                    textBlock(
                        title: "Проверка OCR",
                        body: "После старта мониторинга в главном окне появится распознанный текст. Если число неверно — уточните область."
                    )
                default:
                    textBlock(
                        title: "Paper Prediction",
                        body: "Рекомендуемый режим: программа только прогнозирует и считает точность, без каких-либо действий на сайте."
                    )
                }
            }
            .frame(maxWidth: 520)

            HStack {
                if step > 0 {
                    Button("Назад") { step -= 1 }
                }
                Spacer()
                if step < 5 {
                    Button("Далее") {
                        if step == 1 {
                            _ = CGRequestScreenCaptureAccess()
                        }
                        step += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                } else {
                    Button("Начать Paper Prediction") {
                        pipeline.settings.paperMode = true
                        pipeline.settings.onboardingDone = true
                        pipeline.settings.persist()
                        pipeline.persist()
                        pipeline.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                }
            }
            .frame(maxWidth: 520)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.11, blue: 0.13), Color(red: 0.09, green: 0.16, blue: 0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func textBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(body)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

