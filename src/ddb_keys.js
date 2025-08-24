export function buildUserPk(userId) { return `USER#${userId}`; }
export function buildSessionPk(sessionId) { return `SESSION#${sessionId}`; }
export function buildTsSk(iso) { return `TS#${iso}`; }
export function buildMetaSk() { return "META"; }
export function parsePk(pk) { const [type, id] = pk.split("#"); return { type, id }; }
export function parseTsSk(sk) { return sk.startsWith("TS#") ? { type: "TS", value: sk.slice(3) } : { type: "UNKNOWN", value: sk }; }
export function nowIso() { return new Date().toISOString().replace(/\.\d{3}Z$/, "Z"); }
export function ttlFromNow(seconds) { return Math.floor(Date.now() / 1000) + seconds; }
