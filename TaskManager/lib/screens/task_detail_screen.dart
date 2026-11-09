import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import 'task_form_screen.dart';

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

  bool get canEdit => task != null && (task!.createdBy?['_id']?.toString() == currentUserId || task!.createdBy?['id']?.toString() == currentUserId);

  @override
  void initState() {
    super.initState();
    _load();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await ApiService.getProfile();
      if (mounted) setState(() => currentUserId = (user['_id'] ?? user['id'] ?? '').toString());
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final json = await ApiService.getTaskById(widget.taskId);
      if (mounted) setState(() => task = TaskModel.fromJson(json));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _date(DateTime? d) => d == null ? 'Chưa thiết lập' : '${d.day}/${d.month}/${d.year}';
  String _status(String s) => s == 'completed' ? 'Đã hoàn thành' : s == 'in-progress' ? 'Đang thực hiện' : 'Chưa thực hiện';
  String _priority(String s) => s == 'high' ? 'Cao' : s == 'low' ? 'Thấp' : 'Trung bình';

  Future<void> _edit() async {
    final current = task;
    if (current == null) return;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TaskFormScreen(task: current)));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          if (canEdit) IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined), tooltip: 'Chỉnh sửa'),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : task == null
              ? const Center(child: Text('Không tìm thấy công việc'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(task!.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 18),
                    _item('Mô tả', task!.description.isEmpty ? 'Không có mô tả' : task!.description, Icons.notes),
                    _item('Trạng thái', _status(task!.status), Icons.flag_outlined),
                    _item('Mức độ ưu tiên', _priority(task!.priority), Icons.priority_high),
                    _item('Ngày bắt đầu', _date(task!.startDate), Icons.event_available),
                    _item('Hạn hoàn thành', _date(task!.dueDate), Icons.calendar_month),
                    _item('Ngày tạo', _date(task!.createdAt), Icons.history),
                    _item('Người tạo', task!.creatorName, Icons.person_outline),
                    _item('Người được giao', task!.assigneeName.isEmpty ? 'Chưa giao' : task!.assigneeName, Icons.assignment_ind_outlined),
                    _item('Chia sẻ', task!.sharedWith.map((entry) { final u = entry['user']; return u is Map ? (u['fullName'] ?? '').toString() : ''; }).where((name) => name.isNotEmpty).join(', ').isEmpty ? 'Chưa chia sẻ' : task!.sharedWith.map((entry) { final u = entry['user']; return u is Map ? (u['fullName'] ?? '').toString() : ''; }).where((name) => name.isNotEmpty).join(', '), Icons.people_outline),
                  ],
                ),
    );
  }

  Widget _item(String label, String value, IconData icon) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF3867F4)),
          title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}
