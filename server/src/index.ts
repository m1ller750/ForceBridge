// ForceBridge API — Cloudflare Worker + D1 (SQLite) + Groq.
//
// Привязки и переменные (wrangler.toml и панель Cloudflare):
//   DB            — база D1
//   GROQ_API_KEY  — секрет с ключом Groq (wrangler secret put GROQ_API_KEY)
//   GROQ_MODEL    — необязательно: модель или список моделей через запятую
//
// Схема базы создаётся автоматически при первом запросе.

interface Env {
  DB: any;
  GROQ_API_KEY?: string;
  GROQ_MODEL?: string;
}

class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

// ---------------------------------------------------------------------------
// Справочники
// ---------------------------------------------------------------------------
const KINDS = ["teammate", "research", "join"];
const FORMATS = ["online", "offline", "any"];
const MESSENGERS = ["telegram", "whatsapp", "instagram", "tiktok", "vk", "discord", "phone", "other"];
const RESUME_TYPES = [
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "image/jpeg",
  "image/png",
];
const MAX_RESUME_BYTES = 1_800_000;
const PBKDF2_ITERATIONS = 20_000;

const CATEGORIES = [
  { key: "hackathon", title: "Хакатоны", grp: "format", sort: 1 },
  { key: "olympiad", title: "Олимпиады", grp: "format", sort: 2 },
  { key: "contest", title: "Конкурсы и чемпионаты", grp: "format", sort: 3 },
  { key: "research", title: "Научные исследования", grp: "format", sort: 4 },
  { key: "startup", title: "Стартапы и проекты", grp: "format", sort: 5 },
  { key: "it", title: "IT и разработка", grp: "field", sort: 10 },
  { key: "ai", title: "ИИ и данные", grp: "field", sort: 11 },
  { key: "design", title: "Дизайн", grp: "field", sort: 12 },
  { key: "engineering", title: "Инженерия и робототехника", grp: "field", sort: 13 },
  { key: "biomed", title: "Биология и медицина", grp: "field", sort: 14 },
  { key: "physchem", title: "Физика и химия", grp: "field", sort: 15 },
  { key: "math", title: "Математика", grp: "field", sort: 16 },
  { key: "ecology", title: "Экология", grp: "field", sort: 17 },
  { key: "business", title: "Бизнес и маркетинг", grp: "field", sort: 18 },
  { key: "social", title: "Социальные проекты", grp: "field", sort: 19 },
  { key: "media", title: "Медиа и искусство", grp: "field", sort: 20 },
  { key: "education", title: "Образование", grp: "field", sort: 21 },
];
const CATEGORY_KEYS = new Set(CATEGORIES.map((c) => c.key));
const FORMAT_KEYS = new Set(CATEGORIES.filter((c) => c.grp === "format").map((c) => c.key));

const KIND_TITLES: Record<string, string> = {
  teammate: "Ищу сокомандника",
  research: "Нужен человек для исследования",
  join: "Ищу команду",
};
const FORMAT_TITLES: Record<string, string> = { online: "онлайн", offline: "очно", any: "любой" };

// ---------------------------------------------------------------------------
// Схема базы
// ---------------------------------------------------------------------------
const SCHEMA = [
  `CREATE TABLE IF NOT EXISTS users (
     id TEXT PRIMARY KEY,
     email TEXT NOT NULL UNIQUE,
     password_hash TEXT NOT NULL,
     created_at TEXT NOT NULL
   )`,
  `CREATE TABLE IF NOT EXISTS sessions (
     token_hash TEXT PRIMARY KEY,
     user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
     created_at TEXT NOT NULL,
     expires_at TEXT NOT NULL
   )`,
  `CREATE INDEX IF NOT EXISTS sessions_user_idx ON sessions (user_id)`,
  `CREATE TABLE IF NOT EXISTS profiles (
     id TEXT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
     full_name TEXT NOT NULL,
     age INTEGER,
     city TEXT NOT NULL DEFAULT '',
     occupation TEXT NOT NULL DEFAULT '',
     about TEXT NOT NULL DEFAULT '',
     skills TEXT NOT NULL DEFAULT '[]',
     projects TEXT NOT NULL DEFAULT '[]',
     achievements TEXT NOT NULL DEFAULT '[]',
     messenger TEXT NOT NULL,
     contact TEXT NOT NULL,
     created_at TEXT NOT NULL,
     updated_at TEXT NOT NULL
   )`,
  `CREATE TABLE IF NOT EXISTS resumes (
     user_id TEXT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
     data BLOB NOT NULL,
     content_type TEXT NOT NULL,
     file_name TEXT NOT NULL,
     updated_at TEXT NOT NULL
   )`,
  `CREATE TABLE IF NOT EXISTS categories (
     key TEXT PRIMARY KEY,
     title TEXT NOT NULL,
     grp TEXT NOT NULL,
     sort INTEGER NOT NULL DEFAULT 0
   )`,
  `CREATE TABLE IF NOT EXISTS cards (
     id TEXT PRIMARY KEY,
     author_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
     kind TEXT NOT NULL,
     title TEXT NOT NULL,
     description TEXT NOT NULL,
     event_name TEXT NOT NULL DEFAULT '',
     roles TEXT NOT NULL DEFAULT '[]',
     city TEXT NOT NULL DEFAULT '',
     format TEXT NOT NULL DEFAULT 'any',
     deadline TEXT,
     ai_status TEXT NOT NULL DEFAULT 'pending',
     content_version INTEGER NOT NULL DEFAULT 1,
     search_text TEXT NOT NULL DEFAULT '',
     created_at TEXT NOT NULL,
     updated_at TEXT NOT NULL
   )`,
  `CREATE INDEX IF NOT EXISTS cards_created_idx ON cards (created_at)`,
  `CREATE INDEX IF NOT EXISTS cards_author_idx ON cards (author_id)`,
  `CREATE INDEX IF NOT EXISTS cards_status_idx ON cards (ai_status)`,
  `CREATE TABLE IF NOT EXISTS card_categories (
     card_id TEXT NOT NULL REFERENCES cards (id) ON DELETE CASCADE,
     category TEXT NOT NULL REFERENCES categories (key),
     PRIMARY KEY (card_id, category)
   )`,
  `CREATE INDEX IF NOT EXISTS card_categories_category_idx ON card_categories (category, card_id)`,
  `CREATE TABLE IF NOT EXISTS responses (
     id TEXT PRIMARY KEY,
     card_id TEXT NOT NULL REFERENCES cards (id) ON DELETE CASCADE,
     user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
     message TEXT NOT NULL DEFAULT '',
     hidden INTEGER NOT NULL DEFAULT 0,
     created_at TEXT NOT NULL,
     UNIQUE (card_id, user_id)
   )`,
  `CREATE INDEX IF NOT EXISTS responses_card_idx ON responses (card_id)`,
  `CREATE INDEX IF NOT EXISTS responses_user_idx ON responses (user_id)`,
  `CREATE TABLE IF NOT EXISTS favorites (
     owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
     profile_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
     created_at TEXT NOT NULL,
     PRIMARY KEY (owner_id, profile_id)
   )`,
  `CREATE TABLE IF NOT EXISTS compatibility (
     card_id TEXT NOT NULL REFERENCES cards (id) ON DELETE CASCADE,
     user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
     score INTEGER NOT NULL,
     summary TEXT NOT NULL DEFAULT '',
     strengths TEXT NOT NULL DEFAULT '[]',
     gaps TEXT NOT NULL DEFAULT '[]',
     card_version TEXT NOT NULL,
     profile_version TEXT NOT NULL,
     created_at TEXT NOT NULL,
     PRIMARY KEY (card_id, user_id)
   )`,
];

