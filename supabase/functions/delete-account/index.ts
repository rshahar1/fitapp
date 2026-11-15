// delete-account: permanently deletes the calling user's Supabase account.
// Feature 013 (cloud backup). POST only, caller JWT required. Every synced table
// references auth.users with ON DELETE CASCADE, so all backed-up data goes with it.
// Responses: 204 success, 401 no valid user, 405 wrong method, 500 JSON error.
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY come from the
// Supabase runtime; nothing is hard-coded.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json(405, { error: "method not allowed" });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const authorization = req.headers.get("Authorization") ?? "";

    const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authorization } },
    });
    const { data, error } = await asUser.auth.getUser();
    if (error || !data.user) return json(401, { error: "unauthorized" });

    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { error: delError } = await admin.auth.admin.deleteUser(data.user.id);
    if (delError) return json(500, { error: delError.message });

    return new Response(null, { status: 204, headers: cors });
  } catch (e) {
    return json(500, { error: e instanceof Error ? e.message : "internal error" });
  }
});
