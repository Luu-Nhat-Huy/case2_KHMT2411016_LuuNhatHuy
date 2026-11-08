import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import 'task_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const DashboardScreen({super.key, required this.onLogout});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<TaskModel> tasks = [];
  bool loading = true;
  String filter = 'Tất cả';
  Map<String, dynamic>? user;

  @override
  void initState() { super.initState(); _load(); _loadUser(); }

  Future<void> _loadUser() async {
    final value = await ApiService.getUser();
    if (mounted) setState(() => user = value);
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final rows = await ApiService.getTasks();
      if (!mounted) return;
      setState(() => tasks = rows.map(TaskModel.fromJson).toList());
    } catch (e) {
      if (mounted) _message(e.toString(), error: true);
    } finally { if (mounted) setState(() => loading = false); }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : const Color(0xFF238A62)));
  }

  Future<void> _openForm([TaskModel? task]) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)));
    if (changed == true) _load();
  }

  Future<void> _delete(TaskModel task) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Xóa công việc?'), content: Text('Bạn có chắc muốn xóa "${task.title}"?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa'))]));
    if (yes != true) return;
    try { await ApiService.deleteTask(task.id); _message('Đã xóa công việc'); _load(); }
    catch (e) { _message(e.toString(), error: true); }
  }

  Future<void> _logout() async {
    await ApiService.clearSession();
    widget.onLogout();
  }

  List<TaskModel> get visibleTasks {
    if (filter == 'Tất cả') return tasks;
    if (filter == 'Hoàn thành') return tasks.where((t) => _isDone(t.status)).toList();
    if (filter == 'Đang làm') return tasks.where((t) => !_isDone(t.status) && !_isPending(t.status)).toList();
    return tasks.where((t) => _isPending(t.status)).toList();
  }

  bool _isDone(String s) => ['completed', 'done', 'complete'].contains(s.toLowerCase());
  bool _isPending(String s) => ['pending', 'todo', 'to do'].contains(s.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final name = user?['fullName']?.toString() ?? 'Bạn';
    final done = tasks.where((t) => _isDone(t.status)).length;
    final pending = tasks.where((t) => _isPending(t.status)).length;
    final doing = tasks.length - done - pending;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FC),
        title: const Text('Task Manager', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(tooltip: 'Tải lại', onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Đăng xuất', onPressed: _logout, icon: const Icon(Icons.logout_rounded)), const SizedBox(width: 6)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(), backgroundColor: const Color(0xFF3867F4),
        foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Thêm việc')),
      body: RefreshIndicator(onRefresh: _load, child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text('Xin chào, $name 👋', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF17213A))),
          const SizedBox(height: 5),
          const Text('Cùng hoàn thành những mục tiêu hôm nay.', style: TextStyle(color: Color(0xFF7A849B))),
          const SizedBox(height: 22),
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3867F4), Color(0xFF6C8CFF)]),
            borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: const Color(0xFF3867F4).withOpacity(.2), blurRadius: 18, offset: const Offset(0, 9))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TỔNG QUAN CÔNG VIỆC', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold)),
              const SizedBox(height: 9),
              Text('${tasks.length}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
              const Text('Công việc của bạn', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              Row(children: [
                _stat('Cần làm', pending, Icons.radio_button_unchecked),
                _stat('Đang làm', doing, Icons.timelapse),
                _stat('Hoàn thành', done, Icons.check_circle_outline),
              ])
            ]),
          ),
          const SizedBox(height: 26),
          const Text('Công việc của tôi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF17213A))),
          const SizedBox(height: 13),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final f in ['Tất cả', 'Cần làm', 'Đang làm', 'Hoàn thành'])
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                label: Text(f), selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
                selectedColor: const Color(0xFFDFE7FF), labelStyle: TextStyle(
                  color: filter == f ? const Color(0xFF3867F4) : const Color(0xFF68738A),
                  fontWeight: FontWeight.w600))),
          ])),
          const SizedBox(height: 10),
          if (loading) const Padding(padding: EdgeInsets.all(35), child: Center(child: CircularProgressIndicator()))
          else if (visibleTasks.isEmpty)
            Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: const Column(children: [Icon(Icons.inbox_outlined, size: 42, color: Color(0xFF9AA4B8)),
                SizedBox(height: 10), Text('Chưa có công việc nào', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4), Text('Nhấn “Thêm việc” để tạo công việc đầu tiên.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7A849B)))]))
          else
            ...visibleTasks.map(_taskCard),
        ],
      )),
    );
  }

  Widget _stat(String label, int value, IconData icon) => Expanded(child: Row(children: [
    Icon(icon, color: Colors.white, size: 17), const SizedBox(width: 6),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ]))
  ]));

  Widget _taskCard(TaskModel task) {
    final done = _isDone(task.status);
    final color = done ? const Color(0xFF20A779) : _isPending(task.status) ? const Color(0xFFED9B36) : const Color(0xFF3867F4);
    return Container(margin: const EdgeInsets.only(bottom: 11), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        Container(width: 4, height: 58, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF26314A))),
          if (task.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8993A7), fontSize: 12))),
          const SizedBox(height: 7),
          Wrap(spacing: 7, children: [
            _tag(_statusLabel(task.status), color),
            _tag('Ưu tiên: ${_priorityLabel(task.priority)}', const Color(0xFF77839A)),
            if (task.dueDate != null) _tag(_date(task.dueDate!), const Color(0xFF77839A)),
          ])
        ])),
        PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _openForm(task); if (v == 'delete') _delete(task); },
          itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
            PopupMenuItem(value: 'delete', child: Text('Xóa'))]),
      ]),
    );
  }

  Widget _tag(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(7)),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)));

  String _statusLabel(String s) {
    if (_isDone(s)) return 'Hoàn thành';
    if (_isPending(s)) return 'Cần làm';
    return 'Đang làm';
  }
  String _priorityLabel(String s) {
    switch (s.toLowerCase()) { case 'high': case 'cao': return 'Cao'; case 'low': case 'thấp': return 'Thấp'; default: return 'Trung bình'; }
  }
  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
