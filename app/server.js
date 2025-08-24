import express from "express";
import path from "path";
import { fileURLToPath } from "url";
import registerEventRoute from "../api/register-event-route.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

app.get("/api/v1/status", (req, res) => {
  res.json({ ok: true, ts: new Date().toISOString(), region: process.env.AWS_REGION || "unknown" });
});

app.get("/api/v1/profile", (req, res) => {
  res.json({ ok: true, user: "demo", cached: false });
});

app.use("/static", express.static(path.join(__dirname, "../public/static")));

registerEventRoute(app);

const PORT = parseInt(process.env.PORT || "80", 10);
app.listen(PORT, () => {
  console.log(`server listening on :${PORT}`);
});
