const mongoose = require("mongoose");

async function connectDatabase() {
  const mongoUri = process.env.MONGODB_URI;

  // Chưa cấu hình MongoDB thì cho phép API chạy tạm thời.
  if (!mongoUri) {
    console.warn("CANH BAO: Chua cau hinh MONGODB_URI trong file .env");
    return false;
  }

  try {
    await mongoose.connect(mongoUri);
    console.log("Da ket noi MongoDB thanh cong!");
    return true;
  } catch (error) {
    console.error("Khong the ket noi MongoDB:", error.message);
    throw error;
  }
}

module.exports = connectDatabase;
