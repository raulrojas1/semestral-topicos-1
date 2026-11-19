const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.APP_VERSION || "dev";

app.use(express.json());

// Almacenamiento en memoria (suficiente para la demo)
const items = [
  { id: 1, text: "Infraestructura con Terraform" },
  { id: 2, text: "Imágenes en ECR" },
];
let nextId = 3;

app.get("/api/health", (_req, res) => res.json({ status: "ok" }));

app.get("/api/info", (_req, res) =>
  res.json({ service: "backend", version: VERSION, hostname: require("os").hostname() })
);

app.get("/api/items", (_req, res) => res.json(items));

app.post("/api/items", (req, res) => {
  const text = typeof req.body?.text === "string" ? req.body.text.trim() : "";
  if (!text || text.length > 200) {
    return res.status(400).json({ error: "text es requerido (máx. 200 caracteres)" });
  }
  const item = { id: nextId++, text };
  items.push(item);
  res.status(201).json(item);
});

app.listen(PORT, () => console.log(`backend escuchando en ${PORT}`));
