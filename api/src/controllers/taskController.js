const mongoose = require("mongoose");
const Task = require("../models/task");
const User = require("../models/user");

// =====================================================
// HÀM HỖ TRỢ
// =====================================================

function getCurrentUserId(req) {
  return req.user?.id || req.user?._id || null;
}

function isValidId(id) {
  return !!id && mongoose.Types.ObjectId.isValid(id);
}

function getUserId(value) {
  if (!value) return null;

  if (typeof value === "object") {
    if (value._id) return value._id.toString();
    if (value.id) return value.id.toString();
  }

  return value.toString();
}

// Những công việc người dùng có quyền truy cập
function accessibleQuery(userId) {
  return {
    $or: [
      { createdBy: userId },
      { assignedTo: userId },
      { assignedUsers: userId },
      { primaryAssignee: userId },
      { "sharedWith.user": userId },
    ],
  };
}

// Lấy đầy đủ thông tin người dùng trong công việc
function populateTask(query) {
  return query
    .populate("createdBy", "fullName email")
    .populate("assignedTo", "fullName email")
    .populate("assignedUsers", "fullName email")
    .populate("primaryAssignee", "fullName email")
    .populate("sharedWith.user", "fullName email");
}

// Kiểm tra ngày
function validateDates(startDate, dueDate) {
  if (startDate) {
    const start = new Date(startDate);

    if (Number.isNaN(start.getTime())) {
      return "Ngay bat dau khong hop le.";
    }
  }

  if (dueDate) {
    const due = new Date(dueDate);

    if (Number.isNaN(due.getTime())) {
      return "Ngay ket thuc khong hop le.";
    }
  }

  if (startDate && dueDate) {
    const start = new Date(startDate);
    const due = new Date(dueDate);

    if (start > due) {
      return "Ngay bat dau khong duoc lon hon ngay ket thuc.";
    }
  }

  return null;
}

// Kiểm tra trạng thái và độ ưu tiên
function validateTaskFields(body) {
  const allowedStatus = ["todo", "in-progress", "completed"];
  const allowedPriority = ["low", "medium", "high"];

  if (body.status !== undefined && !allowedStatus.includes(body.status)) {
    return "Trang thai cong viec khong hop le.";
  }

  if (body.priority !== undefined && !allowedPriority.includes(body.priority)) {
    return "Muc do uu tien khong hop le.";
  }

  return null;
}

// Chuẩn hóa danh sách chia sẻ
function normalizeSharedWith(sharedWith) {
  if (!Array.isArray(sharedWith)) {
    return null;
  }

  return sharedWith.map((item) => {
    if (typeof item === "string") {
      return {
        user: item,
        permission: "viewer",
      };
    }

    if (!item || typeof item !== "object") {
      return {
        user: null,
        permission: "viewer",
      };
    }

    const userId = getUserId(item.user || item.userId || item._id);

    return {
      user: userId,
      permission: item.permission || "viewer",
    };
  });
}

// Kiểm tra danh sách ID người dùng có tồn tại
async function validateUserIds(ids) {
  if (!Array.isArray(ids)) {
    return false;
  }

  const uniqueIds = [...new Set(ids.map(String))];

  if (uniqueIds.some((id) => !isValidId(id))) {
    return false;
  }

  const count = await User.countDocuments({
    _id: { $in: uniqueIds },
  });

  return count === uniqueIds.length;
}

// Lấy danh sách ID người được giao
function getAssignedIds(task) {
  const ids = (task.assignedUsers || []).map(getUserId).filter(Boolean);

  if (task.assignedTo) {
    const assignedToId = getUserId(task.assignedTo);

    if (assignedToId && !ids.includes(assignedToId)) {
      ids.push(assignedToId);
    }
  }

  if (task.primaryAssignee) {
    const primaryId = getUserId(task.primaryAssignee);

    if (primaryId && !ids.includes(primaryId)) {
      ids.push(primaryId);
    }
  }

  return [...new Set(ids)];
}

// Kiểm tra người dùng có phải Editor được chia sẻ không
function isTaskEditor(task, userId) {
  return (task.sharedWith || []).some((item) => {
    return (
      getUserId(item.user) === userId.toString() && item.permission === "editor"
    );
  });
}

// Kiểm tra quyền chia sẻ hợp lệ
function validateSharedPermissions(sharedList) {
  if (!Array.isArray(sharedList)) {
    return false;
  }

  return sharedList.every((item) => {
    return (
      item.user &&
      isValidId(item.user) &&
      ["viewer", "editor"].includes(item.permission)
    );
  });
}

