const path = require("path");
const express = require("express");
const bodyParser = require("body-parser");

const port = Number(process.env.PORT) || 3000;
const app = express();

app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, "..", "public")));

// Called by todo-front when a todo is created, with the same payload it sends to todo-store.
// For now the hub only logs the payload.
app.post("/api/notifications", (req, res) => {
  console.log(`todo created: ${JSON.stringify(req.body)}`);
  res.status(202).json({ status: "accepted" });
});

// Liveness / readiness probes for Kubernetes
app.get("/healthz", (req, res) => {
  res.send("healthy");
});

app.listen(port, () => {
  console.log(`todo-notification-hub listening on port ${port}`);
});
