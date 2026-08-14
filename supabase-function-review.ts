// ============================================================================
// Review Suite — proxy Edge Function
// ----------------------------------------------------------------------------
// Deploy once to Supabase:
//   Supabase ▸ Edge Functions ▸ Deploy a new function ▸ name it exactly "review"
//   ▸ paste this file ▸ Deploy. In the function's settings turn OFF "Verify JWT"
//   so reviewers can open a review link without logging in.
//
// What it does: fetches any URL you pass as ?url=... , injects the comment
// overlay, and serves it back as a normal web page (same-origin, so no CSP
// iframe block). The generator page builds those links for you.
//
// Config comes from environment variables (Supabase ▸ Edge Functions ▸ your
// function ▸ Secrets), with sensible fallbacks:
//   SUPABASE_URL       - auto-provided by Supabase (your project URL)
//   SUPABASE_ANON_KEY  - auto-provided by Supabase (anon/public key)
//   OVERLAY_URL        - REQUIRED: public URL of review-overlay.js
//                        e.g. https://YOUR-GH-USER.github.io/YOUR-REPO/review-overlay.js
//   ALLOW_HOSTS        - OPTIONAL: comma-separated host suffixes to allow,
//                        e.g. "example.com,webflow.io". Empty = allow any site.
// ============================================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "https://YOUR-PROJECT.supabase.co";
const ANON_KEY     = Deno.env.get("SUPABASE_ANON_KEY") ?? "YOUR-SUPABASE-ANON-KEY";
const OVERLAY      = Deno.env.get("OVERLAY_URL") ?? "https://YOUR-GH-USER.github.io/YOUR-REPO/review-overlay.js";
const ALLOW_HOSTS  = (Deno.env.get("ALLOW_HOSTS") ?? "").split(",").map((h) => h.trim()).filter(Boolean);

function esc(s: string) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }

Deno.serve(async (req) => {
  const reqUrl = new URL(req.url);
  const CORS = {
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "content-type",
    "access-control-allow-methods": "GET, OPTIONS",
  };
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });

  const target = reqUrl.searchParams.get("url");
  if (!target) {
    return new Response("Add ?url=https://site-to-review", { status: 400, headers: { "content-type": "text/plain" } });
  }
  let t: URL;
  try { t = new URL(target); } catch { return new Response("Invalid url", { status: 400 }); }
  if (t.protocol !== "http:" && t.protocol !== "https:") {
    return new Response("Only http/https allowed", { status: 400 });
  }
  if (ALLOW_HOSTS.length && !ALLOW_HOSTS.some((h) => t.hostname.endsWith(h))) {
    return new Response("This host is not allowed for review", { status: 403 });
  }

  let res: Response;
  try {
    res = await fetch(t.href, { headers: { "User-Agent": "Mozilla/5.0 (ReviewProxy)" } });
  } catch (e) {
    return new Response("Could not fetch that site: " + e, { status: 502 });
  }

  const ctype = res.headers.get("content-type") || "";
  // Non-HTML (images, css, js fetched directly): stream through untouched.
  if (!ctype.includes("text/html")) {
    const buf = await res.arrayBuffer();
    return new Response(buf, { headers: { "content-type": ctype || "application/octet-stream", "access-control-allow-origin": "*" } });
  }

  let html = await res.text();
  const origin = t.origin + "/";
  // Public URL of THIS function — used for in-wrapper navigation links.
  // (Don't derive from reqUrl: inside Supabase the path is /review over http, which breaks externally.)
  const PROXY_BASE = SUPABASE_URL + "/functions/v1/review";

  // 1) strip any page-level CSP that could block our injected script
  html = html.replace(/<meta[^>]+http-equiv=["']?content-security-policy["']?[^>]*>/gi, "");
  // 2) rewrite the target's own links FIRST — before injecting <base>, so we don't clobber the base tag
  const link = (p: string) => `${PROXY_BASE}?url=${encodeURIComponent(t.origin + "/" + p.replace(/^\//, ""))}`;
  html = html.replace(/href="\/([^"]*)"/g, (_m, p) => `href="${link(p)}"`);       // root-relative
  html = html.replace(new RegExp(`href="${esc(t.origin)}/([^"]*)"`, "g"), (_m, p) => `href="${link(p)}"`); // same-origin absolute
  // 3) NOW inject <base> so the target's own CSS/JS/images keep loading from the real site
  html = html.replace(/<head([^>]*)>/i, `<head$1><base href="${origin}">`);
  // 4) inject the comment overlay (auto-scoped to the target's domain)
  const cfg = JSON.stringify({ url: SUPABASE_URL, key: ANON_KEY, project: t.hostname, page: t.pathname });
  const inject = `<script>window.IDR_CONFIG=${cfg};</script><script src="${OVERLAY}?v=${Date.now()}"></script>`;
  html = html.replace(/<\/body>/i, inject + "</body>");

  return new Response(html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "access-control-allow-origin": "*",
    },
  });
});
