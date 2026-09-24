require("dotenv").config();
const path = require("path");
const fs = require("fs");
const express = require("express");
const { Pool } = require("pg");

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const app = express();
app.use(express.json({ limit: "20mb" }));

// Bảo vệ bằng mật khẩu đơn giản (HTTP Basic) nếu đặt APP_USER / APP_PASSWORD trong .env
if (process.env.APP_USER && process.env.APP_PASSWORD) {
  const expected = "Basic " + Buffer.from(`${process.env.APP_USER}:${process.env.APP_PASSWORD}`).toString("base64");
  app.use((req, res, next) => {
    if (req.headers.authorization === expected) return next();
    res.set("WWW-Authenticate", 'Basic realm="AZ OFFICE"').status(401).send("Cần đăng nhập");
  });
}

app.use(express.static(path.join(__dirname, "public")));

// Lấy toàn bộ dữ liệu
app.get("/api/state", async (req, res) => {
  try {
    const { rows } = await pool.query("SELECT data, version, updated_at FROM app_state WHERE id = 1");
    res.json(rows[0] || { data: null, version: 0 });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Lỗi đọc CSDL" });
  }
});

// Lưu dữ liệu (có kiểm tra phiên bản để tránh ghi đè khi nhiều người cùng sửa)
app.put("/api/state", async (req, res) => {
  const { version, data } = req.body || {};
  if (!data || typeof data !== "object") return res.status(400).json({ error: "Thiếu dữ liệu" });
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const cur = await client.query("SELECT data, version FROM app_state WHERE id = 1 FOR UPDATE");
    let newVersion;
    if (cur.rows.length === 0) {
      newVersion = 1;
      await client.query("INSERT INTO app_state (id, data, version) VALUES (1, $1, 1)", [data]);
    } else {
      if (cur.rows[0].version !== Number(version)) {
        await client.query("ROLLBACK");
        return res.status(409).json(cur.rows[0]);
      }
      newVersion = cur.rows[0].version + 1;
      await client.query("UPDATE app_state SET data = $1, version = $2, updated_at = now() WHERE id = 1", [data, newVersion]);
    }
    await client.query("INSERT INTO app_state_history (version, data) VALUES ($1, $2)", [newVersion, data]);
    await client.query("COMMIT");
    res.json({ version: newVersion });
  } catch (e) {
    await client.query("ROLLBACK").catch(() => {});
    console.error(e);
    res.status(500).json({ error: "Lỗi ghi CSDL" });
  } finally {
    client.release();
  }
});

async function start() {
  await pool.query(fs.readFileSync(path.join(__dirname, "db", "schema.sql"), "utf8"));
  const port = Number(process.env.PORT) || 3000;
  app.listen(port, () => console.log(`AZ OFFICE đang chạy tại http://localhost:${port}`));
}
start().catch((e) => {
  console.error("Không khởi động được server:", e.message);
  process.exit(1);
});
