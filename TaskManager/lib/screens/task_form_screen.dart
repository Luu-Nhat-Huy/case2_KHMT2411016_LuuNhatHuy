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
  DateTime? dueDate;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    title = TextEditingController(text: t?.title ?? '');
    description = TextEditingController(text: t?.description ?? '');
    status = t?.status == 'pending' ? 'todo' : (t?.status ?? 'todo');
    priority = t?.priority ?? 'medium';
    dueDate = t?.dueDate;
  }

  @override
  void dispose() { title.dispose(); description.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: dueDate ?? now,
      firstDate: DateTime(2020), lastDate: DateTime(2100), helpText: 'Chọn hạn hoàn thành');
    if (picked != null) setState(() => dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final payload = <String, dynamic>{
      'title': title.text.trim(),
      'description': description.text.trim(),
      'status': status,
      'priority': priority,
      'dueDate': dueDate?.toIso8601String(),
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
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task == null ? 'Thêm công việc' : 'Chỉnh sửa công việc'),
        backgroundColor: const Color(0xFFF5F7FC)),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Tên công việc', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(controller: title, decoration: const InputDecoration(hintText: 'Ví dụ: Hoàn thành bài tập Flutter'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên công việc' : null),
        const SizedBox(height: 18),
        const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(controller: description, minLines: 3, maxLines: 5,
          decoration: const InputDecoration(hintText: 'Nhập mô tả chi tiết...')),
        const SizedBox(height: 18),
        const Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(),
          items: const [DropdownMenuItem(value: 'todo', child: Text('Cần làm')),
            DropdownMenuItem(value: 'in-progress', child: Text('Đang làm')),
            DropdownMenuItem(value: 'completed', child: Text('Hoàn thành'))],
          onChanged: (v) => setState(() => status = v ?? status)),
        const SizedBox(height: 18),
        const Text('Mức độ ưu tiên', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: priority, decoration: const InputDecoration(),
          items: const [DropdownMenuItem(value: 'low', child: Text('Thấp')),
            DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
            DropdownMenuItem(value: 'high', child: Text('Cao'))],
          onChanged: (v) => setState(() => priority = v ?? priority)),
        const SizedBox(height: 18),
        const Text('Hạn hoàn thành', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month),
          label: Text(dueDate == null ? 'Chọn ngày' : '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), alignment: Alignment.centerLeft)),
        if (dueDate != null) Align(alignment: Alignment.centerLeft, child: TextButton(
          onPressed: () => setState(() => dueDate = null), child: const Text('Xóa hạn hoàn thành'))),
        const SizedBox(height: 28),
        SizedBox(height: 52, child: FilledButton.icon(onPressed: saving ? null : _save,
          icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
          label: Text(saving ? 'Đang lưu...' : 'Lưu công việc'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3867F4)))),
      ])),
    );
  }
}