const CATEGORY_UPSERT =
  `INSERT INTO categories (key, title, grp, sort) VALUES ` +
  CATEGORIES.map(() => "(?, ?, ?, ?)").join(", ") +
  ` ON CONFLICT (key) DO UPDATE SET title = excluded.title, grp = excluded.grp, sort = excluded.sort`;

let schemaReady: Promise<void> | null = null;

function ensureSchema(env: Env): Promise<void> {
  if (!schemaReady) {
    schemaReady = (async () => {
      const statements = SCHEMA.map((s) => env.DB.prepare(s));
      const values: unknown[] = [];
      for (const c of CATEGORIES) values.push(c.key, c.title, c.grp, c.sort);
      statements.push(env.DB.prepare(CATEGORY_UPSERT).bind(...values));
      await env.DB.batch(statements);
    })().catch((error) => {
      schemaReady = null;
      throw error;
    });
  }
  return schemaReady;
}

// ---------------------------------------------------------------------------
// Утилиты
// ---------------------------------------------------------------------------
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const encoder = new TextEncoder();

function nowISO(): string {
  return new Date().toISOString();
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function empty(status = 204): Response {
  return new Response(null, { status });
}

async function readJSON(req: Request): Promise<any> {
  try {
    return await req.json();
  } catch {
    throw new ApiError(400, "Некорректный запрос");
  }
}

function text(value: unknown, max: number): string {
  return String(value ?? "").trim().slice(0, max);
}

function textList(value: unknown, maxItems = 30, maxLength = 200): string[] {
  if (!Array.isArray(value)) return [];
  const result: string[] = [];
  for (const item of value) {
    const s = String(item ?? "").trim().slice(0, maxLength);
    if (s && !result.includes(s)) result.push(s);
    if (result.length >= maxItems) break;
  }
  return result;
}

function parseList(value: unknown): string[] {
  if (Array.isArray(value)) return value.map((v) => String(v));
  if (typeof value !== "string" || !value) return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.filter((v) => v !== null).map((v) => String(v)) : [];
  } catch {
    return [];
  }
}

function uuidParam(value: string | undefined, what: string): string {
  if (!value || !UUID_RE.test(value)) throw new ApiError(404, `${what} не найдено`);
  return value.toLowerCase();
}

function hex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return hex(new Uint8Array(digest));
}

function toBase64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

function fromBase64(value: string): Uint8Array {
  const s = atob(value);
  const bytes = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) bytes[i] = s.charCodeAt(i);
  return bytes;
}

async function pbkdf2(password: string, salt: Uint8Array, iterations: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, 256);
  return new Uint8Array(bits);
}

async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt, PBKDF2_ITERATIONS);
  return `pbkdf2$${PBKDF2_ITERATIONS}$${toBase64(salt)}$${toBase64(hash)}`;
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [scheme, iterations, saltB64, hashB64] = String(stored).split("$");
  if (scheme !== "pbkdf2" || !saltB64 || !hashB64) return false;
  const expected = fromBase64(hashB64);
  const actual = await pbkdf2(password, fromBase64(saltB64), Number(iterations) || PBKDF2_ITERATIONS);
  if (actual.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < actual.length; i++) diff |= actual[i] ^ expected[i];
  return diff === 0;
}

function blobBytes(value: unknown): Uint8Array {
  if (value instanceof Uint8Array) return value;
  if (value instanceof ArrayBuffer) return new Uint8Array(value);
  if (Array.isArray(value)) return new Uint8Array(value as number[]);
  return new Uint8Array(0);
}

function searchText(card: { title: string; description: string; eventName: string; roles: string[] }, authorName: string): string {
  return [card.title, card.description, card.eventName, card.roles.join(" "), authorName].join(" ").toLowerCase();
}

// ---------------------------------------------------------------------------
// Сессии
// ---------------------------------------------------------------------------
async function createSession(env: Env, userId: string): Promise<string> {
  const token = hex(crypto.getRandomValues(new Uint8Array(32)));
  const expires = new Date(Date.now() + 90 * 24 * 3600 * 1000).toISOString();
  await env.DB.prepare("INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)")
    .bind(await sha256Hex(token), userId, nowISO(), expires)
    .run();
  return token;
}

