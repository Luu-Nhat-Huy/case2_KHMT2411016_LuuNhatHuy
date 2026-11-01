const express = require("express");
const cors = require("cors");

const authRoutes = require("./routes/authRoutes");
const taskRoutes = require("./routes/taskRoutes");

const app = express();

app.use(cors());
app.use(express.json());

// API kiem tra server
app.get("/api/health", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Task Manager API dang hoat dong!",
    timestamp: new Date().toISOString(),
  });
});

// API xac thuc tai khoan
app.use("/api/auth", authRoutes);

// API quan ly cong viec
app.use("/api/tasks", taskRoutes);

// Xu ly API khong ton tai
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Khong tim thay API nay.",
  });
});

module.exports = app;
