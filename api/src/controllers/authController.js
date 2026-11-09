const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/user");

function createToken(user) {
  if (!process.env.JWT_SECRET) {
    throw new Error("Chua cau hinh JWT_SECRET trong file .env");
  }

  return jwt.sign(
    {
      id: user._id.toString(),
      email: user.email,
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRES_IN || "7d",
    },
  );
}

// =========================
// 1. DANG KY
// =========================
exports.register = async (req, res) => {
  try {
    const { fullName, email, password } = req.body;

    if (!fullName || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "Vui long nhap ho ten, email va mat khau.",
      });
    }

    if (password.length < 8) {
      return res.status(400).json({
        success: false,
        message: "Mat khau phai co it nhat 8 ky tu.",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const existingUser = await User.findOne({
      email: normalizedEmail,
    });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: "Email da duoc dang ky.",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 12);

    const user = await User.create({
      fullName: fullName.trim(),
      email: normalizedEmail,
      password: hashedPassword,
    });

    const token = createToken(user);

    return res.status(201).json({
      success: true,
      message: "Dang ky thanh cong.",
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
      },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "Email da duoc dang ky.",
      });
    }

    console.error("Register error:", error);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi dang ky.",
    });
  }
};

// =========================
// 2. DANG NHAP
// =========================
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Vui long nhap email va mat khau.",
      });
    }

    const user = await User.findOne({
      email: email.trim().toLowerCase(),
    }).select("+password");

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Email hoac mat khau khong dung.",
      });
    }

    const passwordMatches = await bcrypt.compare(password, user.password);

    if (!passwordMatches) {
      return res.status(401).json({
        success: false,
        message: "Email hoac mat khau khong dung.",
      });
    }

    const token = createToken(user);

    return res.status(200).json({
      success: true,
      message: "Dang nhap thanh cong.",
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
      },
    });
  } catch (error) {
    console.error("Login error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi dang nhap.",
    });
  }
};

// =========================
// 3. XEM THONG TIN CA NHAN
// =========================
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select("-password");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Khong tim thay tai khoan.",
      });
    }

    return res.status(200).json({
      success: true,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    console.error("Profile error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi lay thong tin ca nhan.",
    });
  }
};

// =========================
// 4. CAP NHAT THONG TIN CA NHAN
// =========================
exports.updateProfile = async (req, res) => {
  try {
    const { fullName, email } = req.body;

    if (!fullName || !email) {
      return res.status(400).json({
        success: false,
        message: "Vui long nhap day du ho ten va email.",
      });
    }

    const normalizedName = fullName.trim();
    const normalizedEmail = email.trim().toLowerCase();

    if (normalizedName.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Ho ten khong duoc de trong.",
      });
    }

    if (normalizedName.length > 100) {
      return res.status(400).json({
        success: false,
        message: "Ho ten khong duoc vuot qua 100 ky tu.",
      });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailRegex.test(normalizedEmail)) {
      return res.status(400).json({
        success: false,
        message: "Email khong hop le.",
      });
    }

    // Kiem tra email da duoc tai khoan khac su dung chua
    const existingUser = await User.findOne({
      email: normalizedEmail,
      _id: { $ne: req.user.id },
    });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: "Email nay da duoc tai khoan khac su dung.",
      });
    }

    const user = await User.findByIdAndUpdate(
      req.user.id,
      {
        $set: {
          fullName: normalizedName,
          email: normalizedEmail,
        },
      },
      {
        new: true,
        runValidators: true,
      },
    ).select("-password");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Khong tim thay tai khoan.",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Cap nhat thong tin ca nhan thanh cong.",
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "Email nay da duoc tai khoan khac su dung.",
      });
    }

    console.error("Update profile error:", error);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi cap nhat thong tin.",
    });
  }
};

// =========================
// 5. DOI MAT KHAU
// =========================
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword, confirmPassword } = req.body;

    if (!currentPassword || !newPassword || !confirmPassword) {
      return res.status(400).json({
        success: false,
        message: "Vui long nhap day du thong tin mat khau.",
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: "Mat khau moi phai co it nhat 8 ky tu.",
      });
    }

    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: "Xac nhan mat khau moi khong khop.",
      });
    }

    if (currentPassword === newPassword) {
      return res.status(400).json({
        success: false,
        message: "Mat khau moi phai khac mat khau hien tai.",
      });
    }

    // Lay tai khoan kem mat khau de kiem tra
    const user = await User.findById(req.user.id).select("+password");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Khong tim thay tai khoan.",
      });
    }

    // Xac minh mat khau hien tai
    const passwordMatches = await bcrypt.compare(
      currentPassword,
      user.password,
    );

    if (!passwordMatches) {
      return res.status(400).json({
        success: false,
        message: "Mat khau hien tai khong chinh xac.",
      });
    }

    // Ma hoa mat khau moi truoc khi luu
    user.password = await bcrypt.hash(newPassword, 12);
    await user.save();

    return res.status(200).json({
      success: true,
      message: "Doi mat khau thanh cong.",
    });
  } catch (error) {
    console.error("Change password error:", error);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi doi mat khau.",
    });
  }
};
