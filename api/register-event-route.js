import express from "express";
import { PutCommand } from "@aws-sdk/lib-dynamodb";
import { doc, tableName } from "../src/ddb_client.js";
import { buildSessionPk, buildTsSk, nowIso, ttlFromNow } from "../src/ddb_keys.js";

export default function registerEventRoute(app) {
  const router = express.Router();

  router.post("/event", async (req, res) => {
    try {
      const { sessionId, userId, ts } = req.body || {};
      if (!sessionId || !userId) return res.status(400).json({ error: "missing sessionId or userId" });
      const createdAt = ts ? new Date(ts * 1000).toISOString().replace(/\.\d{3}Z$/, "Z") : nowIso();
      const pk = buildSessionPk(sessionId);
      const sk = buildTsSk(createdAt);
      const ttl = ttlFromNow(parseInt(process.env.EVENT_TTL_SECONDS || "2592000"));
      await doc.send(new PutCommand({ TableName: tableName, Item: { pk, sk, userId, createdAt, ttl, type: "SESSION_EVENT" } }));
      return res.status(201).json({ ok: true, pk, sk, userId, createdAt });
    } catch (e) {
      return res.status(500).json({ error: "internal_error" });
    }
  });

  app.use("/api/v1", express.json(), router);
}
