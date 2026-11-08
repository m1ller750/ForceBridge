// ИИ-совместимость: насколько профиль просматривающего подходит под карточки.
// POST { card_ids: string[], force?: boolean } с токеном пользователя.
// Результат кэшируется в таблице compatibility и пересчитывается,
// когда меняется карточка или профиль.
import { createClient } from "npm:@supabase/supabase-js@2";

const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

type Profile = {
  id: string;
  full_name: string;
  age: number | null;
  city: string;
  occupation: string;
  about: string;
  skills: string[] | null;
  projects: string[] | null;
  achievements: string[] | null;
  updated_at: string;
};

type Card = {
  id: string;
  author_id: string;
  kind: string;
  title: string;
  description: string;
  event_name: string;
  roles: string[] | null;
  city: string;
  format: string;
  deadline: string | null;
  updated_at: string;
};

type Score = { score: number; summary: string; strengths: string[]; gaps: string[] };

const KIND_TITLES: Record<string, string> = {
  teammate: "Ищу сокомандника",
  research: "Нужен человек для исследования",
  join: "Ищу команду",
};
const FORMAT_TITLES: Record<string, string> = { online: "онлайн", offline: "очно", any: "любой" };

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

function configuredModels(): string[] {
  const custom = (Deno.env.get("GROQ_MODEL") ?? "")
    .split(",")
    .map((m) => m.trim())
    .filter(Boolean);
  return [...new Set([...custom, ...PREFERRED_MODELS])];
}

async function discoverModels(key: string): Promise<string[]> {
  if (discoveredModels) return discoveredModels;
  try {
    const res = await fetch(GROQ_MODELS, { headers: { Authorization: `Bearer ${key}` } });
    if (!res.ok) return [];
    const data = await res.json();
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
    temperature: 0.3,
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

function extractJSON(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start >= 0 && end > start) return JSON.parse(text.slice(start, end + 1));
    throw new Error("AI returned a non-JSON answer");
  }
}

async function groqJSON(system: string, user: string, maxTokens: number): Promise<any> {
  const key = Deno.env.get("GROQ_API_KEY");
  if (!key) throw new Error("GROQ_API_KEY is not configured");

  const tried = new Set<string>();
  let lastError = "no models available";
  let queue = configuredModels();

  for (let pass = 0; pass < 2; pass++) {
    for (const model of queue) {
      if (tried.has(model)) continue;
      tried.add(model);

      let res = await callModel(key, model, system, user, maxTokens, true);
      if (res.status === 400) {
        const text = await res.text();
        if (/response_format|json_object|json mode/i.test(text)) {
          res = await callModel(key, model, system, user, maxTokens, false);
        } else {
          lastError = `${model}: 400 ${text.slice(0, 300)}`;
          continue;
        }
      }
      if (res.ok) {
        const data = await res.json();
        const content: string = data?.choices?.[0]?.message?.content ?? "";
        return extractJSON(content);
      }
      const text = await res.text();
      lastError = `${model}: ${res.status} ${text.slice(0, 300)}`;
      if (res.status === 401 || res.status === 403) throw new Error("Groq rejected the API key");
    }
    if (pass === 0) {
      queue = (await discoverModels(key)).filter((m) => !tried.has(m));
      if (queue.length === 0) break;
    }
  }
  throw new Error(lastError);
}

// ---------------------------------------------------------------------------
// Оценка
// ---------------------------------------------------------------------------
function list(items: string[] | null | undefined): string {
  const clean = (items ?? []).map((s) => s.trim()).filter(Boolean);
  return clean.length ? clean.join("; ") : "—";
}

function describeProfile(p: Profile): string {
  return [
    `Возраст: ${p.age ?? "не указан"}`,
    `Город: ${p.city || "не указан"}`,
    `Чем занимается: ${p.occupation || "—"}`,
    `О себе: ${(p.about || "—").slice(0, 800)}`,
    `Навыки: ${list(p.skills)}`,
    `Проекты: ${list(p.projects)}`,
    `Достижения: ${list(p.achievements)}`,
  ].join("\n");
}

function describeCard(c: Card, index: number): string {
  return [
    `[${index}] ${KIND_TITLES[c.kind] ?? c.kind}: ${c.title}`,
    `Событие: ${c.event_name || "—"}`,
    `Кого ищут: ${list(c.roles)}`,
    `Формат: ${FORMAT_TITLES[c.format] ?? c.format}${c.city ? `, ${c.city}` : ""}`,
    `Дедлайн: ${c.deadline ?? "не указан"}`,
    `Описание: ${c.description.slice(0, 1200)}`,
  ].join("\n");
}

function cleanStrings(value: unknown, limit: number): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((v) => String(v).trim()).filter(Boolean).slice(0, limit).map((s) => s.slice(0, 160));
}