// =====================================================
// LẤY DANH SÁCH NGƯỜI DÙNG
// =====================================================

exports.getTaskUsers = async (req, res) => {
  try {
    const userId = getCurrentUserId(req);

    const users = await User.find({
      _id: { $ne: userId },
    })
      .select("_id fullName email")
      .sort({ fullName: 1 });

    return res.status(200).json({
      success: true,
      users,
    });
  } catch (error) {
    console.error("Get task users error:", error);

    return res.status(500).json({
      message: "Loi khi lay danh sach nguoi dung.",
    });
  }
};

// =====================================================
// TẠO CÔNG VIỆC
// =====================================================

exports.createTask = async (req, res) => {
  try {
    const userId = getCurrentUserId(req);

    if (!userId) {
      return res.status(401).json({
        message: "Khong xac dinh duoc nguoi dung dang nhap.",
      });
    }

    const {
      title,
      description,
      status,
      priority,
      startDate,
      dueDate,
      assignedTo,
      assignedUsers,
      primaryAssignee,
      sharedWith,
    } = req.body;

    if (!title || typeof title !== "string" || !title.trim()) {
      return res.status(400).json({
        message: "Vui long nhap ten cong viec.",
      });
    }

    const fieldError = validateTaskFields(req.body);

    if (fieldError) {
      return res.status(400).json({
        message: fieldError,
      });
    }

    const dateError = validateDates(startDate, dueDate);

    if (dateError) {
      return res.status(400).json({
        message: dateError,
      });
    }

    // Danh sách người được giao
    const assignedIds = Array.isArray(assignedUsers)
      ? assignedUsers.map(getUserId).filter(Boolean)
      : [];

    if (assignedTo) {
      const assignedToId = getUserId(assignedTo);

      if (assignedToId && !assignedIds.includes(assignedToId)) {
        assignedIds.push(assignedToId);
      }
    }

    const uniqueAssignedIds = [...new Set(assignedIds)];

    // Danh sách chia sẻ
    const normalizedShared = normalizeSharedWith(sharedWith || []);

    if (!normalizedShared) {
      return res.status(400).json({
        message: "Danh sach chia se khong hop le.",
      });
    }

    const sharedIds = normalizedShared.map((item) => item.user);

    if (sharedIds.some((id) => !id)) {
      return res.status(400).json({
        message: "Danh sach chia se khong hop le.",
      });
    }

    if (
      uniqueAssignedIds.includes(userId.toString()) ||
      sharedIds.includes(userId.toString())
    ) {
      return res.status(400).json({
        message: "Khong the giao viec hoac chia se cho chinh minh.",
      });
    }

    if (uniqueAssignedIds.some((id) => sharedIds.includes(id))) {
      return res.status(400).json({
        message: "Mot nguoi khong the vua duoc giao vua duoc chia se.",
      });
    }

    if (
      !(await validateUserIds(uniqueAssignedIds)) ||
      !(await validateUserIds(sharedIds))
    ) {
      return res.status(400).json({
        message: "Nguoi dung khong ton tai hoac ID khong hop le.",
      });
    }

    if (!validateSharedPermissions(normalizedShared)) {
      return res.status(400).json({
        message: "Quyen chia se khong hop le.",
      });
    }

    const selectedPrimary = getUserId(primaryAssignee || assignedTo);

    if (selectedPrimary && !uniqueAssignedIds.includes(selectedPrimary)) {
      return res.status(400).json({
        message:
          "Nguoi chiu trach nhiem phai nam trong danh sach nguoi duoc giao.",
      });
    }

    const task = await Task.create({
      title: title.trim(),
      description: description || "",
      status: status || "todo",
      priority: priority || "medium",
      startDate: startDate || null,
      dueDate: dueDate || null,

      createdBy: userId,

      assignedTo: assignedTo || null,
      assignedUsers: uniqueAssignedIds,

      primaryAssignee: selectedPrimary || null,

      sharedWith: normalizedShared.map((item) => ({
        user: item.user,
        permission: item.permission,
      })),
    });

    const result = await populateTask(Task.findById(task._id));

    return res.status(201).json({
      message: "Tao cong viec thanh cong.",
      task: result,
    });
  } catch (error) {
    console.error("Create task error:", error);

    return res.status(500).json({
      message: "Loi khi tao cong viec.",
      error: error.message,
    });
  }
};

