import { handle } from "hono/vercel";
import app from "../src/index.js";

export const runtime = "nodejs";
// Default function timeout (10s on Hobby) can be shorter than an OpenAI
// extraction call + Supabase write on a slow connection, which surfaces to
// the app as a generic "no se pudo enviar" failure with no server error to
// show. Give it real headroom.
export const maxDuration = 30;

export const GET = handle(app);
export const POST = handle(app);
export const PATCH = handle(app);
export const DELETE = handle(app);
export const OPTIONS = handle(app);