function bearer(req: Request): string {
  return (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
}

async function requireUser(req: Request, env: Env): Promise<string> {
  const token = bearer(req);
  if (!token) throw new ApiError(401, "Войдите в аккаунт");
  const row = await env.DB.prepare("SELECT user_id FROM sessions WHERE token_hash = ? AND expires_at > ?")
    .bind(await sha256Hex(token), nowISO())
    .first();
  if (!row) throw new ApiError(401, "Сессия истекла — войдите снова");
  return row.user_id as string;
}

async function requireProfile(env: Env, uid: string): Promise<any> {
  const row = await env.DB.prepare("SELECT * FROM profiles WHERE id = ?").bind(uid).first();
  if (!row) throw new ApiError(400, "Сначала заполните паспорт участника");
  return row;
}

// ---------------------------------------------------------------------------
// Представление данных
// ---------------------------------------------------------------------------
const PROFILE_COLUMNS = `
  p.id, p.full_name, p.age, p.city, p.occupation, p.about, p.skills, p.projects, p.achievements,
  p.messenger, p.contact, p.created_at, p.updated_at,
  r.file_name AS resume_name, r.content_type AS resume_type`;

function profileJSON(row: any) {
  return {
    id: row.id,
    fullName: row.full_name,
    age: row.age ?? null,
    city: row.city ?? "",
    occupation: row.occupation ?? "",
    about: row.about ?? "",
    skills: parseList(row.skills),
    projects: parseList(row.projects),
    achievements: parseList(row.achievements),
    messenger: row.messenger,
    contact: row.contact,
    resumeName: row.resume_name ?? null,
    resumeType: row.resume_type ?? null,
    createdAt: row.created_at ?? null,
    updatedAt: row.updated_at ?? null,
  };
}

/** Колонки карточки. Первый параметр запроса — id просматривающего (для числа откликов). */
const CARD_COLUMNS = `
  c.id, c.author_id, c.kind, c.title, c.description, c.event_name, c.roles, c.city, c.format,
  c.deadline, c.ai_status, c.created_at, c.updated_at,
  CASE WHEN c.author_id = ?
    THEN (SELECT COUNT(*) FROM responses x WHERE x.card_id = c.id AND x.hidden = 0)
  END AS responses_count,
  (SELECT json_group_array(cc.category) FROM card_categories cc WHERE cc.card_id = c.id) AS categories,
  p.full_name AS author_name, p.city AS author_city, p.occupation AS author_occupation`;

function cardJSON(row: any) {
  return {
    id: row.id,
    authorId: row.author_id,
    kind: row.kind,
    title: row.title,
    description: row.description,
    eventName: row.event_name ?? "",
    roles: parseList(row.roles),
    city: row.city ?? "",
    format: row.format,
    deadline: row.deadline ?? null,
    categories: parseList(row.categories),
    aiStatus: row.ai_status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    authorName: row.author_name ?? null,
    authorCity: row.author_city ?? null,
    authorOccupation: row.author_occupation ?? null,
    responsesCount: row.responses_count ?? null,
  };
}

function responseJSON(row: any) {
  return {
    id: row.response_id,
    cardId: row.response_card_id,
    userId: row.response_user_id,
    message: row.response_message ?? "",
    hidden: Number(row.response_hidden) === 1,
    createdAt: row.response_created_at,
  };
}

async function loadProfile(env: Env, id: string) {
  const row = await env.DB.prepare(
    `SELECT ${PROFILE_COLUMNS} FROM profiles p LEFT JOIN resumes r ON r.user_id = p.id WHERE p.id = ?`,
  )
    .bind(id)
    .first();
  return row ? profileJSON(row) : null;
}

async function loadCard(env: Env, id: string, uid: string) {
  const row = await env.DB.prepare(
    `SELECT ${CARD_COLUMNS} FROM cards c JOIN profiles p ON p.id = c.author_id WHERE c.id = ?`,
  )
    .bind(uid, id)
    .first();
  return row ? cardJSON(row) : null;
}

function normalizeProfile(body: any) {
  const fullName = text(body.fullName, 80);
  const age = Number.parseInt(String(body.age ?? ""), 10);
  const city = text(body.city, 80);
  const occupation = text(body.occupation, 300);
  const messenger = text(body.messenger, 20);
  const contact = text(body.contact, 80);
  if (fullName.length < 2) throw new ApiError(400, "Укажите имя и фамилию");
  if (!Number.isFinite(age) || age < 10 || age > 99) throw new ApiError(400, "Укажите возраст от 10 до 99");
  if (!city) throw new ApiError(400, "Укажите город");
  if (!occupation) throw new ApiError(400, "Напишите, чем вы занимаетесь");
  if (!MESSENGERS.includes(messenger)) throw new ApiError(400, "Выберите мессенджер для связи");
  if (contact.length < 2) throw new ApiError(400, "Укажите юзернейм или номер для связи");
  return {
    fullName,
    age,
    city,
    occupation,
    about: text(body.about, 1500),
    skills: textList(body.skills, 40, 60),
    projects: textList(body.projects, 30, 300),
    achievements: textList(body.achievements, 30, 300),
    messenger,
    contact,
  };
}

function normalizeCard(body: any) {
  const kind = text(body.kind, 20);
  const title = text(body.title, 120);
  const description = text(body.description, 3000);
  const format = text(body.format, 20);
  const deadline = body.deadline == null ? "" : text(body.deadline, 10);
  if (!KINDS.includes(kind)) throw new ApiError(400, "Выберите тип объявления");
  if (title.length < 3) throw new ApiError(400, "Заголовок — минимум 3 символа");
  if (description.length < 10) throw new ApiError(400, "Описание — минимум 10 символов");
  if (!FORMATS.includes(format)) throw new ApiError(400, "Выберите формат");
  if (deadline && !/^\d{4}-\d{2}-\d{2}$/.test(deadline)) throw new ApiError(400, "Некорректный дедлайн");
  return {
    kind,
    title,
    description,
    eventName: text(body.eventName, 160),
    roles: textList(body.roles, 12, 60),
    city: format === "online" ? "" : text(body.city, 80),
    format,
    deadline: deadline || null,
  };
}

// ---------------------------------------------------------------------------
// Groq
// ---------------------------------------------------------------------------
const GROQ_CHAT = "https://api.groq.com/openai/v1/chat/completions";
const GROQ_MODELS = "https://api.groq.com/openai/v1/models";
const PREFERRED_MODELS = [
  "openai/gpt-oss-120b",
  "openai/gpt-oss-20b",
  "llama-3.3-70b-versatile",
  "meta-llama/llama-4-scout-17b-16e-instruct",
];
let discoveredModels: string[] | null = null;

function configuredModels(env: Env): string[] {
  const custom = (env.GROQ_MODEL ?? "").split(",").map((m) => m.trim()).filter(Boolean);
  return [...new Set([...custom, ...PREFERRED_MODELS])];
}

async function discoverModels(key: string): Promise<string[]> {
  if (discoveredModels) return discoveredModels;
  try {
    const res = await fetch(GROQ_MODELS, { headers: { Authorization: `Bearer ${key}` } });
    if (!res.ok) return [];
    const data: any = await res.json();
    const ids: string[] = (data?.data ?? []).map((m: { id: string }) => m.id);
    discoveredModels = ids.filter((id) => !/whisper|guard|tts|orpheus|compound|playai/i.test(id));
    return discoveredModels;
  } catch {
    return [];
  }
}

function callModel(key: string, model: string, system: string, user: string, maxTokens: number, jsonMode: boolean) {
  const body: Record<string, unknown> = {
    model,
    temperature: 0.25,
    max_completion_tokens: maxTokens,
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
  };
  if (jsonMode) body.response_format = { type: "json_object" };
  if (model.startsWith("openai/gpt-oss")) body.reasoning_effort = "low";
  return fetch(GROQ_CHAT, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function extractJSON(content: string): any {
  try {
    return JSON.parse(content);
  } catch {
    const start = content.indexOf("{");
    const end = content.lastIndexOf("}");
    if (start >= 0 && end > start) return JSON.parse(content.slice(start, end + 1));
    throw new Error("AI returned a non-JSON answer");
  }
}

async function groqJSON(env: Env, system: string, user: string, maxTokens: number): Promise<any> {
  const key = env.GROQ_API_KEY;
  if (!key) throw new Error("GROQ_API_KEY is not configured");

  const tried = new Set<string>();
  let lastError = "no models available";
  let queue = configuredModels(env);

  for (let pass = 0; pass < 2; pass++) {
    for (const model of queue) {
      if (tried.has(model)) continue;
      tried.add(model);

      let res = await callModel(key, model, system, user, maxTokens, true);
      if (res.status === 400) {
        const body = await res.text();
        if (/response_format|json_object|json mode/i.test(body)) {
          res = await callModel(key, model, system, user, maxTokens, false);
        } else {
          lastError = `${model}: 400 ${body.slice(0, 300)}`;
          continue;
        }
      }
      if (res.ok) {
        const data: any = await res.json();
        return extractJSON(String(data?.choices?.[0]?.message?.content ?? ""));
      }
      const body = await res.text();
      lastError = `${model}: ${res.status} ${body.slice(0, 300)}`;
      if (res.status === 401 || res.status === 403) throw new Error("Groq rejected the API key");
    }
    if (pass === 0) {
      queue = (await discoverModels(key)).filter((m) => !tried.has(m));
      if (queue.length === 0) break;
    }
  }
  throw new Error(lastError);
}

function aiErrorMessage(error: unknown): string {
  const message = String(error);
  if (message.includes("GROQ_API_KEY")) return "ИИ ещё не подключён: добавьте секрет GROQ_API_KEY в Cloudflare.";
  if (message.includes("rejected the API key")) return "Groq не принял ключ — проверьте GROQ_API_KEY.";
  if (message.includes("429")) return "ИИ перегружен запросами. Попробуйте через минуту.";
  return "ИИ не смог ответить. Попробуйте ещё раз.";
}

// ---------------------------------------------------------------------------
// ИИ: категории
// ---------------------------------------------------------------------------
async function classifyText(env: Env, card: any): Promise<string[]> {
  const list = CATEGORIES.map((c) => `- ${c.key}: ${c.title} (${c.grp === "format" ? "формат" : "область"})`).join("\n");
  const system =
    "Ты — классификатор объявлений платформы ForceBridge, где люди ищут сокомандников " +
    "для хакатонов, олимпиад, конкурсов, стартапов и научных исследований. " +
    "Отнеси объявление ко ВСЕМ подходящим категориям из списка — обычно от 2 до 5. " +
    "Старайся выбрать хотя бы одну категорию формата и хотя бы одну категорию области. " +
    "Используй только ключи из списка. " +
    'Ответь строго в формате JSON: {"categories": ["key1", "key2"]}.';
  const user =
    `Категории:\n${list}\n\nОбъявление:\n` +
    `Тип: ${KIND_TITLES[card.kind] ?? card.kind}\n` +
    `Заголовок: ${card.title}\n` +
    `Событие: ${card.event_name || "—"}\n` +
    `Кого ищут: ${parseList(card.roles).join(", ") || "—"}\n` +
    `Описание: ${String(card.description).slice(0, 2000)}`;
  const out = await groqJSON(env, system, user, 1200);
  const raw: unknown[] = Array.isArray(out?.categories) ? out.categories : [];
  const keys = [...new Set(raw.map((k) => String(k).trim().toLowerCase()).filter((k) => CATEGORY_KEYS.has(k)))];
  if (keys.length === 0 && card.kind === "research") keys.push("research");
  return keys.slice(0, 6);
}

const classifying = new Set<string>();
const rerun = new Set<string>();

/** ИИ читает карточку и записывает её категории. Устаревший результат отбрасывается по content_version. */
async function classifyCard(env: Env, id: string): Promise<void> {
  if (classifying.has(id)) {
    rerun.add(id);
    return;
  }
  classifying.add(id);
  try {
    do {
      rerun.delete(id);
      const card: any = await env.DB.prepare(
        "SELECT id, kind, title, description, event_name, roles, content_version, ai_status FROM cards WHERE id = ?",
      )
        .bind(id)
        .first();
      if (!card || card.ai_status === "done") break;
      const version = card.content_version;
      try {
        const keys = await classifyText(env, card);
        const statements = [
          env.DB.prepare(
            "DELETE FROM card_categories WHERE card_id = ? AND (SELECT content_version FROM cards WHERE id = ?) = ?",
          ).bind(id, id, version),
          ...keys.map((key) =>
            env.DB.prepare(
              "INSERT OR IGNORE INTO card_categories (card_id, category) " +
                "SELECT ?, ? WHERE (SELECT content_version FROM cards WHERE id = ?) = ?",
            ).bind(id, key, id, version),
          ),
          env.DB.prepare("UPDATE cards SET ai_status = 'done' WHERE id = ? AND content_version = ?").bind(id, version),
        ];
        await env.DB.batch(statements);
      } catch (error) {
        console.error("classification failed", id, String(error));
        await env.DB.prepare("UPDATE cards SET ai_status = 'error' WHERE id = ? AND content_version = ?")
          .bind(id, version)
          .run();
      }
    } while (rerun.has(id));
  } finally {
    classifying.delete(id);
  }
}

async function classifyPending(env: Env, limit: number): Promise<number> {
  const { results } = await env.DB.prepare(
    "SELECT id FROM cards WHERE ai_status <> 'done' ORDER BY updated_at LIMIT ?",
  )
    .bind(limit)
    .all();
  for (const row of results ?? []) {
    await classifyCard(env, row.id as string);
  }
  return (results ?? []).length;
}

// ---------------------------------------------------------------------------
// ИИ: совместимость
// ---------------------------------------------------------------------------
function joinList(items: string[]): string {
  const clean = items.map((s) => s.trim()).filter(Boolean);
  return clean.length ? clean.join("; ") : "—";
}

function cleanStrings(value: unknown, limit: number): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((v) => String(v).trim()).filter(Boolean).slice(0, limit).map((s) => s.slice(0, 160));
}

async function scoreCards(env: Env, profile: any, cards: any[]) {
  const describeProfile = [
    `Возраст: ${profile.age ?? "не указан"}`,
    `Город: ${profile.city || "не указан"}`,
    `Чем занимается: ${profile.occupation || "—"}`,
    `О себе: ${String(profile.about || "—").slice(0, 800)}`,
    `Навыки: ${joinList(parseList(profile.skills))}`,
    `Проекты: ${joinList(parseList(profile.projects))}`,
    `Достижения: ${joinList(parseList(profile.achievements))}`,
  ].join("\n");

  const describeCards = cards
    .map((c, i) =>
      [
        `[${i + 1}] ${KIND_TITLES[c.kind] ?? c.kind}: ${c.title}`,
        `Событие: ${c.event_name || "—"}`,
        `Кого ищут: ${joinList(parseList(c.roles))}`,
        `Формат: ${FORMAT_TITLES[c.format] ?? c.format}${c.city ? `, ${c.city}` : ""}`,
        `Дедлайн: ${c.deadline ?? "не указан"}`,
        `Описание: ${String(c.description).slice(0, 1200)}`,
      ].join("\n"),
    )
    .join("\n\n");

  const system =
    "Ты — ИИ-модуль совместимости платформы ForceBridge. Оцени, насколько человек с данным профилем подходит " +
    "под каждое объявление как сокомандник или исследователь, по шкале от 0 до 100. " +
    "Учитывай совпадение навыков с тем, кого ищут; опыт, проекты и достижения; интересы и область; " +
    "город и формат (онлайн или очно); возраст — только если он важен для конкурса. " +
    "Шкала: 85–100 — почти идеально, 60–84 — хорошо подходит, 35–59 — частично, ниже 35 — слабо. " +
    "Оценку читает сам владелец профиля, поэтому пиши по-русски и обращайся к нему напрямую на «вы», " +
    "например: «Ваш опыт со SwiftUI закрывает роль iOS-разработчика», «Вам не хватает опыта с биологическими данными». " +
    "Не пиши о нём в третьем лице и не используй слова «участник» и «кандидат». Конкретно и без общих фраз. " +
    'Ответь строго в формате JSON: {"results": [{"index": 1, "score": 0, "summary": "1–2 предложения", ' +
    '"strengths": ["до 3 коротких пунктов"], "gaps": ["до 2 коротких пунктов"]}]} — по одному элементу на каждое объявление.';

  const out = await groqJSON(
    env,
    system,
    `Профиль читателя (обращайся к нему на «вы»):\n${describeProfile}\n\nОбъявления:\n${describeCards}`,
    900 + cards.length * 350,
  );
  const rows: any[] = Array.isArray(out?.results) ? out.results : [];
  return cards.map((_, i) => {
    const row = rows.find((r) => Number(r?.index) === i + 1) ?? rows[i];
    if (!row) throw new Error("AI skipped a card");
    return {
      score: Math.max(0, Math.min(100, Math.round(Number(row.score) || 0))),
      summary: String(row.summary ?? "").trim().slice(0, 400),
      strengths: cleanStrings(row.strengths, 3),
      gaps: cleanStrings(row.gaps, 2),
    };
  });
}

// ---------------------------------------------------------------------------
// Маршрутизация
// ---------------------------------------------------------------------------
type Context = {
  req: Request;
  env: Env;
  ctx: any;
  url: URL;
  params: Record<string, string>;
};

type Route = {
  method: string;
  pattern: RegExp;
  keys: string[];
  handler: (c: Context) => Promise<Response> | Response;
};

const routes: Route[] = [];

function on(method: string, path: string, handler: Route["handler"]): void {
  const keys: string[] = [];
  const source = path.replace(/:(\w+)/g, (_match, key) => {
    keys.push(key);
    return "([^/]+)";
  });
  routes.push({ method, pattern: new RegExp(`^${source}/?$`), keys, handler });
}

// --- Служебное ----------------------------------------------------------
on("GET", "/", ({ env }) => json({ service: "forcebridge-api", ok: true, ai: Boolean(env.GROQ_API_KEY) }));

// --- Вход ---------------------------------------------------------------
on("POST", "/auth/register", async ({ req, env }) => {
  const body = await readJSON(req);
  const email = text(body.email, 120).toLowerCase();
  const password = String(body.password ?? "");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) throw new ApiError(400, "Проверьте адрес почты");
  if (password.length < 6) throw new ApiError(400, "Пароль должен быть не короче 6 символов");
  if (password.length > 72) throw new ApiError(400, "Пароль слишком длинный");
  const existing = await env.DB.prepare("SELECT 1 AS found FROM users WHERE email = ?").bind(email).first();
  if (existing) throw new ApiError(409, "Аккаунт с этой почтой уже есть — войдите");
  const id = crypto.randomUUID();
  try {
    await env.DB.prepare("INSERT INTO users (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)")
      .bind(id, email, await hashPassword(password), nowISO())
      .run();
  } catch (error) {
    if (/UNIQUE/i.test(String(error))) throw new ApiError(409, "Аккаунт с этой почтой уже есть — войдите");
    throw error;
  }
  const token = await createSession(env, id);
  return json({ token, userId: id, email }, 201);
});

on("POST", "/auth/login", async ({ req, env }) => {
  const body = await readJSON(req);
  const email = text(body.email, 120).toLowerCase();
  const password = String(body.password ?? "");
  const user: any = await env.DB.prepare("SELECT id, email, password_hash FROM users WHERE email = ?").bind(email).first();
  if (!user || !(await verifyPassword(password, user.password_hash))) {
    throw new ApiError(401, "Неверная почта или пароль");
  }
  const token = await createSession(env, user.id);
  return json({ token, userId: user.id, email: user.email });
});

on("POST", "/auth/logout", async ({ req, env }) => {
  const token = bearer(req);
  if (token) {
    await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(await sha256Hex(token)).run();
  }
  return empty();
});

on("GET", "/me", async ({ req, env }) => {
  const uid = await requireUser(req, env);
  const user: any = await env.DB.prepare("SELECT id, email FROM users WHERE id = ?").bind(uid).first();
  return json({ userId: user.id, email: user.email, profile: await loadProfile(env, uid) });
});

// --- Профили ------------------------------------------------------------
on("PUT", "/profile", async ({ req, env }) => {
  const uid = await requireUser(req, env);
  const p = normalizeProfile(await readJSON(req));
  const ts = nowISO();
  const previous: any = await env.DB.prepare("SELECT full_name FROM profiles WHERE id = ?").bind(uid).first();
  await env.DB.prepare(
    `INSERT INTO profiles (id, full_name, age, city, occupation, about, skills, projects, achievements, messenger, contact, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (id) DO UPDATE SET
       full_name = excluded.full_name, age = excluded.age, city = excluded.city,
       occupation = excluded.occupation, about = excluded.about, skills = excluded.skills,
       projects = excluded.projects, achievements = excluded.achievements,
       messenger = excluded.messenger, contact = excluded.contact, updated_at = excluded.updated_at`,
  )
    .bind(
      uid, p.fullName, p.age, p.city, p.occupation, p.about,
      JSON.stringify(p.skills), JSON.stringify(p.projects), JSON.stringify(p.achievements),
      p.messenger, p.contact, ts, ts,
    )
    .run();

  // Имя автора входит в поиск по объявлениям — обновляем поисковый текст его карточек.
  if (previous && previous.full_name !== p.fullName) {
    const { results } = await env.DB.prepare(
      "SELECT id, title, description, event_name, roles FROM cards WHERE author_id = ?",
    )
      .bind(uid)
      .all();
    const updates = (results ?? []).map((row: any) =>
      env.DB.prepare("UPDATE cards SET search_text = ? WHERE id = ?").bind(
        searchText(
          { title: row.title, description: row.description, eventName: row.event_name, roles: parseList(row.roles) },
          p.fullName,
        ),
        row.id,
      ),
    );
    if (updates.length) await env.DB.batch(updates.slice(0, 40));
  }
  return json(await loadProfile(env, uid));
});

on("GET", "/profiles/:id", async ({ req, env, params }) => {
  await requireUser(req, env);
  const id = uuidParam(params.id, "Профиль");
  const profile = await loadProfile(env, id);
  if (!profile) throw new ApiError(404, "Профиль не найден");
  return json(profile);
});

on("PUT", "/profile/resume", async ({ req, env }) => {
  const uid = await requireUser(req, env);
  await requireProfile(env, uid);
  const type = (req.headers.get("Content-Type") ?? "").split(";")[0].trim().toLowerCase();
  if (!RESUME_TYPES.includes(type)) throw new ApiError(415, "Подойдут PDF, Word, JPG или PNG");
  let name = "Резюме";
  try {
    name = decodeURIComponent(req.headers.get("X-File-Name") ?? "Резюме").slice(0, 120) || "Резюме";
  } catch {
    name = "Резюме";
  }
  const data = new Uint8Array(await req.arrayBuffer());
  if (data.length === 0) throw new ApiError(400, "Файл пустой");
  if (data.length > MAX_RESUME_BYTES) throw new ApiError(413, "Файл больше 1,8 МБ — сожмите PDF или сохраните фото меньшего размера");
  const ts = nowISO();
  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO resumes (user_id, data, content_type, file_name, updated_at) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT (user_id) DO UPDATE SET
         data = excluded.data, content_type = excluded.content_type,
         file_name = excluded.file_name, updated_at = excluded.updated_at`,
    ).bind(uid, data, type, name, ts),
    env.DB.prepare("UPDATE profiles SET updated_at = ? WHERE id = ?").bind(ts, uid),
  ]);
  return json(await loadProfile(env, uid));
});

on("GET", "/profiles/:id/resume", async ({ req, env, params }) => {
  await requireUser(req, env);
  const id = uuidParam(params.id, "Резюме");
  const row: any = await env.DB.prepare("SELECT data, content_type, file_name FROM resumes WHERE user_id = ?").bind(id).first();
  if (!row) throw new ApiError(404, "Резюме не загружено");
  return new Response(blobBytes(row.data), {
    headers: {
      "Content-Type": row.content_type,
      "Content-Disposition": `attachment; filename*=UTF-8''${encodeURIComponent(row.file_name)}`,
    },
  });
});

// --- Категории ----------------------------------------------------------
on("GET", "/categories", async ({ env }) => {
  const { results } = await env.DB.prepare("SELECT key, title, grp, sort FROM categories ORDER BY sort").all();
  return json(results ?? []);
});

on("GET", "/categories/counts", async ({ env }) => {
  const { results } = await env.DB.prepare(
    `SELECT k.key AS key, COUNT(cc.card_id) AS total
     FROM categories k LEFT JOIN card_categories cc ON cc.category = k.key
     GROUP BY k.key`,
  ).all();
  return json((results ?? []).map((r: any) => ({ key: r.key, total: Number(r.total) || 0 })));
});

// --- Объявления ---------------------------------------------------------
on("POST", "/cards/search", async ({ req, env }) => {
  const uid = await requireUser(req, env);
  const body = await readJSON(req);
  const formats = textList(body.formats, 20, 30).filter((k) => FORMAT_KEYS.has(k));
  const fields = textList(body.fields, 20, 30).filter((k) => CATEGORY_KEYS.has(k) && !FORMAT_KEYS.has(k));
  const query = text(body.query, 100).toLowerCase();
  const kind = KINDS.includes(String(body.kind)) ? String(body.kind) : "";
  const sort = ["new", "old", "deadline"].includes(String(body.sort)) ? String(body.sort) : "new";

  const where: string[] = [];
  const params: unknown[] = [uid];
  if (formats.length) {
    where.push(
      `EXISTS (SELECT 1 FROM card_categories cc WHERE cc.card_id = c.id AND cc.category IN (${formats.map(() => "?").join(", ")}))`,
    );
    params.push(...formats);
  }
  if (fields.length) {
    where.push(
      `EXISTS (SELECT 1 FROM card_categories cc WHERE cc.card_id = c.id AND cc.category IN (${fields.map(() => "?").join(", ")}))`,
    );
    params.push(...fields);
  }
  if (kind) {
    where.push("c.kind = ?");
    params.push(kind);
  }
  if (query) {
    where.push("c.search_text LIKE ? ESCAPE '\\'");
    params.push("%" + query.replace(/[\\%_]/g, (m) => "\\" + m) + "%");
  }
  const order =
    sort === "old"
      ? "c.created_at ASC"
      : sort === "deadline"
        ? "c.deadline IS NULL, c.deadline ASC, c.created_at DESC"
        : "c.created_at DESC";
  const statement =
    `SELECT ${CARD_COLUMNS} FROM cards c JOIN profiles p ON p.id = c.author_id ` +
    (where.length ? `WHERE ${where.join(" AND ")} ` : "") +
    `ORDER BY ${order} LIMIT 300`;
  const { results } = await env.DB.prepare(statement).bind(...params).all();
  return json((results ?? []).map(cardJSON));
});

on("GET", "/my/cards", async ({ req, env }) => {
  const uid = await requireUser(req, env);
  const { results } = await env.DB.prepare(
    `SELECT ${CARD_COLUMNS} FROM cards c JOIN profiles p ON p.id = c.author_id
     WHERE c.author_id = ? ORDER BY c.created_at DESC`,
  )
    .bind(uid, uid)
    .all();
  return json((results ?? []).map(cardJSON));
});

on("GET", "/cards/:id", async ({ req, env, params }) => {
  const uid = await requireUser(req, env);
  const id = uuidParam(params.id, "Объявление");
  const card = await loadCard(env, id, uid);
  if (!card) throw new ApiError(404, "Объявление удалено автором");
  return json(card);
});

on("POST", "/cards", async ({ req, env, ctx }) => {
  const uid = await requireUser(req, env);
  const profile = await requireProfile(env, uid);
  const d = normalizeCard(await readJSON(req));
  const id = crypto.randomUUID();
  const ts = nowISO();
  await env.DB.prepare(
    `INSERT INTO cards (id, author_id, kind, title, description, event_name, roles, city, format, deadline,
                        ai_status, content_version, search_text, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 1, ?, ?, ?)`,
  )
    .bind(
      id, uid, d.kind, d.title, d.description, d.eventName, JSON.stringify(d.roles), d.city, d.format, d.deadline,
      searchText(d, profile.full_name), ts, ts,
    )
    .run();
  ctx.waitUntil(classifyCard(env, id));
  return json(await loadCard(env, id, uid), 201);
});

on("PATCH", "/cards/:id", async ({ req, env, ctx, params }) => {
  const uid = await requireUser(req, env);
  const id = uuidParam(params.id, "Объявление");
  const existing: any = await env.DB.prepare(
    "SELECT author_id, kind, title, description, event_name, roles, city, format, deadline FROM cards WHERE id = ?",
  )
    .bind(id)
    .first();
  if (!existing) throw new ApiError(404, "Объявление удалено");
  if (existing.author_id !== uid) throw new ApiError(403, "Можно менять только свои объявления");
  const profile = await requireProfile(env, uid);
  const d = normalizeCard(await readJSON(req));
  const contentChanged =
    existing.kind !== d.kind ||
    existing.title !== d.title ||
    existing.description !== d.description ||
    existing.event_name !== d.eventName ||
    JSON.stringify(parseList(existing.roles)) !== JSON.stringify(d.roles);
  const detailsChanged =
    existing.city !== d.city || existing.format !== d.format || (existing.deadline ?? null) !== d.deadline;
  const ts = nowISO();
  const statements = [
    env.DB.prepare(
      `UPDATE cards SET
         kind = ?, title = ?, description = ?, event_name = ?, roles = ?, city = ?, format = ?, deadline = ?,
         search_text = ?,
         ai_status = CASE WHEN ? = 1 THEN 'pending' ELSE ai_status END,
         content_version = content_version + ?,
         updated_at = CASE WHEN ? = 1 THEN ? ELSE updated_at END
       WHERE id = ?`,
    ).bind(
      d.kind, d.title, d.description, d.eventName, JSON.stringify(d.roles), d.city, d.format, d.deadline,
      searchText(d, profile.full_name),
      contentChanged ? 1 : 0,
      contentChanged ? 1 : 0,
      contentChanged || detailsChanged ? 1 : 0,
      ts,
      id,
    ),
  ];
  if (contentChanged) {
    statements.push(env.DB.prepare("DELETE FROM card_categories WHERE card_id = ?").bind(id));
  }
  await env.DB.batch(statements);
  if (contentChanged) ctx.waitUntil(classifyCard(env, id));
  return json(await loadCard(env, id, uid));
});

on("DELETE", "/cards/:id", async ({ req, env, params }) => {
  const uid = await requireUser(req, env);
  const id = uuidParam(params.id, "Объявление");
  const row: any = await env.DB.prepare("SELECT author_id FROM cards WHERE id = ?").bind(id).first();
  if (!row) return empty();
  if (row.author_id !== uid) throw new ApiError(403, "Можно удалять только свои объявления");
  await env.DB.batch([
    env.DB.prepare("DELETE FROM card_categories WHERE card_id = ?").bind(id),
    env.DB.prepare("DELETE FROM compatibility WHERE card_id = ?").bind(id),
    env.DB.prepare("DELETE FROM responses WHERE card_id = ?").bind(id),
    env.DB.prepare("DELETE FROM cards WHERE id = ?").bind(id),
  ]);
  return empty();
});

// --- Отклики ------------------------------------------------------------
on("POST", "/cards/:id/responses", async ({ req, env, params }) => {
  const uid = await requireUser(req, env);
  await requireProfile(env, uid);
  const id = uuidParam(params.id, "Объявление");
  const body = await readJSON(req);
  const card: any = await env.DB.prepare("SELECT author_id FROM cards WHERE id = ?").bind(id).first();
  if (!card) throw new ApiError(404, "Объявление удалено автором");
  if (card.author_id === uid) throw new ApiError(400, "Нельзя откликнуться на своё объявление");
  await env.DB.prepare(
    "INSERT OR IGNORE INTO responses (id, card_id, user_id, message, hidden, created_at) VALUES (?, ?, ?, ?, 0, ?)",
  )
    .bind(crypto.randomUUID(), id, uid, text(body.message, 500), nowISO())
    .run();
  return empty(201);
});

on("DELETE", "/cards/:id/responses", async ({ req, env, params }) => {
  const uid = await requireUser(req, env);
  const id = uuidParam(params.id, "Объявление");
  await env.DB.prepare("DELETE FROM responses WHERE card_id = ? AND user_id = ?").bind(id, uid).run();
  return empty();
});

on("GET", "/cards/:id/responses", async ({ req, env, params }) => {
  const uid = await requireUser(req, env);
  const id = uuidParam(params.id, "Объявление");
  const card: any = await env.DB.prepare("SELECT author_id FROM cards WHERE id = ?").bind(id).first();
  if (!card) throw new ApiError(404, "Объявление удалено");
  if (card.author_id !== uid) throw new ApiError(403, "Отклики видит только автор объявления");
  const { results } = await env.DB.prepare(
    `SELECT x.id AS response_id, x.card_id AS response_card_id, x.user_id AS response_user_id,
            x.message AS response_message, x.hidden AS response_hidden, x.created_at AS response_created_at,
            ${PROFILE_COLUMNS}
     FROM responses x
     JOIN profiles p ON p.id = x.user_id
     LEFT JOIN resumes r ON r.user_id = p.id
     WHERE x.card_id = ? AND x.hidden = 0
     ORDER BY x.created_at DESC`,
  )
    .bind(id)
    .all();
  return json((results ?? []).map((row: any) => ({ ...responseJSON(row), profile: profileJSON(row) })));
});

on("POST", "/responses/:id/hide", async ({ req, env, params }) => {
  const uid = await requireUser(req, env);
  const id = uuidParam(params.id, "Отклик");
  const row: any = await env.DB.prepare(
    "SELECT c.author_id FROM responses x JOIN cards c ON c.id = x.card_id WHERE x.id = ?",
  )
    .bind(id)
    .first();
  if (!row) return empty();
  if (row.author_id !== uid) throw new ApiError(403, "Убирать отклики может только автор объявления");
  await env.DB.prepare("UPDATE responses SET hidden = 1 WHERE id = ?").bind(id).run();
  return empty();
});

on("GET", "/my/responses", async ({ req, env }) => {
  const uid = await requireUser(req, env);
  const { results } = await env.DB.prepare(
    `SELECT x.id AS response_id, x.card_id AS response_card_id, x.user_id AS response_user_id,
            x.message AS response_message, x.hidden AS response_hidden, x.created_at AS response_created_at,
            ${CARD_COLUMNS}
     FROM responses x
     JOIN cards c ON c.id = x.card_id
     JOIN profiles p ON p.id = c.author_id
     WHERE x.user_id = ?
     ORDER BY x.created_at DESC`,
  )
    .bind(uid, uid)
    .all();
  return json((results ?? []).map((row: any) => ({ ...responseJSON(row), card: cardJSON(row) })));
});

// --- Избранное ----------------------------------------------------------
on("GET", "/favorites", async ({ req, env }) => {
  const uid = await requireUser(req, env);
  const { results } = await env.DB.prepare(
    `SELECT ${PROFILE_COLUMNS}
     FROM favorites f
     JOIN profiles p ON p.id = f.profile_id
     LEFT JOIN resumes r ON r.user_id = p.id
     WHERE f.owner_id = ?
     ORDER BY f.created_at DESC`,
  )
    .bind(uid)
    .all();
  return json((results ?? []).map(profileJSON));
});

on("PUT", "/favorites/:id", async ({ req, env, params }) => {
  const uid = await requireUser(req, env);
  const id = uuidParam(params.id, "Профиль");
  if (id === uid) throw new ApiError(400, "Себя добавить в избранное нельзя");
  const exists = await env.DB.prepare("SELECT 1 AS found FROM profiles WHERE id = ?").bind(id).first();
  if (!exists) throw new ApiError(404, "Профиль не найден");
  await env.DB.prepare("INSERT OR IGNORE INTO favorites (owner_id, profile_id, created_at) VALUES (?, ?, ?)")
    .bind(uid, id, nowISO())
    .run();
  return empty();
});

on("DELETE", "/favorites/:id", async ({ req, env, params }) => {
  const uid = await requireUser(req, env);
  const id = uuidParam(params.id, "Профиль");
  await env.DB.prepare("DELETE FROM favorites WHERE owner_id = ? AND profile_id = ?").bind(uid, id).run();
  return empty();
});

// --- ИИ -----------------------------------------------------------------
on("POST", "/ai/classify-pending", async ({ req, env }) => {
  await requireUser(req, env);
  const processed = await classifyPending(env, 3);
  return json({ processed });
});

on("POST", "/ai/compatibility", async ({ req, env }) => {
  const uid = await requireUser(req, env);
  const body = await readJSON(req);
  const ids = textList(body.cardIds, 8, 40).filter((id) => UUID_RE.test(id)).map((id) => id.toLowerCase());
  const force = body.force === true;
  if (ids.length === 0) return json({ results: {} });

  const profile: any = await env.DB.prepare("SELECT * FROM profiles WHERE id = ?").bind(uid).first();
  if (!profile) throw new ApiError(400, "Сначала заполните паспорт участника");

  const marks = ids.map(() => "?").join(", ");
  const cardsResult = await env.DB.prepare(
    `SELECT id, author_id, kind, title, description, event_name, roles, city, format, deadline, updated_at
     FROM cards WHERE id IN (${marks})`,
  )
    .bind(...ids)
    .all();
  const cachedResult = await env.DB.prepare(
    `SELECT * FROM compatibility WHERE user_id = ? AND card_id IN (${marks})`,
  )
    .bind(uid, ...ids)
    .all();
  const cards: any[] = cardsResult.results ?? [];
  const cached: any[] = cachedResult.results ?? [];

  const results: Record<string, unknown> = {};
  const todo: any[] = [];
  for (const card of cards) {
    if (card.author_id === uid) continue;
    const hit = cached.find((row) => row.card_id === card.id);
    const fresh = hit && hit.card_version === card.updated_at && hit.profile_version === profile.updated_at;
    if (hit && fresh && !force) {
      results[card.id] = {
        score: hit.score,
        summary: hit.summary,
        strengths: parseList(hit.strengths),
        gaps: parseList(hit.gaps),
      };
    } else {
      todo.push(card);
    }
  }

  if (todo.length > 0) {
    let scores: any[];
    try {
      scores = await scoreCards(env, profile, todo);
    } catch (error) {
      console.error("compatibility failed", String(error));
      return json({ results, error: aiErrorMessage(error) }, Object.keys(results).length > 0 ? 200 : 502);
    }
    const ts = nowISO();
    const statements = todo.map((card, i) => {
      results[card.id] = scores[i];
      return env.DB.prepare(
        `INSERT INTO compatibility (card_id, user_id, score, summary, strengths, gaps, card_version, profile_version, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT (card_id, user_id) DO UPDATE SET
           score = excluded.score, summary = excluded.summary, strengths = excluded.strengths,
           gaps = excluded.gaps, card_version = excluded.card_version,
           profile_version = excluded.profile_version, created_at = excluded.created_at`,
      ).bind(
        card.id, uid, scores[i].score, scores[i].summary,
        JSON.stringify(scores[i].strengths), JSON.stringify(scores[i].gaps),
        card.updated_at, profile.updated_at, ts,
      );
    });
    await env.DB.batch(statements);
  }

  return json({ results });
});

// ---------------------------------------------------------------------------
// Точка входа
// ---------------------------------------------------------------------------
export default {
  async fetch(req: Request, env: Env, ctx: any): Promise<Response> {
    try {
      await ensureSchema(env);
      const url = new URL(req.url);
      for (const route of routes) {
        if (route.method !== req.method) continue;
        const match = url.pathname.match(route.pattern);
        if (!match) continue;
        const params: Record<string, string> = {};
        route.keys.forEach((key, index) => {
          params[key] = decodeURIComponent(match[index + 1]);
        });
        return await route.handler({ req, env, ctx, url, params });
      }
      return json({ error: "Не найдено" }, 404);
    } catch (error) {
      if (error instanceof ApiError) return json({ error: error.message }, error.status);
      console.error("unhandled", String(error));
      return json({ error: "Внутренняя ошибка сервера" }, 500);
    }
  },

  // Раз в 10 минут ИИ доразбирает карточки, которые не успел классифицировать.
  async scheduled(_event: unknown, env: Env, ctx: any): Promise<void> {
    ctx.waitUntil(
      (async () => {
        await ensureSchema(env);
        await classifyPending(env, 3);
      })(),
    );
  },
};