async function scoreCards(profile: Profile, cards: Card[]): Promise<Score[]> {
  const system =
    "Ты — ИИ-модуль совместимости платформы ForceBridge. Оцени, насколько участник подходит " +
    "под каждое объявление как сокомандник или исследователь, по шкале от 0 до 100. " +
    "Учитывай совпадение навыков с тем, кого ищут; опыт, проекты и достижения; интересы и область; " +
    "город и формат (онлайн или очно); возраст — только если он важен для конкурса. " +
    "Шкала: 85–100 — почти идеально, 60–84 — хорошо подходит, 35–59 — частично, ниже 35 — слабо. " +
    "Пиши по-русски, обращайся к участнику на «вы», без воды и общих фраз. " +
    'Ответь строго в формате JSON: {"results": [{"index": 1, "score": 0, "summary": "1–2 предложения", ' +
    '"strengths": ["до 3 коротких пунктов"], "gaps": ["до 2 коротких пунктов"]}]} — по одному элементу на каждое объявление.';

  const user =
    `Профиль участника:\n${describeProfile(profile)}\n\n` +
    `Объявления:\n${cards.map((c, i) => describeCard(c, i + 1)).join("\n\n")}`;

  const out = await groqJSON(system, user, 900 + cards.length * 350);
  const rows: any[] = Array.isArray(out?.results) ? out.results : [];

  return cards.map((_, i) => {
    const row = rows.find((r) => Number(r?.index) === i + 1) ?? rows[i];
    if (!row) throw new Error("AI skipped a card");
    const score = Math.max(0, Math.min(100, Math.round(Number(row.score) || 0)));
    return {
      score,
      summary: String(row.summary ?? "").trim().slice(0, 400),
      strengths: cleanStrings(row.strengths, 3),
      gaps: cleanStrings(row.gaps, 2),
    };
  });
}

function sameMoment(a: string, b: string): boolean {
  return Date.parse(a) === Date.parse(b);
}

function aiErrorMessage(error: unknown): string {
  const text = String(error);
  if (text.includes("GROQ_API_KEY")) return "ИИ ещё не подключён: добавьте секрет GROQ_API_KEY в Supabase.";
  if (text.includes("rejected the API key")) return "Groq не принял ключ API — проверьте GROQ_API_KEY.";
  if (text.includes("429")) return "ИИ перегружен запросами. Попробуйте через минуту.";
  return "ИИ не смог оценить совместимость. Попробуйте ещё раз.";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return json({ error: "Метод не поддерживается" }, 405);

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Войдите в аккаунт" }, 401);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const { data: auth, error: authError } = await admin.auth.getUser(token);
  if (authError || !auth?.user) return json({ error: "Сессия истекла — войдите снова" }, 401);
  const uid = auth.user.id;

  const payload = await req.json().catch(() => ({}));
  const ids: string[] = (Array.isArray(payload.card_ids) ? payload.card_ids : [])
    .filter((x: unknown) => typeof x === "string")
    .slice(0, 8);
  const force = payload.force === true;
  if (ids.length === 0) return json({ results: {} });

  const { data: profile } = await admin.from("profiles").select("*").eq("id", uid).maybeSingle();
  if (!profile) return json({ error: "Сначала заполните профиль" }, 400);

  const { data: cards } = await admin
    .from("cards")
    .select("id,author_id,kind,title,description,event_name,roles,city,format,deadline,updated_at")
    .in("id", ids);

  const { data: cached } = await admin
    .from("compatibility")
    .select("*")
    .eq("user_id", uid)
    .in("card_id", ids);

  const results: Record<string, Score> = {};
  const todo: Card[] = [];

  for (const card of (cards ?? []) as Card[]) {
    if (card.author_id === uid) continue;
    const hit = (cached ?? []).find((c: any) => c.card_id === card.id);
    const fresh = hit &&
      sameMoment(hit.card_version, card.updated_at) &&
      sameMoment(hit.profile_version, (profile as Profile).updated_at);
    if (hit && fresh && !force) {
      results[card.id] = { score: hit.score, summary: hit.summary, strengths: hit.strengths ?? [], gaps: hit.gaps ?? [] };
    } else {
      todo.push(card);
    }
  }

  if (todo.length > 0) {
    let scores: Score[];
    try {
      scores = await scoreCards(profile as Profile, todo);
    } catch (error) {
      console.error("compatibility failed", String(error));
      return json({ results, error: aiErrorMessage(error) }, Object.keys(results).length > 0 ? 200 : 502);
    }

    const rows = todo.map((card, i) => ({
      card_id: card.id,
      user_id: uid,
      score: scores[i].score,
      summary: scores[i].summary,
      strengths: scores[i].strengths,
      gaps: scores[i].gaps,
      card_version: card.updated_at,
      profile_version: (profile as Profile).updated_at,
      created_at: new Date().toISOString(),
    }));

    const { error: saveError } = await admin.from("compatibility").upsert(rows, { onConflict: "card_id,user_id" });
    if (saveError) console.error("cache save failed", saveError.message);

    todo.forEach((card, i) => {
      results[card.id] = scores[i];
    });
  }

  return json({ results });
});
