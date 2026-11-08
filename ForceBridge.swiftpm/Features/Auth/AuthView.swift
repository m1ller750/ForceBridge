import SwiftUI

/// Вступление, регистрация и вход.
struct AuthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var mode: Mode = .register
    @State private var email = ""
    @State private var password = ""
    @State private var passwordRepeat = ""
    @State private var working = false
    @State private var errorText: String?

    enum Mode { case register, signIn }

    private var canSubmit: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passwordOK = password.count >= 6
        if mode == .register {
            return emailOK && passwordOK && password == passwordRepeat
        }
        return emailOK && !password.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    MonoLabel("ForceBridge / v2.0", color: Palette.faint)
                    Spacer()
                    MonoLabel("Лист 1", color: Palette.faint)
                }

                AssemblingTruss()
                    .frame(height: 110)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Force\nBridge")
                        .font(Typo.display(52, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Команда — это конструкция. Найдите тех, с кем она выдержит нагрузку конкурса, хакатона или научного исследования.")
                        .font(Typo.serif(19))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Ruler()

                VStack(alignment: .leading, spacing: 16) {
                    Principle(number: "01", title: "Объявления", text: "Опубликуйте карточку: «ищу сокомандника на конкурс» или «нужен человек для исследования».")
                    Principle(number: "02", title: "Отклики", text: "Откликайтесь на чужие карточки — автор увидит ваш профиль, резюме и контакты.")
                    Principle(number: "03", title: "ИИ", text: "Нейросеть раскладывает объявления по категориям и считает, насколько вы подходите.")
                }

                if !SupabaseConfig.isConfigured {
                    EmptyNote(
                        title: "Сервер не подключён",
                        message: "Заполните App/SupabaseConfig.swift: адрес проекта Supabase и публичный ключ. Инструкция — в README."
                    )
                }

                form
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 20)
            .contentColumn()
        }
        .scrollDismissesKeyboard(.interactively)
        .paperBackground()
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(number: "→", title: mode == .register ? "Регистрация" : "Вход")
            HStack(spacing: 6) {
                Chip(title: "Новый аккаунт", isOn: mode == .register) {
                    mode = .register
                    errorText = nil
                }
                Chip(title: "Уже есть аккаунт", isOn: mode == .signIn) {
                    mode = .signIn
                    errorText = nil
                }
            }
            FieldBox(label: "Почта") {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            FieldBox(label: "Пароль", hint: mode == .register ? "не короче 6 символов" : nil) {
                SecureField("Пароль", text: $password)
                    .textContentType(mode == .register ? .newPassword : .password)
            }
            if mode == .register {
                FieldBox(label: "Повторите пароль", hint: !passwordRepeat.isEmpty && passwordRepeat != password ? "не совпадает" : nil) {
                    SecureField("Пароль ещё раз", text: $passwordRepeat)
                        .textContentType(.newPassword)
                }
            }
            if let errorText {
                Text(errorText)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.signal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(working ? "Подождите…" : (mode == .register ? "Создать аккаунт" : "Войти")) {
                submit()
            }
            .buttonStyle(.signal)
            .disabled(!canSubmit || working || !SupabaseConfig.isConfigured)
            if mode == .register {
                Text("После регистрации заполните паспорт участника: чем занимаетесь, возраст, город и контакт для связи.")
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func submit() {
        working = true
        errorText = nil
        Task {
            do {
                if mode == .register {
                    try await store.register(email: email, password: password)
                } else {
                    try await store.signIn(email: email, password: password)
                }
            } catch {
                errorText = error.localizedDescription
            }
            working = false
        }
    }
}

private struct Principle: View {
    let number: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(number)
                .font(Typo.mono(12, weight: .bold))
                .foregroundStyle(Palette.signal)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                Text(text)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
