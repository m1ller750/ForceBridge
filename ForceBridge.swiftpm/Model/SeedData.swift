import Foundation

/// Демонстрационные данные. Все люди, команды и события вымышлены.
/// Даты считаются от момента первого запуска, поэтому лента всегда актуальна.
enum SeedData {
    struct Dataset {
        var people: [Person]
        var challenges: [Challenge]
        var teams: [Team]
    }

    static func demoProfile() -> Person {
        Person(
            name: "Айдар Каримов",
            city: "Алматы",
            affiliation: "КазНУ, механико-математический факультет",
            headline: "Пишу на SwiftUI и собираю интерфейсы для учебных проектов",
            roles: [.mobile, .design],
            skills: ["Swift", "SwiftUI", "Figma", "Прототипирование"],
            interests: ["Образование", "Медицина", "Космос"],
            hoursPerWeek: 12,
            format: .hybrid,
            track: ["Финалист городского хакатона, 2025", "Призёр олимпиады по информатике, 2024"],
            isLookingForTeam: true
        )
    }

    static func make(now: Date = Date()) -> Dataset {
        // MARK: Люди
        let anna = Person(
            name: "Анна Ковалёва", city: "Казань", affiliation: "КФУ, ИВМиИТ",
            headline: "Компьютерное зрение для медицины. Люблю чистые датасеты.",
            roles: [.ml, .science], skills: ["Python", "PyTorch", "OpenCV", "Сегментация"],
            interests: ["Медицина", "Биотех"], hoursPerWeek: 12, format: .hybrid,
            track: ["Финал хакатона по медицинским данным, 2025", "Доклад на студенческой конференции по CV, 2026"],
            isLookingForTeam: false
        )
        let timur = Person(
            name: "Тимур Ахметов", city: "Алматы", affiliation: "КБТУ",
            headline: "iOS-разработчик, пишу на SwiftUI с 2022 года",
            roles: [.mobile], skills: ["Swift", "SwiftUI", "Core Data", "HealthKit"],
            interests: ["Образование", "Финтех", "Медицина"], hoursPerWeek: 15, format: .online,
            track: ["Победитель республиканской олимпиады по информатике, 2023"],
            isLookingForTeam: true
        )
        let maria = Person(
            name: "Мария Лебедева", city: "Санкт-Петербург", affiliation: "ИТМО",
            headline: "Продуктовый дизайнер. Исследую интерфейсы для пожилых людей.",
            roles: [.design, .product], skills: ["Figma", "UX-исследования", "Прототипирование"],
            interests: ["Медицина", "Социальные проекты"], hoursPerWeek: 10, format: .hybrid,
            track: ["Лучший дизайн на хакатоне «Доступная среда», 2025"],
            isLookingForTeam: true
        )
        let daniil = Person(
            name: "Даниил Орлов", city: "Москва", affiliation: "МФТИ",
            headline: "Бэкенд на Go, распределённые системы, олимпиадник",
            roles: [.backend, .math], skills: ["Go", "PostgreSQL", "Kubernetes", "Алгоритмы"],
            interests: ["Финтех", "Космос"], hoursPerWeek: 20, format: .offline,
            track: ["Полуфинал студенческого чемпионата по программированию, 2025"],
            isLookingForTeam: false
        )
        let aigerim = Person(
            name: "Айгерим Нурланова", city: "Астана", affiliation: "Назарбаев Университет",
            headline: "Биоинформатик: геномы, пайплайны, статистика",
            roles: [.science, .ml], skills: ["R", "Python", "Биоинформатика", "Статистика"],
            interests: ["Биотех", "Медицина", "Агротех"], hoursPerWeek: 8, format: .online,
            track: ["Публикация в студенческом журнале по геномике, 2026"],
            isLookingForTeam: true
        )
        let ilya = Person(
            name: "Илья Смирнов", city: "Новосибирск", affiliation: "НГУ, физический факультет",
            headline: "Схемотехника и прошивки. Собираю платы для кубсатов.",
            roles: [.hardware], skills: ["C", "STM32", "KiCad", "Arduino"],
            interests: ["Космос", "Робототехника", "Энергетика"], hoursPerWeek: 12, format: .offline,
            track: ["Команда студенческого спутника, 2025"],
            isLookingForTeam: false
        )
        let sofia = Person(
            name: "Софья Миронова", city: "Москва", affiliation: "ВШЭ",
            headline: "Аналитик данных: дашборды, эксперименты, A/B-тесты",
            roles: [.ml, .product], skills: ["SQL", "Python", "Pandas", "A/B-тесты"],
            interests: ["Финтех", "Образование", "Городская среда"], hoursPerWeek: 10, format: .hybrid,
            track: ["Призёр кейс-чемпионата по аналитике, 2025"],
            isLookingForTeam: true
        )
        let arseny = Person(
            name: "Арсений Волков", city: "Екатеринбург", affiliation: "УрФУ",
            headline: "Фронтенд и визуализация данных: карты, графики, WebGL",
            roles: [.web, .design], skills: ["TypeScript", "React", "D3", "WebGL"],
            interests: ["Городская среда", "Климат", "Игры"], hoursPerWeek: 14, format: .online,
            track: ["Открытая карта шума Екатеринбурга, 2025"],
            isLookingForTeam: true
        )
        let kamila = Person(
            name: "Камила Юсупова", city: "Казань", affiliation: "Университет Иннополис",
            headline: "Робототехника: ROS, навигация, SLAM",
            roles: [.hardware, .ml], skills: ["ROS", "C++", "SLAM", "Python"],
            interests: ["Робототехника", "Агротех"], hoursPerWeek: 16, format: .offline,
            track: ["Финал чемпионата мобильных роботов, 2025"],
            isLookingForTeam: false
        )
        let egor = Person(
            name: "Егор Петров", city: "Томск", affiliation: "ТПУ",
            headline: "Химик-технолог: катализ и зелёная химия",
            roles: [.science], skills: ["Химический анализ", "Хроматография", "Python"],
            interests: ["Климат", "Энергетика"], hoursPerWeek: 6, format: .hybrid,
            track: ["Грант университета на исследование катализаторов, 2025"],
            isLookingForTeam: false
        )
        let darya = Person(
            name: "Дарья Кузнецова", city: "Санкт-Петербург", affiliation: "СПбГУ, матмех",
            headline: "Теория графов и оптимизация, призёр олимпиад",
            roles: [.math], skills: ["C++", "Теория графов", "Оптимизация"],
            interests: ["Космос", "Финтех", "Игры"], hoursPerWeek: 10, format: .online,
            track: ["Диплом II степени студенческой олимпиады по математике, 2025"],
            isLookingForTeam: false
        )
        let ruslan = Person(
            name: "Руслан Ибрагимов", city: "Казань", affiliation: "КНИТУ-КАИ",
            headline: "Мобильная разработка на Kotlin и Flutter",
            roles: [.mobile, .backend], skills: ["Kotlin", "Flutter", "Firebase"],
            interests: ["Городская среда", "Социальные проекты"], hoursPerWeek: 18, format: .offline,
            track: ["Приложение для волонтёрского центра, 2025"],
            isLookingForTeam: false
        )
        let polina = Person(
            name: "Полина Соколова", city: "Нижний Новгород", affiliation: "ННГУ",
            headline: "Нейробиолог: ЭЭГ и интерфейсы мозг–компьютер",
            roles: [.science, .ml], skills: ["MATLAB", "Python", "ЭЭГ", "Обработка сигналов"],
            interests: ["Медицина", "Образование"], hoursPerWeek: 8, format: .hybrid,
            track: ["Стажировка в лаборатории нейроинтерфейсов, 2025"],
            isLookingForTeam: false
        )
        let nursultan = Person(
            name: "Нурсултан Абенов", city: "Алматы", affiliation: "Satbayev University",
            headline: "Энергетик: моделирую солнечные станции",
            roles: [.science, .math], skills: ["Моделирование", "Python", "MATLAB"],
            interests: ["Энергетика", "Климат"], hoursPerWeek: 12, format: .offline,
            track: ["Проект солнечной станции для школы, 2025"],
            isLookingForTeam: false
        )
        let veronika = Person(
            name: "Вероника Андреева", city: "Москва", affiliation: "МГУ",
            headline: "Питчи, грантовые заявки и научная коммуникация",
            roles: [.product], skills: ["Питч", "Грантовые заявки", "Тексты"],
            interests: ["Образование", "Социальные проекты", "Медицина"], hoursPerWeek: 6, format: .hybrid,
            track: ["Три поддержанные грантовые заявки, 2024–2026"],
            isLookingForTeam: true
        )
        let maxim = Person(
            name: "Максим Белов", city: "Санкт-Петербург", affiliation: "СПбПУ",
            headline: "DevOps и бэкенд на Python",
            roles: [.backend], skills: ["Python", "FastAPI", "Docker", "CI/CD"],
            interests: ["Агротех", "Городская среда"], hoursPerWeek: 12, format: .online,
            track: ["Инфраструктура для университетского хакатона, 2025"],
            isLookingForTeam: false
        )
        let aliya = Person(
            name: "Алия Сагитова", city: "Казань", affiliation: "КФУ, Высшая школа ИТИС",
            headline: "Интерфейсы и 3D-графика для игр и обучения",
            roles: [.design], skills: ["Figma", "Blender", "Моушн"],
            interests: ["Игры", "Космос", "Образование"], hoursPerWeek: 10, format: .online,
            track: ["Визуальный стиль студенческой игры, 2025"],
            isLookingForTeam: false
        )
        let gleb = Person(
            name: "Глеб Захаров", city: "Новосибирск", affiliation: "НГТУ",
            headline: "Мобильные игры на SpriteKit и Unity",
            roles: [.mobile, .web], skills: ["Swift", "SpriteKit", "Unity", "C#"],
            interests: ["Игры", "Образование"], hoursPerWeek: 20, format: .online,
            track: ["Игра-головоломка в App Store, 2025"],
            isLookingForTeam: false
        )
        let ksenia = Person(
            name: "Ксения Морозова", city: "Екатеринбург", affiliation: "УрФУ, ИЕНиМ",
            headline: "Эколог: мониторинг воды и микропластика",
            roles: [.science], skills: ["Полевые исследования", "ГИС", "Статистика"],
            interests: ["Климат", "Городская среда"], hoursPerWeek: 10, format: .offline,
            track: ["Экспедиция по малым рекам Урала, 2025"],
            isLookingForTeam: false
        )
        let artem = Person(
            name: "Артём Ким", city: "Астана", affiliation: "AITU",
            headline: "NLP и языковые модели для казахского языка",
            roles: [.ml, .backend], skills: ["Python", "Transformers", "NLP", "FastAPI"],
            interests: ["Образование", "Социальные проекты"], hoursPerWeek: 15, format: .online,
            track: ["Открытый корпус казахских текстов, 2026"],
            isLookingForTeam: true
        )
        let liza = Person(
            name: "Елизавета Новикова", city: "Томск", affiliation: "ТГУ",
            headline: "Математик-статистик: байесовские модели",
            roles: [.math, .ml], skills: ["R", "Stan", "Статистика"],
            interests: ["Медицина", "Биотех"], hoursPerWeek: 8, format: .online,
            track: ["Летняя школа по байесовской статистике, 2025"],
            isLookingForTeam: false
        )
        let timofey = Person(
            name: "Тимофей Григорьев", city: "Москва", affiliation: "МИЭТ",
            headline: "Электроника, FPGA, умные датчики",
            roles: [.hardware], skills: ["Verilog", "FPGA", "Altium", "C"],
            interests: ["Энергетика", "Городская среда", "Агротех"], hoursPerWeek: 10, format: .hybrid,
            track: ["Датчик качества воздуха для школ, 2025"],
            isLookingForTeam: true
        )

        let people = [
            anna, timur, maria, daniil, aigerim, ilya, sofia, arseny, kamila, egor, darya,
            ruslan, polina, nursultan, veronika, maxim, aliya, gleb, ksenia, artem, liza, timofey
        ]

        // MARK: События
        func day(_ offset: Int) -> Date { Fmt.date(byAddingDays: offset, to: now) }

        let northCode = Challenge(
            title: "Хакатон «Северный код»", kind: .hackathon,
            organizer: "Ассоциация студенческих IT-клубов",
            summary: "48 часов на сервис для большого города: транспорт, доступная среда, локальные сообщества. Наставники из индустрии, финал — живое демо перед жюри.",
            format: .offline, city: "Казань", startDate: day(16), registrationDeadline: day(6),
            minTeam: 2, maxTeam: 5, topics: ["Городская среда", "Социальные проекты"],
            prize: "600 000 ₽ призового фонда"
        )
        let dataset = Challenge(
            title: "Олимпиада по анализу данных «Датасет»", kind: .olympiad,
            organizer: "Лига анализа данных",
            summary: "Два тура: отборочный онлайн и финальный с реальными данными банков и клиник. Оценивают качество модели и честность валидации.",
            format: .online, city: nil, startDate: day(23), registrationDeadline: day(12),
            minTeam: 1, maxTeam: 3, topics: ["Финтех", "Медицина"],
            prize: "Стажировки и гранты на обучение"
        )
        let horizon = Challenge(
            title: "Конкурс научных проектов «Горизонт»", kind: .contest,
            organizer: "Фонд молодых исследователей «Горизонт»",
            summary: "Конкурс для студентов и школьников старших классов. Нужна гипотеза, план эксперимента и первые результаты. Финалисты защищают проект перед учёными.",
            format: .hybrid, city: "Москва", startDate: day(45), registrationDeadline: day(20),
            minTeam: 1, maxTeam: 4, topics: ["Биотех", "Медицина", "Климат", "Энергетика"],
            prize: "Грант до 1 000 000 ₽ на исследование"
        )
        let cell = Challenge(
            title: "BioHack «Клетка»", kind: .hackathon,
            organizer: "Консорциум биотехнологических лабораторий",
            summary: "Биомедицинский хакатон: от анализа сигналов до носимых устройств. Командам дают реальные обезличенные данные и доступ к оборудованию.",
            format: .offline, city: "Новосибирск", startDate: day(30), registrationDeadline: day(14),
            minTeam: 3, maxTeam: 5, topics: ["Биотех", "Медицина"],
            prize: "Три месяца работы в лаборатории"
        )
        let orbit = Challenge(
            title: "Хакатон «Орбита» по спутниковым данным", kind: .hackathon,
            organizer: "Студенческий центр космических технологий",
            summary: "Работаем с открытыми снимками Земли: пожары, паводки, урожайность. Лучшее решение полетит полезной нагрузкой на студенческом кубсате.",
            format: .online, city: nil, startDate: day(9), registrationDeadline: day(3),
            minTeam: 2, maxTeam: 4, topics: ["Космос", "Климат", "Агротех"],
            prize: "Запуск полезной нагрузки на кубсате"
        )
        let algorithm = Challenge(
            title: "Командная олимпиада «Алгоритм»", kind: .olympiad,
            organizer: "Клуб спортивного программирования",
            summary: "Пять часов, один компьютер на команду из трёх человек, двенадцать задач. Классический формат командных соревнований по программированию.",
            format: .offline, city: "Санкт-Петербург", startDate: day(38), registrationDeadline: day(18),
            minTeam: 3, maxTeam: 3, topics: [],
            prize: "Путёвка в международный финал"
        )
        let screen = Challenge(
            title: "Конкурс студенческих приложений «Экран»", kind: .contest,
            organizer: "Сообщество Swift-разработчиков",
            summary: "Приложение или игра, которые решают настоящую задачу. Оценивают идею, дизайн, доступность и качество кода. Можно участвовать в одиночку.",
            format: .online, city: nil, startDate: day(60), registrationDeadline: day(35),
            minTeam: 1, maxTeam: 3, topics: ["Образование", "Социальные проекты", "Игры"],
            prize: "Поездка на конференцию разработчиков"
        )
        let openLab = Challenge(
            title: "Грант «Открытая лаборатория»", kind: .grant,
            organizer: "Сеть университетских лабораторий",
            summary: "Финансирование на год для междисциплинарных команд. Обязательное условие — в команде есть и исследователь, и инженер.",
            format: .hybrid, city: "Томск", startDate: day(75), registrationDeadline: day(40),
            minTeam: 2, maxTeam: 6, topics: ["Климат", "Энергетика", "Агротех"],
            prize: "До 2 000 000 ₽ на 12 месяцев"
        )
        let warmHouse = Challenge(
            title: "Хакатон «Тёплый дом»", kind: .hackathon,
            organizer: "Городской центр энергоэффективности",
            summary: "Решения для энергоэффективного жилья: от датчиков в подъездах до расчёта окупаемости солнечных панелей. Лучшие проекты пилотируют с городом.",
            format: .offline, city: "Алматы", startDate: day(27), registrationDeadline: day(13),
            minTeam: 2, maxTeam: 5, topics: ["Энергетика", "Городская среда", "Климат"],
            prize: "1 500 000 ₸ и пилот с городом"
        )
        let gear = Challenge(
            title: "Чемпионат по робототехнике «Шестерня»", kind: .contest,
            organizer: "Ассоциация инженерных кружков",
            summary: "Автономный робот проходит полосу препятствий и сортирует объекты. Нужны механика, электроника и софт — одному не справиться.",
            format: .offline, city: "Екатеринбург", startDate: day(52), registrationDeadline: day(25),
            minTeam: 2, maxTeam: 4, topics: ["Робототехника", "Образование"],
            prize: "Оборудование для лаборатории"
        )
        let genome = Challenge(
            title: "Олимпиада по биоинформатике «Геном»", kind: .olympiad,
            organizer: "Школа вычислительной биологии",
            summary: "Задачи на выравнивание последовательностей, филогению и анализ экспрессии генов. Можно решать в паре.",
            format: .online, city: nil, startDate: day(33), registrationDeadline: day(19),
            minTeam: 1, maxTeam: 2, topics: ["Биотех", "Медицина"],
            prize: "Летняя школа и менторство"
        )

        let challenges = [
            orbit, northCode, dataset, warmHouse, genome, cell, algorithm,
            horizon, gear, screen, openLab
        ]

        // MARK: Команды
        let pulse = Team(
            name: "Пульс", challengeID: cell.id, field: "Медицина",
            pitch: "Нейросеть, которая по ЭКГ с носимых устройств предупреждает об аритмии за несколько часов до приступа.",
            slots: [
                Slot(role: .ml, memberID: anna.id),
                Slot(role: .science, memberID: polina.id),
                Slot(role: .mobile, note: "SwiftUI, HealthKit"),
                Slot(role: .design, note: "Медицинские интерфейсы")
            ],
            hoursPerWeek: 12, format: .offline, city: "Новосибирск",
            ownerID: anna.id, createdAt: day(-3)
        )
        let quietStreet = Team(
            name: "Тихая улица", challengeID: northCode.id, field: "Городская среда",
            pitch: "Карта шумового загрязнения города по замерам со смартфонов жителей.",
            slots: [
                Slot(role: .mobile, memberID: ruslan.id),
                Slot(role: .backend, memberID: maxim.id),
                Slot(role: .ml, note: "Обработка аудио"),
                Slot(role: .design, note: "Карта и визуальный язык")
            ],
            hoursPerWeek: 15, format: .offline, city: "Казань",
            ownerID: ruslan.id, createdAt: day(-5)
        )
        let cube = Team(
            name: "Кубик", challengeID: orbit.id, field: "Космос",
            pitch: "Оцениваем площадь лесных пожаров по открытым спутниковым снимкам и сверяем с наземными датчиками.",
            slots: [
                Slot(role: .hardware, memberID: ilya.id),
                Slot(role: .ml, note: "Сегментация снимков"),
                Slot(role: .web, note: "Карта и визуализация")
            ],
            hoursPerWeek: 10, format: .online, city: nil,
            ownerID: ilya.id, createdAt: day(-2)
        )
        let microplastic = Team(
            name: "Микропластик Исети", challengeID: nil, field: "Климат",
            pitch: "Долгосрочное исследование концентрации микропластика в реках Урала. Нужны люди для пробоотборника и анализа микроскопии.",
            slots: [
                Slot(role: .science, memberID: ksenia.id),
                Slot(role: .science, memberID: egor.id),
                Slot(role: .hardware, note: "Автоматический пробоотборник"),
                Slot(role: .ml, note: "Распознавание частиц на снимках"),
                Slot(role: .product, note: "Грантовая заявка")
            ],
            hoursPerWeek: 6, format: .hybrid, city: "Екатеринбург",
            ownerID: ksenia.id, createdAt: day(-12)
        )
        let threePeaks = Team(
            name: "Три вершины", challengeID: algorithm.id, field: "",
            pitch: "Ищем третьего на командную олимпиаду. Тренируемся по выходным, решаем архив задач.",
            slots: [
                Slot(role: .math, memberID: darya.id),
                Slot(role: .math, memberID: daniil.id),
                Slot(role: .math, note: "Динамика, строки")
            ],
            hoursPerWeek: 8, format: .offline, city: "Санкт-Петербург",
            ownerID: darya.id, createdAt: day(-7)
        )
        let solar = Team(
            name: "Солнечный счётчик", challengeID: warmHouse.id, field: "Энергетика",
            pitch: "Сервис оценивает по фото крыши выработку солнечных панелей и срок их окупаемости.",
            slots: [
                Slot(role: .science, memberID: nursultan.id),
                Slot(role: .ml, note: "Компьютерное зрение по фото крыш"),
                Slot(role: .mobile, note: "Камера и AR-разметка"),
                Slot(role: .product, note: "Питч перед жюри")
            ],
            hoursPerWeek: 12, format: .offline, city: "Алматы",
            ownerID: nursultan.id, createdAt: day(-1)
        )
        let codex = Team(
            name: "Кодекс", challengeID: screen.id, field: "Образование",
            pitch: "Обучающая игра про алгоритмы для школьников: каждый уровень — задача на графы.",
            slots: [
                Slot(role: .mobile, memberID: gleb.id),
                Slot(role: .design, memberID: aliya.id),
                Slot(role: .math, note: "Подбор и проверка задач")
            ],
            hoursPerWeek: 14, format: .online, city: nil,
            ownerID: gleb.id, createdAt: day(-4)
        )
        let neuro = Team(
            name: "Нейрореабилитация", challengeID: nil, field: "Медицина",
            pitch: "Исследуем, ускоряет ли обратная связь по ЭЭГ восстановление моторики после инсульта.",
            slots: [
                Slot(role: .math, memberID: liza.id),
                Slot(role: .science, note: "Клинические протоколы"),
                Slot(role: .hardware, note: "Сборка ЭЭГ-гарнитуры"),
                Slot(role: .mobile, note: "Приложение для пациентов")
            ],
            hoursPerWeek: 8, format: .hybrid, city: "Томск",
            ownerID: liza.id, createdAt: day(-9)
        )
        let grain = Team(
            name: "Зерно", challengeID: openLab.id, field: "Агротех",
            pitch: "Робот-разведчик для теплиц: следит за влажностью и находит болезни растений по листьям.",
            slots: [
                Slot(role: .hardware, memberID: kamila.id),
                Slot(role: .hardware, memberID: timofey.id),
                Slot(role: .ml, note: "Детекция болезней по листьям"),
                Slot(role: .backend, note: "Телеметрия и хранение данных")
            ],
            hoursPerWeek: 10, format: .hybrid, city: "Казань",
            ownerID: kamila.id, createdAt: day(-6)
        )

        let teams = [pulse, solar, cube, quietStreet, microplastic, codex, neuro, grain, threePeaks]

        return Dataset(people: people, challenges: challenges, teams: teams)
    }
}
