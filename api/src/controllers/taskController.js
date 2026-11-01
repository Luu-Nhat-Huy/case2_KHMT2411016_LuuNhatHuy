const mongoose = require("mongoose");
const Task = require("../models/task");

// 1. Tao cong viec
exports.createTask = async (req, res) => {
  try {
    const { title, description, status, priority, dueDate } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({
        success: false,
        message: "Ten cong viec la bat buoc.",
      });
    }

    const task = await Task.create({
      title,
      description,
      status,
      priority,
      dueDate: dueDate || null,
      createdBy: req.user.id,
    });

    return res.status(201).json({
      success: true,
      message: "Tao cong viec thanh cong.",
      task,
    });
  } catch (error) {
    console.error("Create task error:", error);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi tao cong viec.",
    });
  }
};

// 2. Lay danh sach cong viec
exports.getTasks = async (req, res) => {
  try {
    const tasks = await Task.find({
      createdBy: req.user.id,
    }).sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      total: tasks.length,
      tasks,
    });
  } catch (error) {
    console.error("Get tasks error:", error);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi lay danh sach cong viec.",
    });
  }
};

// 3. Xem chi tiet cong viec
exports.getTaskById = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        success: false,
        message: "ID cong viec khong hop le.",
      });
    }

    const task = await Task.findOne({
      _id: id,
      createdBy: req.user.id,
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Khong tim thay cong viec.",
      });
    }

    return res.status(200).json({
      success: true,
      task,
    });
  } catch (error) {
    console.error("Get task detail error:", error);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi xem cong viec.",
    });
  }
};

// 4. Cap nhat cong viec
exports.updateTask = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        success: false,
        message: "ID cong viec khong hop le.",
      });
    }

    const allowedFields = [
      "title",
      "description",
      "status",
      "priority",
      "dueDate",
    ];

    const updateData = {};

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updateData[field] = req.body[field];
      }
    }

    if (
      updateData.title !== undefined &&
      (typeof updateData.title !== "string" || !updateData.title.trim())
    ) {
      return res.status(400).json({
        success: false,
        message: "Ten cong viec khong hop le.",
      });
    }

    if (updateData.title !== undefined) {
      updateData.title = updateData.title.trim();
    }

    const task = await Task.findOneAndUpdate(
      {
        _id: id,
        createdBy: req.user.id,
      },
      updateData,
      {
        new: true,
        runValidators: true,
      },
    );

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Khong tim thay cong viec.",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Cap nhat cong viec thanh cong.",
      task,
    });
  } catch (error) {
    console.error("Update task error:", error);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi cap nhat cong viec.",
    });
  }
};

// 5. Xoa cong viec
exports.deleteTask = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        success: false,
        message: "ID cong viec khong hop le.",
      });
    }

    const task = await Task.findOneAndDelete({
      _id: id,
      createdBy: req.user.id,
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Khong tim thay cong viec.",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Xoa cong viec thanh cong.",
    });
  } catch (error) {
    console.error("Delete task error:", error);

    return res.status(500).json({
      success: false,
      message: "Loi may chu khi xoa cong viec.",
    });
  }
};
