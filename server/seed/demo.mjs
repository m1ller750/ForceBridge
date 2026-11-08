// Демо-данные для ForceBridge. Все люди и объявления вымышленные.
// Запуск: API=https://<адрес>.workers.dev JURY_PASSWORD=<пароль> node seed/demo.mjs
//
// Создаёт участников, их объявления и демо-аккаунт для жюри:
// у него есть свои объявления с откликами и избранное, чтобы показать весь сценарий.

const API = (process.env.API ?? "").replace(/\/$/, "");
const JURY_EMAIL = process.env.JURY_EMAIL ?? "jury.forcebridge@example.com";
const JURY_PASSWORD = process.env.JURY_PASSWORD ?? "";

if (!API) {
  console.error("Укажите адрес API: API=https://... node seed/demo.mjs");
  process.exit(1);
}

async function call(method, path, token, body) {
  const res = await fetch(`${API}/${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (!res.ok) {
    const error = new Error(`${method} ${path} → ${res.status}: ${typeof data === "object" ? data?.error : data}`);
    error.status = res.status;
    throw error;
  }
  return data;
}

async function account(email, password) {
  try {
    return await call("POST", "auth/register", null, { email, password });
  } catch (error) {
    if (error.status === 409) return call("POST", "auth/login", null, { email, password });
    throw error;
  }
}

const day = (offset) => {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  return d.toISOString().slice(0, 10);
};

// Контакт демо-профилей заведомо ненастоящий: «Другое → Демо-профиль».
const DEMO_CONTACT = { messenger: "other", contact: "Демо-профиль ForceBridge" };

const people = [
  {
    key: "anna",
    profile: {
      fullName: "Анна Ковалёва", age: 21, city: "Казань",
      occupation: "Студентка КФУ, компьютерное зрение для медицины",
      about: "Делаю сегментацию медицинских снимков. Ищу команду, где ML решает реальную задачу врачей.",
      skills: ["Python", "PyTorch", "OpenCV", "Сегментация"],
      projects: ["Детектор пневмонии по рентгену, 2025"],
      achievements: ["Финалист хакатона по медицинским данным, 2025"],
    },
    cards: [
      {
        kind: "teammate", title: "Ищу iOS-разработчика на биомедицинский хакатон",
        eventName: "BioHack «Клетка»",
        description: "Делаем приложение, которое по ЭКГ с часов предупреждает об аритмии. Модель уже обучена, нужен человек, который соберёт клиент на SwiftUI с HealthKit и покажет демо жюри.",
        roles: ["iOS-разработчик", "SwiftUI", "HealthKit"], city: "Новосибирск", format: "offline", deadline: day(14),
      },
    ],
  },
  {
    key: "timur",
    profile: {
      fullName: "Тимур Ахметов", age: 19, city: "Алматы",
      occupation: "iOS-разработчик, студент КБТУ",
      about: "Пишу на SwiftUI с 2022 года, люблю аккуратные интерфейсы и быстрые прототипы.",
      skills: ["Swift", "SwiftUI", "Core Data", "Figma"],
      projects: ["Трекер привычек для студентов", "Приложение расписания КБТУ"],
      achievements: ["Победитель республиканской олимпиады по информатике, 2023"],
    },
    cards: [
      {
        kind: "join", title: "iOS-разработчик ищет команду на конкурс приложений",
        eventName: "Конкурс студенческих приложений",
        description: "Готов взять на себя мобильную часть: SwiftUI, архитектура, публикация в TestFlight. Интересны образование и финтех. Ищу команду с дизайнером и бэкендером.",
        roles: ["iOS", "SwiftUI"], city: "Алматы", format: "any", deadline: day(30),
      },
    ],
  },
  {
    key: "maria",
    profile: {
      fullName: "Мария Лебедева", age: 22, city: "Санкт-Петербург",
      occupation: "Продуктовый дизайнер, ИТМО",
      about: "Исследую интерфейсы для пожилых людей и медицинских сервисов.",
      skills: ["Figma", "UX-исследования", "Прототипирование"],
      projects: ["Редизайн записи к врачу для пенсионеров"],
      achievements: ["Лучший дизайн на хакатоне «Доступная среда», 2025"],
    },
    cards: [],
  },
  {
    key: "ksenia",
    profile: {
      fullName: "Ксения Морозова", age: 23, city: "Екатеринбург",
      occupation: "Эколог, магистрантка УрФУ",
      about: "Изучаю микропластик в реках Урала. Нужны люди, которые помогут автоматизировать отбор проб и анализ.",
      skills: ["Полевые исследования", "ГИС", "Статистика"],
      projects: ["Мониторинг малых рек Урала"],
      achievements: ["Грант университета на экспедицию, 2025"],
    },
    cards: [
      {
        kind: "research", title: "Нужен химик для исследования микропластика в реках",
        eventName: "",
        description: "Долгосрочное исследование концентрации микропластика в реках Урала. Ищем химика, который поставит методику идентификации частиц, и человека с ML для распознавания частиц на снимках микроскопа.",
        roles: ["Химик-аналитик", "ML-инженер"], city: "Екатеринбург", format: "any", deadline: null,
      },
    ],
  },
  {
    key: "ilya",
    profile: {
      fullName: "Илья Смирнов", age: 20, city: "Новосибирск",
      occupation: "Схемотехник, физфак НГУ",
      about: "Собираю платы для кубсатов и датчики. Хочу на хакатон по спутниковым данным.",
      skills: ["C", "STM32", "KiCad", "Arduino"],
      projects: ["Плата телеметрии студенческого спутника"],
      achievements: ["Команда студенческого спутника, 2025"],
    },
    cards: [
      {
        kind: "teammate", title: "Ищем ML-инженера на хакатон по спутниковым снимкам",
        eventName: "Хакатон «Орбита»",
        description: "Оцениваем площадь лесных пожаров по открытым снимкам Sentinel и сверяем с наземными датчиками. Железо и датчики на мне, нужен человек на сегментацию снимков и фронтенд для карты.",
        roles: ["ML-инженер", "Фронтенд", "Компьютерное зрение"], city: "", format: "online", deadline: day(5),
      },
    ],
  },
  {
    key: "aigerim",
    profile: {
      fullName: "Айгерим Нурланова", age: 22, city: "Астана",
      occupation: "Биоинформатик, Назарбаев Университет",
      about: "Геномы, пайплайны, статистика. Ищу людей для научной статьи и олимпиады по биоинформатике.",
      skills: ["R", "Python", "Биоинформатика", "Статистика"],
      projects: ["Анализ экспрессии генов при засухе у пшеницы"],
      achievements: ["Публикация в студенческом журнале по геномике, 2026"],
    },
    cards: [
      {
        kind: "teammate", title: "Ищу напарника на олимпиаду по биоинформатике",
        eventName: "Олимпиада по биоинформатике",
        description: "Командный зачёт по двое. Задачи на выравнивание, филогению и анализ экспрессии. Нужен человек с сильным программированием на Python или C++ — биологию объясню.",
        roles: ["Программист", "Алгоритмы"], city: "", format: "online", deadline: day(19),
      },
      {
        kind: "research", title: "Нужен статистик для исследования устойчивости пшеницы",
        eventName: "",
        description: "Готовим статью по экспрессии генов пшеницы при засухе. Данные собраны, нужен человек, который поможет с байесовскими моделями и визуализацией результатов.",
        roles: ["Статистик", "Визуализация данных"], city: "Астана", format: "any", deadline: day(45),
      },
    ],
  },
  {
    key: "ruslan",
    profile: {
      fullName: "Руслан Ибрагимов", age: 21, city: "Казань",
      occupation: "Мобильная разработка на Kotlin и Flutter",
      about: "Делаю городские сервисы. Сейчас собираю команду на хакатон про городскую среду.",
      skills: ["Kotlin", "Flutter", "Firebase"],
      projects: ["Приложение для волонтёрского центра"],
      achievements: ["Призёр городского хакатона, 2025"],
    },
    cards: [
      {
        kind: "teammate", title: "Собираю команду на хакатон «Северный код»",
        eventName: "Хакатон «Северный код»",
        description: "Делаем карту шумового загрязнения города по замерам со смартфонов жителей. Нужны дизайнер интерфейсов и человек на обработку аудио. 48 часов, финал — живое демо перед жюри.",
        roles: ["Дизайнер", "Обработка звука", "Data Science"], city: "Казань", format: "offline", deadline: day(9),
      },
    ],
  },
  {
    key: "nursultan",
    profile: {
      fullName: "Нурсултан Абенов", age: 24, city: "Алматы",
      occupation: "Энергетик, моделирую солнечные станции",
      about: "Хочу сделать сервис оценки окупаемости солнечных панелей по фото крыши.",
      skills: ["Моделирование", "Python", "MATLAB"],
      projects: ["Проект солнечной станции для школы"],
      achievements: ["Диплом конкурса молодых энергетиков, 2025"],
    },
    cards: [
      {
        kind: "teammate", title: "Нужен питчер и мобильный разработчик в энергетический стартап",
        eventName: "Хакатон «Тёплый дом»",
        description: "Сервис по фото крыши оценивает выработку солнечных панелей и срок окупаемости. Расчётная модель готова. Ищем мобильного разработчика и человека, который сделает сильный питч.",
        roles: ["Мобильный разработчик", "Питчер"], city: "Алматы", format: "offline", deadline: day(13),
      },
    ],
  },
];

const juryCards = [
  {
    kind: "teammate", title: "Ищу дизайнера и ML-инженера на конкурс социальных проектов",
    eventName: "Конкурс социальных инноваций",
    description: "Делаем помощника для людей с нарушением зрения: камера распознаёт ценники и вывески и озвучивает их. Нужен дизайнер доступных интерфейсов и человек с опытом компьютерного зрения.",
    roles: ["Дизайнер", "ML-инженер", "Компьютерное зрение"], city: "Алматы", format: "any", deadline: day(21),
  },
  {
    kind: "research", title: "Ищу соавтора для исследования цифровой грамотности школьников",
    eventName: "",
    description: "Опрашиваем школьников 8–11 классов о том, как они проверяют информацию в интернете. Нужен человек, который поможет со статистическим анализом и визуализацией результатов.",
    roles: ["Аналитик данных", "Социолог"], city: "", format: "online", deadline: day(40),
  },
];

const responses = [
  { from: "maria", to: 0, message: "Проектирую интерфейсы для людей с ограничениями зрения — с удовольствием возьму дизайн." },
  { from: "anna", to: 0, message: "Компьютерное зрение — мой профиль. Есть наработки по распознаванию текста на фото." },
  { from: "timur", to: 0, message: "Могу собрать iOS-клиент с VoiceOver и камерой." },
  { from: "aigerim", to: 1, message: "Помогу со статистикой и визуализацией, есть опыт с опросными данными." },
];

const tokens = {};
let created = 0;

for (const person of people) {
  const email = `demo.${person.key}@example.com`;
  const auth = await account(email, crypto.randomUUID());
  tokens[person.key] = auth.token;
  await call("PUT", "profile", auth.token, { ...person.profile, ...DEMO_CONTACT });
  for (const card of person.cards) {
    await call("POST", "cards", auth.token, card);
    created += 1;
  }
  console.log(`✓ ${person.profile.fullName}`);
}

if (JURY_PASSWORD) {
  const jury = await account(JURY_EMAIL, JURY_PASSWORD);
  await call("PUT", "profile", jury.token, {
    fullName: "Жюри Демо",
    age: 30,
    city: "Алматы",
    occupation: "Демо-аккаунт для проверки ForceBridge",
    about: "Этот аккаунт показывает весь сценарий: свои объявления, отклики на них и избранное.",
    skills: ["Проверка проектов"],
    projects: [],
    achievements: [],
    ...DEMO_CONTACT,
  });
  const cardIds = [];
  for (const card of juryCards) {
    const saved = await call("POST", "cards", jury.token, card);
    cardIds.push(saved.id);
    created += 1;
  }
  for (const r of responses) {
    await call("POST", `cards/${cardIds[r.to]}/responses`, tokens[r.from], { message: r.message });
  }
  const me = await call("GET", "me", tokens.maria);
  await call("PUT", `favorites/${me.userId}`, jury.token);
  console.log(`✓ Демо-аккаунт жюри: ${JURY_EMAIL}`);
}

console.log(`Готово: участников ${people.length}, объявлений ${created}.`);
