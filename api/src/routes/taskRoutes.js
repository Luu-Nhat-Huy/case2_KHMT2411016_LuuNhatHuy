const express = require("express");

const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");

const {
  createTask,
  getTasks,
  getTaskById,
  updateTask,
  deleteTask,
} = require("../controllers/taskController");

// Tat ca API Task deu yeu cau dang nhap
router.use(authMiddleware);

// Tao cong viec
router.post("/", createTask);

// Lay danh sach cong viec
router.get("/", getTasks);

// Xem chi tiet cong viec
router.get("/:id", getTaskById);

// Cap nhat cong viec
router.put("/:id", updateTask);

// Xoa cong viec
router.delete("/:id", deleteTask);

module.exports = router;
