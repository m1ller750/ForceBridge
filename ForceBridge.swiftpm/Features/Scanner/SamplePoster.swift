import SwiftUI
import UIKit

/// Пример афиши, который рисуется прямо в приложении (ImageRenderer),
/// чтобы распознавание можно было проверить без фото.
enum SamplePoster {
    @MainActor
    static func render(now: Date = Date()) -> UIImage? {
        let start = Fmt.date(byAddingDays: 26, to: now)
        let end = Fmt.date(byAddingDays: 28, to: now)
        let deadline = Fmt.date(byAddingDays: 12, to: now)
        let renderer = ImageRenderer(content: SamplePosterView(start: start, end: end, deadline: deadline))
        renderer.scale = 2
        return renderer.uiImage
    }
}

struct SamplePosterView: View {
    let start: Date
    let end: Date
    let deadline: Date

    private let backdrop = Color(red: 0.08, green: 0.08, blue: 0.075)
    private let paper = Color(red: 0.95, green: 0.93, blue: 0.9)
    private let orange = Color(red: 1.0, green: 0.31, blue: 0.0)

    private var dateRange: String {
        let calendar = Calendar.current
        if calendar.component(.month, from: start) == calendar.component(.month, from: end) {
            return "\(calendar.component(.day, from: start))–\(Fmt.dayMonth(end))"
        }
        return "\(Fmt.dayMonth(start)) – \(Fmt.dayMonth(end))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("ХАКАТОН")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .tracking(5)
                    .foregroundStyle(orange)
                Text("ЗЕЛЁНЫЙ")
                    .font(Font.system(size: 70, weight: .heavy).width(.expanded))
                    .padding(.top, 18)
                Text("КОНТУР")
                    .font(Font.system(size: 70, weight: .heavy).width(.expanded))
            }

            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.68, y: size.height * 0.55)
                for ring in 0..<7 {
                    let inset = CGFloat(ring) * 15
                    let rect = CGRect(
                        x: center.x - 200 + inset * 1.3,
                        y: center.y - 70 + inset * 0.55,
                        width: 400 - inset * 2.6,
                        height: 140 - inset * 1.1
                    )
                    let path = Path(ellipseIn: rect)
                    context.stroke(path, with: .color(ring == 3 ? orange : paper.opacity(0.35)), lineWidth: ring == 3 ? 3 : 1.2)
                }
            }
            .frame(height: 150)
            .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(dateRange) · Томск")
                    .font(.system(size: 30, weight: .bold))
                Text("Регистрация до \(Fmt.dayMonth(deadline))")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(orange)
                    .padding(.top, 6)
                Text("Команды 2–4 человека · 48 часов")
                    .font(.system(size: 22, weight: .regular))
                    .padding(.top, 14)
                Text("Темы: климат, энергетика, городская среда")
                    .font(.system(size: 20, weight: .regular))
                    .padding(.top, 4)
            }

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(paper.opacity(0.5))
                    .frame(height: 1.5)
                Text("Призовой фонд 400 000 ₽")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 16)
                Text("Организатор: Клуб прикладной экологии")
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .padding(.top, 6)
            }
        }
        .foregroundStyle(paper)
        .padding(40)
        .frame(width: 600, height: 860, alignment: .topLeading)
        .background(backdrop)
    }
}
