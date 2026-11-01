require("dotenv").config();

const app = require("./app");
const connectDatabase = require("./config/database");

const PORT = process.env.PORT || 3000;

async function startServer() {
  try {
    await connectDatabase();

    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Task Manager API dang chay tai port ${PORT}`);
      console.log(`Kiem tra: http://localhost:${PORT}/api/health`);
    });
  } catch (error) {
    console.error("Khong the khoi dong server:", error.message);
    process.exit(1);
  }
}

startServer();
