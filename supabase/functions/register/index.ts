// Регистрация по почте и паролю без письма-подтверждения.
// Пользователь создаётся сразу подтверждённым, после чего приложение входит обычным способом.
import { createClient } from "npm:@supabase/supabase-js@2";

const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return json({ error: "Метод не поддерживается" }, 405);

  let payload: { email?: unknown; password?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Некорректный запрос" }, 400);
  }

  const email = String(payload.email ?? "").trim().toLowerCase();
  const password = String(payload.password ?? "");

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return json({ error: "Проверьте адрес почты" }, 400);
  }
  if (password.length < 6) {
    return json({ error: "Пароль должен быть не короче 6 символов" }, 400);
  }
  if (password.length > 72) {
    return json({ error: "Пароль слишком длинный" }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (error) {
    const exists = /already|registered|exists/i.test(error.message);
    return json(
      { error: exists ? "Аккаунт с этой почтой уже есть — войдите" : `Не удалось создать аккаунт: ${error.message}` },
      exists ? 409 : 400,
    );
  }

  return json({ id: data.user?.id ?? null });
});
