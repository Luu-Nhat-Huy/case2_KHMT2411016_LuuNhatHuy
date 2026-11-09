const mongoose = require("mongoose");
const Task = require("../models/task");
const User = require("../models/user");

const validStatuses = ["todo", "in-progress", "completed"];
const validPriorities = ["low", "medium", "high"];
const priorityRank = { low: 1, medium: 2, high: 3 };
const userFields = "fullName email";

function validDate(value) {
  if (value === null || value === undefined || value === "") return true;
  if (typeof value === "string") {
    const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (match) {
      const y = Number(match[1]), m = Number(match[2]), d = Number(match[3]);
      const date = new Date(Date.UTC(y, m - 1, d));
      return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
    }
  }
  return !Number.isNaN(new Date(value).getTime());
}

function normalizeDate(value) {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) return new Date(`${value}T00:00:00.000Z`);
  return new Date(value);
}

function dateAfter(a, b) {
  return !!a && !!b && normalizeDate(a).getTime() > normalizeDate(b).getTime();
}

function accessibleQuery(userId) {
  return { $or: [
    { createdBy: userId },
    { assignedTo: userId },
    { "sharedWith.user": userId },
  ] };
}

async function validateUserIds(ids) {
  const unique = [...new Set((ids || []).filter(Boolean).map(String))];
  if (unique.some((id) => !mongoose.Types.ObjectId.isValid(id))) return null;
  const count = await User.countDocuments({ _id: { $in: unique } });
  return count === unique.length ? unique : null;
}

function populateTask(query) {
  return query
    .populate("createdBy", userFields)
    .populate("assignedTo", userFields)
    .populate("sharedWith.user", userFields);
}

// GET /api/tasks/users?search=
exports.getTaskUsers = async (req, res) => {
  try {
    const search = (req.query.search || "").trim();
    const query = { _id: { $ne: req.user.id } };
    if (search) {
      const escaped = search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      query.$or = [
        { fullName: { $regex: escaped, $options: "i" } },
        { email: { $regex: escaped, $options: "i" } },
      ];
    }
    const users = await User.find(query).select("fullName email").sort({ fullName: 1 }).limit(50).lean();
    return res.json({ success: true, users });
  } catch (error) {
    console.error("Get task users error:", error);
    return res.status(500).json({ success: false, message: "Loi may chu khi lay danh sach nguoi dung." });
  }
};

// POST /api/tasks
exports.createTask = async (req, res) => {
  try {
    const { title, description = "", status = "todo", priority = "medium", startDate = null, dueDate = null } = req.body;
    if (typeof title !== "string" || !title.trim()) return res.status(400).json({ success: false, message: "Ten cong viec la bat buoc." });
    if (!validStatuses.includes(status) || !validPriorities.includes(priority)) return res.status(400).json({ success: false, message: "Trang thai hoac muc uu tien khong hop le." });
    if (!validDate(startDate) || !validDate(dueDate)) return res.status(400).json({ success: false, message: "Ngay bat dau hoac han hoan thanh khong hop le." });
    if (dateAfter(startDate, dueDate)) return res.status(400).json({ success: false, message: "Ngay bat dau khong duoc sau han hoan thanh." });

    let assignedTo = null;
    if (req.body.assignedTo) {
      const ids = await validateUserIds([req.body.assignedTo]);
      if (!ids) return res.status(400).json({ success: false, message: "Nguoi duoc giao khong ton tai hoac ID khong hop le." });
      if (ids[0] === String(req.user.id)) return res.status(400).json({ success: false, message: "Khong the giao cong viec cho chinh minh." });
      assignedTo = ids[0];
    }

    const sharedIds = await validateUserIds(req.body.sharedWith || []);
    if (!sharedIds) return res.status(400).json({ success: false, message: "Danh sach nguoi duoc chia se khong hop le." });
    if (sharedIds.includes(String(req.user.id)) || (assignedTo && sharedIds.includes(assignedTo))) {
      return res.status(400).json({ success: false, message: "Nguoi chia se khong hop le hoac bi trung nguoi duoc giao." });
    }
    const sharedWith = sharedIds.map((id) => ({ user: id, permission: "viewer" }));

    const task = await Task.create({ title: title.trim(), description, status, priority,
      startDate: normalizeDate(startDate), dueDate: normalizeDate(dueDate),
      createdBy: req.user.id, assignedTo, sharedWith });
    await task.populate([{ path: "createdBy", select: userFields }, { path: "assignedTo", select: userFields }, { path: "sharedWith.user", select: userFields }]);
    return res.status(201).json({ success: true, message: "Tao cong viec thanh cong.", task });
  } catch (error) {
    console.error("Create task error:", error);
    return res.status(500).json({ success: false, message: "Loi may chu khi tao cong viec." });
  }
};

