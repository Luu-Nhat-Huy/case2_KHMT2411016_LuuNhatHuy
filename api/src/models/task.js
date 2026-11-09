const mongoose = require("mongoose");

const sharedUserSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    permission: { type: String, enum: ["viewer", "editor"], default: "viewer" },
  },
  { _id: false },
);

const taskSchema = new mongoose.Schema(
  {
    title: { type: String, required: [true, "Ten cong viec la bat buoc"], trim: true, maxlength: 200 },
    description: { type: String, trim: true, default: "" },
    status: { type: String, enum: ["todo", "in-progress", "completed"], default: "todo" },
    priority: { type: String, enum: ["low", "medium", "high"], default: "medium" },
    startDate: { type: Date, default: null },
    dueDate: { type: Date, default: null },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
    sharedWith: { type: [sharedUserSchema], default: [] },
  },
  { timestamps: true },
);

taskSchema.index({ createdBy: 1, createdAt: -1 });
taskSchema.index({ assignedTo: 1, dueDate: 1 });
taskSchema.index({ "sharedWith.user": 1 });

module.exports = mongoose.model("Task", taskSchema);