// =====================================================
// LẤY DANH SÁCH CÔNG VIỆC
// PHÂN LOẠI + LỌC + SẮP XẾP + THỐNG KÊ TIẾN ĐỘ
// =====================================================

exports.getTasks = async (req, res) => {
  try {
    const userId = getCurrentUserId(req);

    if (!userId) {
      return res.status(401).json({
        message: "Khong xac dinh duoc nguoi dung dang nhap.",
      });
    }

    const {
      view,
      type,
      search,
      status,
      priority,
      assignee,
      sortBy,
      sort,
      order = "desc",
    } = req.query;

    const selectedView = view || type || "all";

    // -------------------------------------------------
    // 1. PHÂN LOẠI THEO VAI TRÒ
    // -------------------------------------------------

    let roleQuery = {};

    switch (selectedView) {
      // Công việc do người dùng tạo
      case "created":
        roleQuery = {
          createdBy: userId,
        };
        break;

      // Công việc người dùng được giao phụ trách
      case "assigned":
      case "received":
      case "responsible":
        roleQuery = {
          $or: [
            { assignedTo: userId },
            { assignedUsers: userId },
            { primaryAssignee: userId },
          ],
        };
        break;

      // Công việc được người khác chia sẻ
      case "shared":
        roleQuery = {
          "sharedWith.user": userId,
        };
        break;

      // Tất cả công việc có quyền truy cập
      case "all":
      default:
        roleQuery = accessibleQuery(userId);
        break;
    }

    const conditions = [roleQuery];

    // -------------------------------------------------
    // 2. LỌC TRẠNG THÁI
    // -------------------------------------------------

    const allowedStatus = ["todo", "in-progress", "completed"];

    if (status && status !== "all") {
      if (!allowedStatus.includes(status)) {
        return res.status(400).json({
          message: "Trang thai cong viec khong hop le.",
        });
      }

      conditions.push({ status });
    }

    // -------------------------------------------------
    // 3. LỌC ĐỘ ƯU TIÊN
    // -------------------------------------------------

    const allowedPriority = ["low", "medium", "high"];

    if (priority && priority !== "all") {
      if (!allowedPriority.includes(priority)) {
        return res.status(400).json({
          message: "Muc do uu tien khong hop le.",
        });
      }

      conditions.push({ priority });
    }

    // -------------------------------------------------
    // 4. LỌC NGƯỜI PHỤ TRÁCH
    // -------------------------------------------------

    if (assignee && assignee !== "all") {
      if (!isValidId(assignee)) {
        return res.status(400).json({
          message: "ID nguoi phu trach khong hop le.",
        });
      }

      conditions.push({
        $or: [
          { assignedTo: assignee },
          { assignedUsers: assignee },
          { primaryAssignee: assignee },
        ],
      });
    }

    // -------------------------------------------------
    // 5. TÌM KIẾM
    // -------------------------------------------------

    if (search && search.trim()) {
      const safeSearch = search.trim().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

      conditions.push({
        $or: [
          {
            title: {
              $regex: safeSearch,
              $options: "i",
            },
          },
          {
            description: {
              $regex: safeSearch,
              $options: "i",
            },
          },
        ],
      });
    }

    const query = {
      $and: conditions,
    };

    // -------------------------------------------------
    // 6. SẮP XẾP
    // -------------------------------------------------

    let selectedSort = sortBy || sort || "createdAt";

    if (selectedSort === "newest" || selectedSort === "oldest") {
      selectedSort = "createdAt";
    }

    const allowedSortFields = ["createdAt", "dueDate", "priority", "title"];

    if (!allowedSortFields.includes(selectedSort)) {
      selectedSort = "createdAt";
    }

    const sortOrder = order === "asc" ? 1 : -1;

    let tasks;

    if (selectedSort === "priority") {
      const priorityRank = {
        low: 1,
        medium: 2,
        high: 3,
      };

      tasks = await populateTask(Task.find(query));

      tasks.sort((a, b) => {
        const rankA = priorityRank[a.priority] || 0;
        const rankB = priorityRank[b.priority] || 0;

        return (rankA - rankB) * sortOrder;
      });
    } else {
      const sortOption = {
        [selectedSort]: sortOrder,
      };

      tasks = await populateTask(Task.find(query).sort(sortOption));
    }

    // -------------------------------------------------
    // 7. THỐNG KÊ TIẾN ĐỘ
    // -------------------------------------------------

    // Thống kê dựa trên toàn bộ công việc người dùng
    // có quyền truy cập, không phụ thuộc bộ lọc hiện tại.

    const allAccessibleQuery = accessibleQuery(userId);

    const [
      totalTasks,
      todoTasks,
      inProgressTasks,
      completedTasks,
      createdCount,
      responsibleCount,
      sharedCount,
    ] = await Promise.all([
      Task.countDocuments(allAccessibleQuery),

      Task.countDocuments({
        $and: [allAccessibleQuery, { status: "todo" }],
      }),

      Task.countDocuments({
        $and: [allAccessibleQuery, { status: "in-progress" }],
      }),

      Task.countDocuments({
        $and: [allAccessibleQuery, { status: "completed" }],
      }),

      Task.countDocuments({
        createdBy: userId,
      }),

      Task.countDocuments({
        $or: [
          { assignedTo: userId },
          { assignedUsers: userId },
          { primaryAssignee: userId },
        ],
      }),

      Task.countDocuments({
        "sharedWith.user": userId,
      }),
    ]);

    const completionRate =
      totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;

    const summary = {
      total: totalTasks,
      todo: todoTasks,
      inProgress: inProgressTasks,
      completed: completedTasks,
      completionRate,

      created: createdCount,
      responsible: responsibleCount,
      shared: sharedCount,
    };

    // -------------------------------------------------
    // 8. TRẢ KẾT QUẢ
    // -------------------------------------------------

    return res.status(200).json({
      success: true,
      count: tasks.length,
      tasks,
      summary,
    });
  } catch (error) {
    console.error("Get tasks error:", error);

    return res.status(500).json({
      message: "Loi khi lay danh sach cong viec.",
      error: error.message,
    });
  }
};