// GET /api/tasks?view=all|created|assigned|received|shared
exports.getTasks = async (req, res) => {
  try {
    const { search, status, priority, sortBy = "createdAt", order = "desc", view = "all", assignee = "all" } = req.query;
    const uid = String(req.user.id);
    let query;
    switch (view) {
      case "created": query = { createdBy: uid }; break;
      case "assigned": query = { createdBy: uid, assignedTo: { $ne: null } }; break;
      case "received": query = { assignedTo: uid }; break;
      case "shared": query = { "sharedWith.user": uid }; break;
      case "all": query = accessibleQuery(uid); break;
      default: return res.status(400).json({ success: false, message: "Loai danh sach cong viec khong hop le." });
    }
    if (search && search.trim()) {
      const escaped = search.trim().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      query.title = { $regex: escaped, $options: "i" };
    }
    if (status && status !== "all") {
      if (!validStatuses.includes(status)) return res.status(400).json({ success: false, message: "Bo loc trang thai khong hop le." });
      query.status = status;
    }
    if (priority && priority !== "all") {
      if (!validPriorities.includes(priority)) return res.status(400).json({ success: false, message: "Bo loc uu tien khong hop le." });
      query.priority = priority;
    }
    if (assignee !== "all") {
      if (!mongoose.Types.ObjectId.isValid(assignee)) return res.status(400).json({ success: false, message: "Nguoi duoc giao khong hop le." });
      query.assignedTo = assignee;
    }
    const direction = order === "asc" ? 1 : -1;
    let tasks;
    if (sortBy === "priority") {
      tasks = await populateTask(Task.find(query)).lean();
      tasks.sort((a, b) => ((priorityRank[a.priority] || 0) - (priorityRank[b.priority] || 0)) * direction || (new Date(b.createdAt) - new Date(a.createdAt)));
    } else {
      const field = sortBy === "dueDate" ? "dueDate" : "createdAt";
      tasks = await populateTask(Task.find(query).sort({ [field]: direction, createdAt: -1 }));
    }
    return res.status(200).json({ success: true, total: tasks.length, tasks });
  } catch (error) {
    console.error("Get tasks error:", error);
    return res.status(500).json({ success: false, message: "Loi may chu khi lay danh sach cong viec." });
  }
};

exports.getTaskById = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ success: false, message: "ID cong viec khong hop le." });
    const task = await populateTask(Task.findOne({ _id: id, ...accessibleQuery(req.user.id) }));
    if (!task) return res.status(404).json({ success: false, message: "Khong tim thay cong viec." });
    return res.json({ success: true, task });
  } catch (error) {
    console.error("Get task detail error:", error);
    return res.status(500).json({ success: false, message: "Loi may chu khi xem cong viec." });
  }
};

exports.updateTask = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ success: false, message: "ID cong viec khong hop le." });
    const task = await Task.findOne({ _id: id, ...accessibleQuery(req.user.id) });
    if (!task) return res.status(404).json({ success: false, message: "Khong tim thay cong viec." });

    const uid = String(req.user.id);
    const isOwner = String(task.createdBy) === uid;
    const isAssignee = task.assignedTo && String(task.assignedTo) === uid;
    const sharedEntry = task.sharedWith.find((entry) => String(entry.user) === uid);
    const canEditAll = isOwner || sharedEntry?.permission === "editor";
    const body = req.body || {};
    const allowed = ["title", "description", "status", "priority", "startDate", "dueDate"];
    const update = {};
    for (const key of allowed) if (body[key] !== undefined) update[key] = body[key];
    if (!canEditAll && !(isAssignee && Object.keys(update).every((key) => key === "status"))) {
      return res.status(403).json({ success: false, message: "Ban khong co quyen chinh sua cong viec nay." });
    }
    if (update.title !== undefined) {
      if (typeof update.title !== "string" || !update.title.trim()) return res.status(400).json({ success: false, message: "Ten cong viec khong hop le." });
      update.title = update.title.trim();
    }
    if (update.status !== undefined && !validStatuses.includes(update.status)) return res.status(400).json({ success: false, message: "Trang thai khong hop le." });
    if (update.priority !== undefined && !validPriorities.includes(update.priority)) return res.status(400).json({ success: false, message: "Muc uu tien khong hop le." });
    for (const key of ["startDate", "dueDate"]) {
      if (update[key] !== undefined) {
        if (!validDate(update[key])) return res.status(400).json({ success: false, message: "Ngay khong hop le." });
        update[key] = normalizeDate(update[key]);
      }
    }
    if (canEditAll && body.assignedTo !== undefined) {
      if (body.assignedTo === null || body.assignedTo === "") update.assignedTo = null;
      else {
        const ids = await validateUserIds([body.assignedTo]);
        if (!ids || ids[0] === uid) return res.status(400).json({ success: false, message: "Nguoi duoc giao khong hop le." });
        update.assignedTo = ids[0];
      }
    }
    if (canEditAll && body.sharedWith !== undefined) {
      const ids = await validateUserIds(body.sharedWith);
      if (!ids || ids.includes(uid) || (update.assignedTo && ids.includes(String(update.assignedTo)))) return res.status(400).json({ success: false, message: "Danh sach chia se khong hop le." });
      update.sharedWith = ids.map((userId) => {
        const old = task.sharedWith.find((x) => String(x.user) === userId);
        return { user: userId, permission: old?.permission || "viewer" };
      });
    }
    const start = update.startDate !== undefined ? update.startDate : task.startDate;
    const due = update.dueDate !== undefined ? update.dueDate : task.dueDate;
    if (dateAfter(start, due)) return res.status(400).json({ success: false, message: "Ngay bat dau khong duoc sau han hoan thanh." });
    Object.assign(task, update);
    await task.save();
    await task.populate([{ path: "createdBy", select: userFields }, { path: "assignedTo", select: userFields }, { path: "sharedWith.user", select: userFields }]);
    return res.json({ success: true, message: "Cap nhat cong viec thanh cong.", task });
  } catch (error) {
    console.error("Update task error:", error);
    return res.status(500).json({ success: false, message: "Loi may chu khi cap nhat cong viec." });
  }
};

exports.deleteTask = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ success: false, message: "ID cong viec khong hop le." });
    const task = await Task.findOneAndDelete({ _id: id, createdBy: req.user.id });
    if (!task) return res.status(404).json({ success: false, message: "Khong tim thay cong viec hoac ban khong co quyen xoa." });
    return res.json({ success: true, message: "Xoa cong viec thanh cong." });
  } catch (error) {
    console.error("Delete task error:", error);
    return res.status(500).json({ success: false, message: "Loi may chu khi xoa cong viec." });
  }
};
