import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class TaskFormScreen extends StatefulWidget {
  final TaskModel? task;
  const TaskFormScreen({super.key, this.task});
  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late String status, priority;
  DateTime? startDate, dueDate;
  bool saving = false, loadingUsers = true;
  List<Map<String, dynamic>> users = [];
  String? assignedTo;
  final Set<String> sharedIds = {};

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    title = TextEditingController(text: t?.title ?? '');
    description = TextEditingController(text: t?.description ?? '');
    status = t?.status == 'pending' ? 'todo' : (t?.status ?? 'todo');
    priority = t?.priority ?? 'medium';
    startDate = t?.startDate;
    dueDate = t?.dueDate;
    assignedTo = t?.assignedTo?['_id']?.toString();
    for (final item in t?.sharedWith ?? <Map<String, dynamic>>[]) {
      final user = item['user'];
      final id = user is Map ? user['_id']?.toString() : user?.toString();
      if (id != null && id.isNotEmpty) sharedIds.add(id);
    }
    _loadUsers();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final result = await ApiService.getTaskUsers();
      if (!mounted) return;
      setState(() {
        users = result;
        loadingUsers = false;
        if (assignedTo != null && !users.any((u) => u['_id']?.toString() == assignedTo)) assignedTo = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loadingUsers = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tải được danh sách người dùng: $e')));
      }
    }
  }

  String _dateOnly(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? startDate : dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isStart ? 'Chọn ngày bắt đầu' : 'Chọn hạn hoàn thành',
    );
    if (picked != null) setState(() => isStart ? startDate = picked : dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (startDate != null && dueDate != null && startDate!.isAfter(dueDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ngày bắt đầu không được sau hạn hoàn thành')));
      return;
    }
    if (assignedTo != null) sharedIds.remove(assignedTo);
    setState(() => saving = true);
    final payload = <String, dynamic>{
      'title': title.text.trim(),
      'description': description.text.trim(),
      'status': status,
      'priority': priority,
      'startDate': startDate == null ? null : _dateOnly(startDate),
      'dueDate': dueDate == null ? null : _dateOnly(dueDate),
      'assignedTo': assignedTo,
      'sharedWith': sharedIds.toList(),
    };
    try {
      if (widget.task == null) {
        await ApiService.createTask(payload);
      } else {
        await ApiService.updateTask(widget.task!.id, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.task == null ? 'Đã tạo công việc' : 'Đã cập nhật công việc')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _userLabel(Map<String, dynamic> user) => '${user['fullName'] ?? 'Không tên'} (${user['email'] ?? ''})';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task == null ? 'Thêm công việc' : 'Chỉnh sửa công việc'), backgroundColor: const Color(0xFFF5F7FC)),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Tên công việc', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(controller: title, decoration: const InputDecoration(hintText: 'Nhập tên công việc'), validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên công việc' : null),
          const SizedBox(height: 18),
          const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(controller: description, minLines: 3, maxLines: 5, decoration: const InputDecoration(hintText: 'Nhập mô tả chi tiết...')),
          const SizedBox(height: 18),
          const Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: status, items: const [
            DropdownMenuItem(value: 'todo', child: Text('Chưa thực hiện')),
            DropdownMenuItem(value: 'in-progress', child: Text('Đang thực hiện')),
            DropdownMenuItem(value: 'completed', child: Text('Đã hoàn thành')),
          ], onChanged: (v) => setState(() => status = v ?? status)),
          const SizedBox(height: 18),
          const Text('Mức độ ưu tiên', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: priority, items: const [
            DropdownMenuItem(value: 'low', child: Text('Thấp')),
            DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
            DropdownMenuItem(value: 'high', child: Text('Cao')),
          ], onChanged: (v) => setState(() => priority = v ?? priority)),
          const SizedBox(height: 18),
          const Text('Ngày bắt đầu', style: TextStyle(fontWeight: FontWeight.bold)),
          OutlinedButton.icon(onPressed: () => _pickDate(isStart: true), icon: const Icon(Icons.event_available), label: Text(startDate == null ? 'Chọn ngày bắt đầu' : _dateOnly(startDate))),
          if (startDate != null) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setState(() => startDate = null), child: const Text('Xóa ngày bắt đầu'))),
          const SizedBox(height: 10),
          const Text('Hạn hoàn thành', style: TextStyle(fontWeight: FontWeight.bold)),
          OutlinedButton.icon(onPressed: () => _pickDate(isStart: false), icon: const Icon(Icons.calendar_month), label: Text(dueDate == null ? 'Chọn hạn hoàn thành' : _dateOnly(dueDate))),
          if (dueDate != null) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setState(() => dueDate = null), child: const Text('Xóa hạn hoàn thành'))),
          const Divider(height: 32),
          const Text('Giao công việc cho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (loadingUsers) const LinearProgressIndicator()
          else DropdownButtonFormField<String>(
            value: assignedTo,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Chọn thành viên (không bắt buộc)'),
            items: [const DropdownMenuItem<String>(value: null, child: Text('Không giao cho ai')),
              ...users.map((u) => DropdownMenuItem<String>(value: u['_id']?.toString(), child: Text(_userLabel(u), overflow: TextOverflow.ellipsis)))],
            onChanged: (value) => setState(() { assignedTo = value; if (value != null) sharedIds.remove(value); }),
          ),
          const SizedBox(height: 20),
          const Text('Chia sẻ công việc với', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Người được chia sẻ có quyền xem công việc.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          if (!loadingUsers && users.isEmpty) const Text('Chưa có tài khoản người dùng khác.'),
          ...users.where((u) => u['_id']?.toString() != assignedTo).map((u) {
            final id = u['_id']?.toString() ?? '';
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: sharedIds.contains(id),
              title: Text(u['fullName']?.toString() ?? 'Không tên'),
              subtitle: Text(u['email']?.toString() ?? ''),
              onChanged: (checked) => setState(() { if (checked == true) { sharedIds.add(id); } else { sharedIds.remove(id); } }),
            );
          }),
          const SizedBox(height: 24),
          SizedBox(height: 52, child: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Đang lưu...' : 'Lưu công việc'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3867F4)),
          )),
        ]),
      ),
    );
  }
}