// =====================================================
// XEM CHI TIẾT CÔNG VIỆC
// =====================================================

exports.getTaskById = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getCurrentUserId(req);

    if (!userId) {
      return res.status(401).json({
        message: "Khong xac dinh duoc nguoi dung dang nhap.",
      });
    }

    if (!isValidId(id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    const task = await populateTask(
      Task.findOne({
        _id: id,
        ...accessibleQuery(userId),
      }),
    );

    if (!task) {
      return res.status(404).json({
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
      message: "Loi khi lay chi tiet cong viec.",
      error: error.message,
    });
  }
};

// =====================================================
// CẬP NHẬT CÔNG VIỆC
//
// OWNER: Sửa nội dung, phân công, chia sẻ
// EDITOR: Chỉ sửa nội dung
// ASSIGNEE: Chỉ cập nhật trạng thái
// VIEWER: Chỉ được xem
// =====================================================

exports.updateTask = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getCurrentUserId(req);

    console.log("\n========== UPDATE TASK ==========");
    console.log("TASK ID:", id);
    console.log("USER ID:", userId);
    console.log("REQUEST BODY:", JSON.stringify(req.body, null, 2));

    if (!userId) {
      return res.status(401).json({
        message: "Khong xac dinh duoc nguoi dung dang nhap.",
      });
    }

    if (!isValidId(id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    const task = await Task.findById(id);

    console.log("TASK FOUND:", task ? "YES" : "NO");

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    const currentUserId = userId.toString();
    const ownerId = getUserId(task.createdBy);

    const isOwner = ownerId === currentUserId;

    const assignedIds = getAssignedIds(task);
    const isAssignee = assignedIds.includes(currentUserId);

    const sharedEntry = (task.sharedWith || []).find(
      (item) => getUserId(item.user) === currentUserId,
    );

    const isEditor = sharedEntry?.permission === "editor";
    const isViewer = sharedEntry?.permission === "viewer";

    console.log("IS OWNER:", isOwner);
    console.log("IS ASSIGNEE:", isAssignee);
    console.log("IS EDITOR:", isEditor);
    console.log("IS VIEWER:", isViewer);

    if (!isOwner && !isAssignee && !isEditor && !isViewer) {
      return res.status(403).json({
        message: "Ban khong co quyen truy cap cong viec nay.",
      });
    }

    if (isViewer && !isOwner && !isAssignee && !isEditor) {
      return res.status(403).json({
        message: "Ban chi co quyen xem cong viec.",
      });
    }

    const body = req.body;
    const update = {};

    const canEditContent = isOwner || isEditor;
    const canManageAccess = isOwner;

    // -------------------------------------------------
    // 1. SỬA NỘI DUNG CÔNG VIỆC
    // -------------------------------------------------

    if (canEditContent) {
      const allowedFields = [
        "title",
        "description",
        "status",
        "priority",
        "startDate",
        "dueDate",
      ];

      for (const field of allowedFields) {
        if (body[field] !== undefined) {
          update[field] = body[field];
        }
      }

      if (update.title !== undefined) {
        if (typeof update.title !== "string" || !update.title.trim()) {
          return res.status(400).json({
            message: "Ten cong viec khong duoc de trong.",
          });
        }

        update.title = update.title.trim();
      }

      const fieldError = validateTaskFields(body);

      if (fieldError) {
        return res.status(400).json({
          message: fieldError,
        });
      }

      const dateError = validateDates(
        update.startDate !== undefined ? update.startDate : task.startDate,
        update.dueDate !== undefined ? update.dueDate : task.dueDate,
      );

      if (dateError) {
        return res.status(400).json({
          message: dateError,
        });
      }
    } else if (isAssignee) {
      if (body.status === undefined) {
        return res.status(403).json({
          message: "Nguoi duoc giao chi co the cap nhat trang thai.",
        });
      }

      if (!["todo", "in-progress", "completed"].includes(body.status)) {
        return res.status(400).json({
          message: "Trang thai cong viec khong hop le.",
        });
      }

      update.status = body.status;
    }

    // -------------------------------------------------
    // 2. CHỈ OWNER QUẢN LÝ NGƯỜI ĐƯỢC GIAO
    // -------------------------------------------------

    let nextAssignedIds = getAssignedIds(task);

    if (canManageAccess) {
      if (body.assignedUsers !== undefined) {
        if (!Array.isArray(body.assignedUsers)) {
          return res.status(400).json({
            message: "Danh sach nguoi duoc giao khong hop le.",
          });
        }

        nextAssignedIds = body.assignedUsers.map(getUserId).filter(Boolean);
      }

      if (body.assignedTo !== undefined) {
        const assignedToId = getUserId(body.assignedTo);

        update.assignedTo = assignedToId || null;

        if (assignedToId && !nextAssignedIds.includes(assignedToId)) {
          nextAssignedIds.push(assignedToId);
        }
      } else if (body.assignedUsers !== undefined) {
        const oldAssignedTo = getUserId(task.assignedTo);

        update.assignedTo =
          oldAssignedTo && nextAssignedIds.includes(oldAssignedTo)
            ? oldAssignedTo
            : nextAssignedIds[0] || null;
      }

      nextAssignedIds = [...new Set(nextAssignedIds)];

      if (!(await validateUserIds(nextAssignedIds))) {
        return res.status(400).json({
          message: "Nguoi duoc giao khong ton tai hoac ID khong hop le.",
        });
      }

      if (nextAssignedIds.includes(currentUserId)) {
        return res.status(400).json({
          message: "Khong the giao viec cho chinh minh.",
        });
      }

      if (body.assignedUsers !== undefined || body.assignedTo !== undefined) {
        update.assignedUsers = nextAssignedIds;
      }

      if (body.primaryAssignee !== undefined) {
        const primaryId = getUserId(body.primaryAssignee);

        if (primaryId && !isValidId(primaryId)) {
          return res.status(400).json({
            message: "Nguoi chiu trach nhiem khong hop le.",
          });
        }

        if (primaryId && !nextAssignedIds.includes(primaryId)) {
          return res.status(400).json({
            message:
              "Nguoi chiu trach nhiem phai nam trong danh sach nguoi duoc giao.",
          });
        }

        update.primaryAssignee = primaryId || null;
      } else if (
        task.primaryAssignee &&
        !nextAssignedIds.includes(getUserId(task.primaryAssignee))
      ) {
        update.primaryAssignee = null;
      }
    }

    // -------------------------------------------------
    // 3. CHỈ OWNER QUẢN LÝ DANH SÁCH CHIA SẺ
    // -------------------------------------------------

    if (canManageAccess && body.sharedWith !== undefined) {
      const normalizedShared = normalizeSharedWith(body.sharedWith);

      if (!normalizedShared) {
        return res.status(400).json({
          message: "Danh sach chia se khong hop le.",
        });
      }

      const oldPermissions = new Map(
        (task.sharedWith || []).map((item) => [
          getUserId(item.user),
          item.permission,
        ]),
      );

      for (let i = 0; i < normalizedShared.length; i++) {
        const originalItem = body.sharedWith[i];
        const item = normalizedShared[i];

        if (typeof originalItem === "string") {
          item.permission = oldPermissions.get(item.user) || "viewer";
        } else if (!originalItem.permission) {
          item.permission = oldPermissions.get(item.user) || "viewer";
        }
      }

      if (!validateSharedPermissions(normalizedShared)) {
        return res.status(400).json({
          message: "Quyen chia se hoac ID nguoi dung khong hop le.",
        });
      }

      const sharedIds = normalizedShared.map((item) => item.user);

      if (sharedIds.includes(currentUserId)) {
        return res.status(400).json({
          message: "Khong the chia se cong viec cho chinh minh.",
        });
      }

      if (sharedIds.some((sharedId) => nextAssignedIds.includes(sharedId))) {
        return res.status(400).json({
          message: "Mot nguoi khong the vua duoc giao vua duoc chia se.",
        });
      }

      if (!(await validateUserIds(sharedIds))) {
        return res.status(400).json({
          message: "Nguoi duoc chia se khong ton tai.",
        });
      }

      task.sharedWith = normalizedShared.map((item) => ({
        user: item.user,
        permission: item.permission,
      }));
    }

    // Editor không được cập nhật danh sách phân công
    // hoặc danh sách chia sẻ.
    Object.assign(task, update);

    await task.save();

    console.log("UPDATE TASK SUCCESS:", task._id.toString());
    console.log("=================================\n");

    const result = await populateTask(Task.findById(task._id));

    return res.status(200).json({
      message: "Cap nhat cong viec thanh cong.",
      task: result,
    });
  } catch (error) {
    console.error("Update task error:", error);

    return res.status(500).json({
      message: "Loi khi cap nhat cong viec.",
      error: error.message,
    });
  }
};

// =====================================================
// CẬP NHẬT QUYỀN TRUY CẬP
// CHỈ OWNER ĐƯỢC QUẢN LÝ PHÂN CÔNG / CHIA SẺ
// =====================================================

exports.updateTaskAccess = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getCurrentUserId(req);

    console.log("\n========== UPDATE TASK ACCESS ==========");
    console.log("TASK ID nhận từ Flutter:", id);
    console.log("USER ID đăng nhập:", userId);
    console.log("REQUEST BODY:", JSON.stringify(req.body, null, 2));

    if (!userId) {
      return res.status(401).json({
        message: "Khong xac dinh duoc nguoi dung dang nhap.",
      });
    }

    if (!isValidId(id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    const task = await Task.findById(id);

    console.log("TASK FOUND:", task ? "YES" : "NO");

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    console.log("TASK ID trong MongoDB:", task._id.toString());
    console.log("TASK OWNER:", getUserId(task.createdBy));

    const currentUserId = userId.toString();
    const ownerId = getUserId(task.createdBy);

    const isOwner = ownerId === currentUserId;

    console.log("IS OWNER:", isOwner);

    if (!isOwner) {
      return res.status(403).json({
        message: "Chi chu so huu moi duoc quan ly quyen truy cap.",
      });
    }

    const { assignedUsers, primaryAssignee, sharedWith } = req.body;

    let assignedIds = getAssignedIds(task);

    // -------------------------------------------------
    // 1. DANH SÁCH NGƯỜI ĐƯỢC GIAO
    // -------------------------------------------------

    if (assignedUsers !== undefined) {
      if (!Array.isArray(assignedUsers)) {
        return res.status(400).json({
          message: "Danh sach nguoi duoc giao khong hop le.",
        });
      }

      assignedIds = assignedUsers.map(getUserId).filter(Boolean);

      assignedIds = [...new Set(assignedIds)];

      if (!(await validateUserIds(assignedIds))) {
        return res.status(400).json({
          message: "Danh sach nguoi duoc giao khong hop le.",
        });
      }
    }

    if (assignedIds.includes(currentUserId)) {
      return res.status(400).json({
        message: "Khong the giao viec cho chinh minh.",
      });
    }

    // -------------------------------------------------
    // 2. DANH SÁCH CHIA SẺ
    // -------------------------------------------------

    let normalizedShared = (task.sharedWith || []).map((item) => ({
      user: getUserId(item.user),
      permission: item.permission || "viewer",
    }));

    if (sharedWith !== undefined) {
      normalizedShared = normalizeSharedWith(sharedWith);

      if (!normalizedShared) {
        return res.status(400).json({
          message: "Danh sach chia se khong hop le.",
        });
      }

      const oldPermissions = new Map(
        (task.sharedWith || []).map((item) => [
          getUserId(item.user),
          item.permission,
        ]),
      );

      for (let i = 0; i < normalizedShared.length; i++) {
        const originalItem = sharedWith[i];
        const item = normalizedShared[i];

        if (typeof originalItem === "string") {
          item.permission = oldPermissions.get(item.user) || "viewer";
        } else if (!originalItem.permission) {
          item.permission = oldPermissions.get(item.user) || "viewer";
        }
      }
    }

    if (!validateSharedPermissions(normalizedShared)) {
      return res.status(400).json({
        message: "Danh sach chia se khong hop le.",
      });
    }

    const sharedIds = normalizedShared.map((item) => item.user);

    if (sharedIds.includes(currentUserId)) {
      return res.status(400).json({
        message: "Khong the chia se cho chinh minh.",
      });
    }

    if (sharedIds.some((sharedId) => assignedIds.includes(sharedId))) {
      return res.status(400).json({
        message: "Mot nguoi khong the vua duoc giao vua duoc chia se.",
      });
    }

    if (!(await validateUserIds(sharedIds))) {
      return res.status(400).json({
        message: "Nguoi duoc chia se khong ton tai.",
      });
    }

    // -------------------------------------------------
    // 3. NGƯỜI PHỤ TRÁCH CHÍNH
    // -------------------------------------------------

    let nextPrimaryAssignee = getUserId(task.primaryAssignee);

    if (primaryAssignee !== undefined) {
      nextPrimaryAssignee = getUserId(primaryAssignee);
    }

    if (nextPrimaryAssignee && !isValidId(nextPrimaryAssignee)) {
      return res.status(400).json({
        message: "Nguoi chiu trach nhiem khong hop le.",
      });
    }

    if (nextPrimaryAssignee && !assignedIds.includes(nextPrimaryAssignee)) {
      return res.status(400).json({
        message:
          "Nguoi chiu trach nhiem phai nam trong danh sach nguoi duoc giao.",
      });
    }

    // -------------------------------------------------
    // 4. LƯU CẬP NHẬT
    // -------------------------------------------------

    if (assignedUsers !== undefined) {
      task.assignedUsers = assignedIds;

      const oldAssignedTo = getUserId(task.assignedTo);

      if (!oldAssignedTo || !assignedIds.includes(oldAssignedTo)) {
        task.assignedTo = assignedIds[0] || null;
      }
    }

    if (primaryAssignee !== undefined || assignedUsers !== undefined) {
      task.primaryAssignee = nextPrimaryAssignee || null;
    }

    if (sharedWith !== undefined) {
      task.sharedWith = normalizedShared.map((item) => ({
        user: item.user,
        permission: item.permission,
      }));
    }

    await task.save();

    console.log("UPDATE TASK ACCESS SUCCESS:", task._id.toString());
    console.log("========================================\n");

    const result = await populateTask(Task.findById(task._id));

    return res.status(200).json({
      message: "Cap nhat quyen truy cap thanh cong.",
      task: result,
    });
  } catch (error) {
    console.error("Update task access error:", error);

    return res.status(500).json({
      message: "Loi khi cap nhat quyen truy cap.",
      error: error.message,
    });
  }
};

// =====================================================
// XÓA CÔNG VIỆC
// CHỈ OWNER ĐƯỢC XÓA
// =====================================================

exports.deleteTask = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getCurrentUserId(req);

    if (!userId) {
      return res.status(401).json({
        message: "Khong xac dinh duoc nguoi dung dang nhap.",
      });
    }

    if (!isValidId(id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    const task = await Task.findById(id);

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    if (getUserId(task.createdBy) !== userId.toString()) {
      return res.status(403).json({
        message: "Chi chu so huu moi duoc xoa cong viec.",
      });
    }

    await Task.findByIdAndDelete(id);

    return res.status(200).json({
      message: "Xoa cong viec thanh cong.",
    });
  } catch (error) {
    console.error("Delete task error:", error);

    return res.status(500).json({
      message: "Loi khi xoa cong viec.",
      error: error.message,
    });
  }
};
