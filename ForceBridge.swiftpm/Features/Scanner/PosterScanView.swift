import SwiftUI
import PhotosUI
import UIKit

/// Распознавание афиши: фото → Vision → поля объявления.
struct PosterScanView: View {
    var onApply: (PosterDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var lines: [RecognizedLine] = []
    @State private var draft = PosterDraft()
    @State private var phase: Phase = .idle
    @State private var sweep = false

    enum Phase: Equatable {
        case idle
        case loading
        case recognizing
        case done
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro
                    sources
                    if let image {
                        preview(image)
                    }
                    statusLine
                    if phase == .done {
                        recognizedText
                        form
                    }
                }
                .padding(Metrics.gutter)
                .contentColumn()
            }
            .scrollDismissesKeyboard(.interactively)
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    MonoLabel("Скан афиши", color: Palette.ink, weight: .semibold)
                }
            }
        }
        .presentationBackground(Palette.paper)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await load(newItem)
            }
        }
    }

    // MARK: Блоки

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Афиша → объявление")
                .font(Typo.display(26, weight: .heavy))
                .foregroundStyle(Palette.ink)
            Text("Vision распознаёт текст на фото афиши конкурса, а приложение вытаскивает название, даты, город и размер команды. Всё можно поправить.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sources: some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 13, weight: .semibold))
                    Text("ФОТО АФИШИ")
                        .font(Typo.mono(12, weight: .bold))
                }
                .foregroundStyle(Palette.onSignal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Palette.signal)
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await processSample()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 13, weight: .semibold))
                    Text("ПРИМЕР")
                        .font(Typo.mono(12, weight: .bold))
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .disabled(phase == .loading || phase == .recognizing)
    }

    private func preview(_ image: UIImage) -> some View {
        let aspect = image.size.width / max(image.size.height, 1)
        return Image(uiImage: image)
            .resizable()
            .aspectRatio(aspect, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        ForEach(lines) { line in
                            let rect = CGRect(
                                x: line.box.minX * proxy.size.width,
                                y: (1 - line.box.maxY) * proxy.size.height,
                                width: line.box.width * proxy.size.width,
                                height: line.box.height * proxy.size.height
                            )
                            Rectangle()
                                .stroke(Palette.signal, lineWidth: 1.5)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                        if phase == .recognizing {
                            Rectangle()
                                .fill(Palette.signal)
                                .frame(width: proxy.size.width, height: 2)
                                .offset(y: sweep ? proxy.size.height - 2 : 0)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                                        sweep = true
                                    }
                                }
                                .onDisappear {
                                    sweep = false
                                }
                        }
                    }
                }
            }
            .frame(maxHeight: 440)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Palette.surface)
            .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
            .accessibilityLabel("Изображение афиши")
    }

    @ViewBuilder
    private var statusLine: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .loading:
            MonoLabel("Загружаем фото…", color: Palette.graphite)
        case .recognizing:
            MonoLabel("Vision читает текст…", color: Palette.signal, weight: .semibold)
        case .done:
            MonoLabel(
                "Найдено строк: \(lines.count) · дат: \(draft.datesFound)",
                color: Palette.ink,
                weight: .semibold
            )
        case .failed(let message):
            EmptyNote(title: "Не получилось", message: message)
        }
    }

    private var recognizedText: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "01", title: "Распознанный текст", trailing: "уверенность")
            ForEach(lines.prefix(14)) { line in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(line.text)
                        .font(Typo.mono(12))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(String(format: "%.2f", Double(line.confidence)))
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(line.confidence >= 0.5 ? Palette.graphite : Palette.signal)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Hairline() }
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(number: "02", title: "Проверьте поля")
            FieldBox(label: "Название события") {
                TextField("Например, хакатон «Северный код»", text: $draft.title)
            }
            VStack(spacing: 0) {
                DatePicker(selection: $draft.startDate, displayedComponents: .date) {
                    MonoLabel("Старт", size: 10.5)
                }
                .padding(.vertical, 8)
                Hairline()
                DatePicker(selection: $draft.deadline, displayedComponents: .date) {
                    MonoLabel("Регистрация до", size: 10.5)
                }
                .padding(.vertical, 8)
                Hairline()
                Stepper(value: $draft.minTeam, in: 1...10) {
                    MonoLabel("Команда от \(draft.minTeam)", color: Palette.ink, size: 10.5)
                }
                .padding(.vertical, 8)
                Hairline()
                Stepper(value: $draft.maxTeam, in: 1...12) {
                    MonoLabel("Команда до \(draft.maxTeam)", color: Palette.ink, size: 10.5)
                }
                .padding(.vertical, 8)
            }
            .environment(\.locale, Fmt.locale)
            .tint(Palette.signal)

            VStack(alignment: .leading, spacing: 8) {
                MonoLabel("Формат", size: 10.5)
                FormatPicker(selection: $draft.format)
            }
            if draft.format != .online {
                CityField(city: $draft.city)
            }
            VStack(alignment: .leading, spacing: 18) {
                FieldBox(label: "Приз") {
                    TextField("Необязательно", text: $draft.prize)
                }
                FieldBox(label: "Организатор") {
                    TextField("Кто проводит", text: $draft.organizer)
                }
                FieldBox(label: "Описание") {
                    TextField("Пара предложений о событии", text: $draft.summary, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            Button("Подставить в объявление") {
                if draft.datesFound == 0 {
                    draft.datesFound = 1
                }
                onApply(draft)
                dismiss()
            }
            .buttonStyle(.signal)
            .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: Обработка

    private func load(_ item: PhotosPickerItem) async {
        phase = .loading
        lines = []
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let picked = UIImage(data: data) else {
                phase = .failed("Не удалось открыть изображение.")
                return
            }
            await process(PosterRecognizer.normalized(picked))
        } catch {
            phase = .failed("Не удалось загрузить фото: \(error.localizedDescription)")
        }
    }

    private func processSample() async {
        guard let sample = SamplePoster.render() else {
            phase = .failed("Не удалось нарисовать пример афиши.")
            return
        }
        await process(sample)
    }

    private func process(_ picked: UIImage) async {
        image = picked
        lines = []
        phase = .recognizing
        guard let cgImage = picked.cgImage else {
            phase = .failed("Этот формат изображения не поддерживается.")
            return
        }
        do {
            let result = try await PosterRecognizer.recognize(cgImage)
            withAnimation(.easeOut(duration: 0.3)) {
                lines = result
            }
            if result.isEmpty {
                phase = .failed("Текст не найден. Сфотографируйте афишу крупнее и ровнее.")
                return
            }
            draft = PosterParser.parse(result)
            phase = .done
        } catch {
            phase = .failed("Vision не смог распознать текст: \(error.localizedDescription)")
        }
    }
}
