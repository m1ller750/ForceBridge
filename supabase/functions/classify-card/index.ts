// ИИ-классификатор карточек. Вызывается триггером базы данных после создания
// или изменения карточки ({ card_id, version }) и приложением для «зависших»
// карточек ({ pending: true }). Пишет категории прямо в таблицу cards.
import { createClient } from "npm:@supabase/supabase-js@2";

const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

type Card = {
  id: string;
  kind: string;
  title: string;
  description: string;
  event_name: string;
  roles: string[] | null;
  content_version: number;
  ai_status?: string;
};

type Category = { key: string; title: string; grp: string };

const KIND_TITLES: Record<string, string> = {
  teammate: "Ищу сокомандника",
  research: "Нужен человек для исследования",
  join: "Ищу команду",
};

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
    temperature: 0.2,
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
// Классификация
// ---------------------------------------------------------------------------
async function classify(card: Card, categories: Category[]): Promise<string[]> {
  const valid = new Set(categories.map((c) => c.key));
  const list = categories
    .map((c) => `- ${c.key}: ${c.title} (${c.grp === "format" ? "формат" : "область"})`)
    .join("\n");

  const system =
    "Ты — классификатор объявлений платформы ForceBridge, где люди ищут сокомандников " +
    "для хакатонов, олимпиад, конкурсов, стартапов и научных исследований. " +
    "Отнеси объявление ко ВСЕМ подходящим категориям из списка — обычно от 2 до 5. " +
    "Старайся выбрать хотя бы одну категорию формата и хотя бы одну категорию области. " +
    "Используй только ключи из списка. " +
    'Ответь строго в формате JSON: {"categories": ["key1", "key2"]}.';

  const user =
    `Категории:\n${list}\n\n` +
    `Объявление:\n` +
    `Тип: ${KIND_TITLES[card.kind] ?? card.kind}\n` +
    `Заголовок: ${card.title}\n` +
    `Событие: ${card.event_name || "—"}\n` +
    `Кого ищут: ${(card.roles ?? []).join(", ") || "—"}\n` +
    `Описание: ${card.description.slice(0, 2000)}`;

  const out = await groqJSON(system, user, 1200);
  const raw: unknown[] = Array.isArray(out?.categories) ? out.categories : [];
  const keys = [...new Set(raw.map((k) => String(k).trim().toLowerCase()).filter((k) => valid.has(k)))];
  if (keys.length === 0 && card.kind === "research" && valid.has("research")) keys.push("research");
  return keys.slice(0, 6);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });

  const payload = await req.json().catch(() => ({}));
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const { data: categories, error: categoriesError } = await admin
    .from("categories")
    .select("key,title,grp")
    .order("sort");
  if (categoriesError || !categories?.length) {
    return json({ error: "categories unavailable" }, 500);
  }

  const columns = "id,kind,title,description,event_name,roles,content_version,ai_status";
  let cards: Card[] = [];

  if (typeof payload.card_id === "string") {
    const { data } = await admin.from("cards").select(columns).eq("id", payload.card_id).maybeSingle();
    if (!data) return json({ skipped: "not_found" });
    if (typeof payload.version === "number" && data.content_version !== payload.version) {
      return json({ skipped: "stale" });
    }
    if (data.ai_status === "done" && payload.force !== true) return json({ skipped: "done" });
    cards = [data as Card];
  } else if (payload.pending === true) {
    const cutoff = new Date(Date.now() - 15_000).toISOString();
    const { data } = await admin
      .from("cards")
      .select(columns)
      .neq("ai_status", "done")
      .lt("updated_at", cutoff)
      .order("updated_at")
      .limit(10);
    cards = (data ?? []) as Card[];
  } else {
    return json({ error: "card_id or pending is required" }, 400);
  }

  const results: unknown[] = [];
  for (const card of cards) {
    try {
      const keys = await classify(card, categories as Category[]);
      await admin
        .from("cards")
        .update({ categories: keys, ai_status: "done" })
        .eq("id", card.id)
        .eq("content_version", card.content_version);
      results.push({ id: card.id, categories: keys });
    } catch (error) {
      await admin
        .from("cards")
        .update({ ai_status: "error" })
        .eq("id", card.id)
        .eq("content_version", card.content_version);
      results.push({ id: card.id, error: String(error) });
    }
  }

  return json({ results });
});
