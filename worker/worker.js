/**
 * Somfy Protect — passerelle pour la montre (Cloudflare Worker)
 *
 * Points d'accès (tous protégés par l'en-tête  Authorization: Bearer <API_KEY>) :
 *   GET  /status   -> état actuel de l'alarme
 *   POST /arm      -> armement total
 *   POST /partial  -> armement partiel
 *   POST /disarm   -> désarmement
 *
 * Réponse JSON : { "site": "Maison", "status": "armed|partial|disarmed",
 *                  "confirmed": true|false }   ou   { "error": "..." }
 *
 * Secrets à définir dans Cloudflare (Settings > Variables and Secrets) :
 *   SOMFY_USER, SOMFY_PASSWORD  identifiants Somfy Protect
 *   API_KEY                     clé longue et aléatoire, connue seulement de la montre
 *   SOMFY_SITE_ID (facultatif)  si le compte a plusieurs sites
 * Liaison KV facultative nommée TOKENS : garde le jeton Somfy entre deux appels
 * (sinon le Worker se reconnecte avec le mot de passe quand il redémarre).
 *
 * API non officielle de l'app mobile (api.myfox.io) : Somfy peut la modifier.
 */

const DEFAULT_API_URL = "https://api.myfox.io";
const DEFAULT_TOKEN_URL = "https://sso.myfox.io/oauth/oauth/v2/token";

// Identifiants OAuth publics de l'app mobile (repris de la bibliothèque
// open source somfy-protect-api, utilisée par Home Assistant).
const CLIENT_ID = atob(
  "ODRlZGRmNDgtMmI4ZS0xMWU1LWIyYTUtMTI0Y2ZhYjI1NTk1XzQ3NWJ1cXJmOHY4a2d3b280" +
  "Z293MDhna2tjMGNrODA0ODh3bzQ0czhvNDhzZzg0azQw");
const CLIENT_SECRET = atob(
  "NGRzcWZudGlldTB3Y2t3d280MGt3ODQ4Z3c0bzBjOGs0b3djODBrNGdvMGNzMGs4NDQ=");

const ACTIONS = { "/arm": "armed", "/partial": "partial", "/disarm": "disarmed" };
const TOKEN_KEY = "somfy_token";

// Jeton gardé en mémoire tant que le Worker reste actif.
let memoryToken = null;

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function sameSecret(a, b) {
  // Comparaison à temps constant pour ne rien révéler de la clé.
  if (typeof a !== "string" || typeof b !== "string" || !b) return false;
  let diff = a.length ^ b.length;
  for (let i = 0; i < b.length; i++) {
    diff |= (a.charCodeAt(i % (a.length || 1)) || 0) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

class Somfy {
  constructor(env) {
    this.env = env;
    this.apiUrl = env.SOMFY_API_URL || DEFAULT_API_URL;
    this.tokenUrl = env.SOMFY_TOKEN_URL || DEFAULT_TOKEN_URL;
  }

  async loadToken() {
    if (memoryToken) return memoryToken;
    if (this.env.TOKENS) {
      const raw = await this.env.TOKENS.get(TOKEN_KEY);
      if (raw) memoryToken = JSON.parse(raw);
    }
    return memoryToken;
  }

  async saveToken(tok) {
    memoryToken = {
      access_token: tok.access_token,
      refresh_token: tok.refresh_token || (memoryToken && memoryToken.refresh_token),
      expires_at: Date.now() + ((Number(tok.expires_in) || 3600) - 60) * 1000,
    };
    if (this.env.TOKENS) await this.env.TOKENS.put(TOKEN_KEY, JSON.stringify(memoryToken));
  }

  async requestToken(fields) {
    const body = new URLSearchParams({
      ...fields, client_id: CLIENT_ID, client_secret: CLIENT_SECRET,
    });
    const resp = await fetch(this.tokenUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "Somfy Protect" },
      body: body.toString(),
    });
    if (!resp.ok) return null;
    const tok = await resp.json();
    if (!tok.access_token) return null;
    await this.saveToken(tok);
    return memoryToken.access_token;
  }

  async login() {
    if (!this.env.SOMFY_USER || !this.env.SOMFY_PASSWORD) {
      throw new HttpError(500, "secrets SOMFY_USER / SOMFY_PASSWORD manquants");
    }
    const t = await this.requestToken({
      grant_type: "password", username: this.env.SOMFY_USER, password: this.env.SOMFY_PASSWORD,
    });
    if (!t) throw new HttpError(502, "connexion Somfy refusée (identifiants ?)");
    return t;
  }

  async refresh() {
    const tok = await this.loadToken();
    if (!tok || !tok.refresh_token) return null;
    return this.requestToken({ grant_type: "refresh_token", refresh_token: tok.refresh_token });
  }

  async accessToken(force = false) {
    const tok = await this.loadToken();
    if (!force && tok && tok.expires_at > Date.now()) return tok.access_token;
    return (await this.refresh()) || (await this.login());
  }

  async api(method, path, body) {
    const call = async (token) => fetch(this.apiUrl + path, {
      method,
      headers: {
        "Authorization": `Bearer ${token}`, "User-Agent": "Somfy Protect",
        "Accept": "application/json",
        ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    let resp = await call(await this.accessToken());
    if (resp.status === 401 || resp.status === 403) {
      // Jeton révoqué côté Somfy : on en reprend un et on réessaie une fois.
      resp = await call(await this.accessToken(true));
    }
    if (!resp.ok) throw new HttpError(502, `Somfy a répondu HTTP ${resp.status} sur ${path}`);
    const text = await resp.text();
    return text ? JSON.parse(text) : {};
  }

  async site() {
    const { items = [] } = await this.api("GET", "/v3/site");
    if (!items.length) throw new HttpError(502, "aucun site sur ce compte");
    const wanted = this.env.SOMFY_SITE_ID;
    if (wanted) {
      const s = items.find((x) => x.site_id === wanted);
      if (!s) throw new HttpError(500, `site ${wanted} introuvable`);
      return s;
    }
    if (items.length > 1) {
      throw new HttpError(500, "plusieurs sites : définir SOMFY_SITE_ID ("
        + items.map((s) => `${s.site_id}=${s.label}`).join(", ") + ")");
    }
    return items[0];
  }
}

async function handle(request, env) {
  const url = new URL(request.url);
  const auth = request.headers.get("Authorization") || "";
  const key = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!env.API_KEY) throw new HttpError(500, "secret API_KEY manquant");
  if (!sameSecret(key, env.API_KEY)) throw new HttpError(401, "clé invalide");

  const somfy = new Somfy(env);

  if (url.pathname === "/status" && request.method === "GET") {
    const s = await somfy.site();
    return json({ site: s.label, status: s.security_level, confirmed: true });
  }

  const target = ACTIONS[url.pathname];
  if (target && request.method === "POST") {
    const s = await somfy.site();
    await somfy.api("PUT", `/v3/site/${s.site_id}/security`, { status: target });
    // Somfy applique la demande en différé : on vérifie pendant ~10 s.
    let current = s.security_level;
    for (let i = 0; i < 5; i++) {
      await sleep(Number(env.POLL_MS) || 2000);
      current = (await somfy.api("GET", `/v3/site/${s.site_id}`)).security_level;
      if (current === target) break;
    }
    return json({ site: s.label, status: current, confirmed: current === target });
  }

  throw new HttpError(404, "route inconnue");
}

export default {
  async fetch(request, env) {
    try {
      return await handle(request, env);
    } catch (e) {
      const status = e instanceof HttpError ? e.status : 500;
      return json({ error: e.message || String(e) }, status);
    }
  },
};
