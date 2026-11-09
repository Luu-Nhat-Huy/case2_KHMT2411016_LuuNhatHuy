const express = require("express");

const {
  register,
  login,
  getProfile,
  updateProfile,
  changePassword,
} = require("../controllers/authController");

const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

// Dang ky, dang nhap
router.post("/register", register);
router.post("/login", login);

// Quan ly thong tin ca nhan
router.get("/profile", authMiddleware, getProfile);
router.put("/profile", authMiddleware, updateProfile);

// Doi mat khau
router.put("/change-password", authMiddleware, changePassword);

module.exports = router;
