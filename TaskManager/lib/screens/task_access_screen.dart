import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TaskAccessScreen extends StatefulWidget {
  final String taskId;
  const TaskAccessScreen({super.key, required this.taskId});

  @override
  State<TaskAccessScreen> createState() => _TaskAccessScreenState();
}

class _TaskAccessScreenState extends State<TaskAccessScreen> {
  bool loading = true, saving = false;
  List<Map<String, dynamic>> users = [];
  Set<String> assigned = {};
  String? primary;
  Map<String, String> sharedPermissions = {};

  String _id(dynamic value) {
    if (value is Map) return (value['_id'] ?? value['id'] ?? '').toString();
    return value?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getTaskUsers(),
        ApiService.getTaskById(widget.taskId),
      ]);
      final userRows = results[0] as List<Map<String, dynamic>>;
      final task = results[1] as Map<String, dynamic>;
      final assignedRows = task['assignedUsers'];
      final assignedIds = assignedRows is List
          ? assignedRows.map(_id).where((x) => x.isNotEmpty).toSet()
          : <String>{};
      if (assignedIds.isEmpty && task['assignedTo'] != null) {
        assignedIds.add(_id(task['assignedTo']));
      }
      final shareRows = task['sharedWith'];
      final permissions = <String, String>{};
      if (shareRows is List) {
        for (final row in shareRows.whereType<Map>()) {
          final id = _id(row['user']);
          if (id.isNotEmpty) permissions[id] = row['permission'] == 'editor' ? 'editor' : 'viewer';
        }
      }
      if (!mounted) return;
      setState(() {
        users = userRows;
        assigned = assignedIds;
        primary = _id(task['primaryAssignee'] ?? task['assignedTo']).isEmpty
            ? null : _id(task['primaryAssignee'] ?? task['assignedTo']);
        if (primary != null) assigned.add(primary!);
        sharedPermissions = permissions;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _save() async {
    if (primary != null && !assigned.contains(primary)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Người phụ trách chính phải nằm trong danh sách được giao.')));
      return;
    }
    if (assigned.any(sharedPermissions.containsKey)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Một người không thể vừa được giao vừa được chia sẻ.')));
      return;
    }
    setState(() => saving = true);
    try {
      await ApiService.updateTaskAccess(
        widget.taskId,
        assignedUsers: assigned.toList(),
        primaryAssignee: primary,
        sharedWith: sharedPermissions.entries.map((e) => {'user': e.key, 'permission': e.value}).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật phân công và quyền truy cập.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _name(Map<String, dynamic> u) => '${u['fullName'] ?? 'Không tên'} (${u['email'] ?? ''})';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phân công & chia sẻ')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('NGƯỜI ĐƯỢC GIAO', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3867F4))),
                const SizedBox(height: 6),
                const Text('Có thể chọn nhiều người cùng thực hiện công việc.'),
                const SizedBox(height: 8),
                ...users.map((u) {
                  final id = _id(u);
                  final checked = assigned.contains(id);
                  return CheckboxListTile(
                    value: checked,
                    contentPadding: EdgeInsets.zero,
                    title: Text(u['fullName']?.toString() ?? 'Không tên'),
                    subtitle: Text(u['email']?.toString() ?? ''),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        assigned.add(id);
                      } else {
                        assigned.remove(id);
                        if (primary == id) primary = null;
                      }
                      sharedPermissions.remove(id);
                    }),
                  );
                }),
                const SizedBox(height: 10),
                const Text('NGƯỜI PHỤ TRÁCH CHÍNH', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3867F4))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: primary,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Chọn người phụ trách chính'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Chưa chọn')),
                    ...users.where((u) => assigned.contains(_id(u))).map((u) =>
                      DropdownMenuItem<String>(value: _id(u), child: Text(_name(u), overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => primary = v),
                ),
                const Divider(height: 32),
                const Text('CHIA SẺ CÔNG VIỆC', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3867F4))),
                const SizedBox(height: 4),
                const Text('Chọn Viewer để chỉ xem hoặc Editor để được chỉnh sửa.'),
                const SizedBox(height: 8),
                ...users.where((u) => !assigned.contains(_id(u))).map((u) {
                  final id = _id(u);
                  final permission = sharedPermissions[id];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u['fullName']?.toString() ?? 'Không tên', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(u['email']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Row(children: [
                          Expanded(child: DropdownButton<String>(
                            isExpanded: true,
                            value: permission,
                            hint: const Text('Không chia sẻ'),
                            items: const [
                              DropdownMenuItem(value: 'viewer', child: Text('Viewer – Chỉ xem')),
                              DropdownMenuItem(value: 'editor', child: Text('Editor – Được chỉnh sửa')),
                            ],
                            onChanged: (v) => setState(() {
                              if (v == null) { sharedPermissions.remove(id); }
                              else { sharedPermissions[id] = v; }
                            }),
                          )),
                          if (permission != null)
                            IconButton(tooltip: 'Thu hồi quyền', onPressed: () => setState(() => sharedPermissions.remove(id)), icon: const Icon(Icons.remove_circle_outline, color: Colors.red)),
                        ]),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                SizedBox(height: 50, child: FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                  label: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                )),
              ],
            ),
    );
  }
}
