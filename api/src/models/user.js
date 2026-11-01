const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: [true, "Ho ten la bat buoc"],
      trim: true,
      maxlength: 100,
    },
    email: {
      type: String,
      required: [true, "Email la bat buoc"],
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: {
      type: String,
      required: [true, "Mat khau la bat buoc"],
      minlength: 8,
      select: false,
    },
  },
  {
    timestamps: true,
  },
);

module.exports = mongoose.model("User", userSchema);
