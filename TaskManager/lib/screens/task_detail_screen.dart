
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import 'task_form_screen.dart';
import 'task_access_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskModel? task;
  bool loading = true;
  String currentUserId = '';

  // Lấy ID từ Map hoặc String
  String _getId(dynamic value) {
    if (value == null) return '';

    if (value is Map) {
      return (value['_id'] ?? value['id'] ?? '').toString();
    }

    return value.toString();
  }

  // Kiểm tra người tạo
  bool get isCreator {
    if (task == null || currentUserId.isEmpty) return false;

    return _getId(task!.createdBy) == currentUserId;
  }

  // Kiểm tra quyền Editor của người được chia sẻ
  bool get isEditor {
    if (task == null || currentUserId.isEmpty) return false;

    return task!.sharedWith.any((entry) {
      final userId = _getId(entry['user']);
      final permission =
          entry['permission']?.toString().toLowerCase();

      return userId == currentUserId && permission == 'editor';
    });
  }

  // Người tạo hoặc Editor được chỉnh sửa
  bool get canEdit => isCreator || isEditor;

  // Chỉ người tạo được quản lý quyền truy cập
  bool get canManageAccess => isCreator;

  Future<void> _manageAccess() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskAccessScreen(taskId: widget.taskId),
      ),
    );

    if (changed == true) {
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await ApiService.getProfile();

      if (!mounted) return;

      setState(() {
        currentUserId =
            (user['_id'] ?? user['id'] ?? '').toString();
      });
    } catch (e) {
      debugPrint('Lỗi lấy thông tin người dùng: $e');
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final json = await ApiService.getTaskById(widget.taskId);

      if (mounted) {
        setState(() {
          task = TaskModel.fromJson(json);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _date(DateTime? d) {
    if (d == null) return 'Chưa thiết lập';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _status(String s) {
    if (s == 'completed') return 'Đã hoàn thành';
    if (s == 'in-progress') return 'Đang thực hiện';
    return 'Chưa thực hiện';
  }

  String _priority(String s) {
    if (s == 'high') return 'Cao';
    if (s == 'low') return 'Thấp';
    return 'Trung bình';
  }

  Future<void> _edit() async {
    final current = task;
    if (current == null || !canEdit) return;

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: current),
      ),
    );

    if (changed == true) {
      _load();
    }
  }

  String _assigneeNames() {
    final names = task!.assignedUsers
        .map((u) => u['fullName']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    return names.isEmpty ? 'Chưa giao' : names.join(', ');
  }

  String _sharedNames() {
    final names = task!.sharedWith.map((entry) {
      final user = entry['user'];

      final name = user is Map
          ? (user['fullName'] ?? '').toString()
          : '';

      final permission =
          entry['permission']?.toString().toLowerCase();

      final role = permission == 'editor' ? 'Editor' : 'Viewer';

      return name.isEmpty ? '' : '$name ($role)';
    }).where((name) => name.isNotEmpty).toList();

    return names.isEmpty ? 'Chưa chia sẻ' : names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          if (!loading && canManageAccess)
            IconButton(
              onPressed: _manageAccess,
              icon: const Icon(Icons.group_add_outlined),
              tooltip: 'Phân công & chia sẻ',
            ),

          if (!loading && canEdit)
            IconButton(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Chỉnh sửa',
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : task == null
              ? const Center(
                  child: Text('Không tìm thấy công việc'),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      task!.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),

                    _item(
                      'Mô tả',
                      task!.description.isEmpty
                          ? 'Không có mô tả'
                          : task!.description,
                      Icons.notes,
                    ),

                    _item(
                      'Trạng thái',
                      _status(task!.status),
                      Icons.flag_outlined,
                    ),

                    _item(
                      'Mức độ ưu tiên',
                      _priority(task!.priority),
                      Icons.priority_high,
                    ),

                    _item(
                      'Ngày bắt đầu',
                      _date(task!.startDate),
                      Icons.event_available,
                    ),

                    _item(
                      'Hạn hoàn thành',
                      _date(task!.dueDate),
                      Icons.calendar_month,
                    ),

                    _item(
                      'Ngày tạo',
                      _date(task!.createdAt),
                      Icons.history,
                    ),

                    _item(
                      'Người tạo',
                      task!.creatorName,
                      Icons.person_outline,
                    ),

                    _item(
                      'Người phụ trách chính',
                      (task!.primaryAssignee?['fullName'] ??
                              task!.assigneeName)
                          .toString()
                          .isEmpty
                          ? 'Chưa chọn'
                          : (task!.primaryAssignee?['fullName'] ??
                                  task!.assigneeName)
                              .toString(),
                      Icons.star_outline,
                    ),

                    _item(
                      'Những người cùng thực hiện',
                      _assigneeNames(),
                      Icons.assignment_ind_outlined,
                    ),

                    _item(
                      'Người được chia sẻ',
                      _sharedNames(),
                      Icons.people_outline,
                    ),
                  ],
                ),
    );
  }

  Widget _item(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF3867F4),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
