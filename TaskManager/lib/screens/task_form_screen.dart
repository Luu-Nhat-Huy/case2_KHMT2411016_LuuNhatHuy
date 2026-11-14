
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

  bool saving = false;
  bool loadingUsers = true;

  List<Map<String, dynamic>> users = [];

  String? assignedTo;
  final Set<String> sharedIds = {};

  // Lấy ID từ cả dạng ObjectId String và Map đã populate.
  String? _getUserId(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      final id = value['_id'] ?? value['id'];
      return id?.toString();
    }

    return value.toString();
  }

  // Lấy tất cả người được giao, tránh trùng với người được chia sẻ.
  Set<String> _getAssignedIds() {
    final ids = <String>{};

    final primaryId = _getUserId(widget.task?.assignedTo);
    if (primaryId != null && primaryId.isNotEmpty) {
      ids.add(primaryId);
    }

    final taskAssignedUsers = widget.task?.assignedUsers ?? [];
    for (final user in taskAssignedUsers) {
      final id = _getUserId(user);
      if (id != null && id.isNotEmpty) {
        ids.add(id);
      }
    }

    final currentAssignedId = assignedTo;
    if (currentAssignedId != null && currentAssignedId.isNotEmpty) {
      ids.add(currentAssignedId);
    }

    return ids;
  }

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

    assignedTo = _getUserId(t?.assignedTo);

    // Nạp danh sách người đã được chia sẻ trước đó.
    for (final item in t?.sharedWith ?? <Map<String, dynamic>>[]) {
      final id = _getUserId(item['user'] ?? item['userId']);

      if (id != null && id.isNotEmpty) {
        sharedIds.add(id);
      }
    }

    // Không đưa người được giao vào danh sách chia sẻ.
    sharedIds.removeAll(_getAssignedIds());

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

        if (assignedTo != null &&
            !users.any((u) => _getUserId(u) == assignedTo)) {
          assignedTo = null;
        }

        // Loại các ID không còn tồn tại trong danh sách người dùng.
        final validIds = users
            .map(_getUserId)
            .whereType<String>()
            .toSet();

        sharedIds.removeWhere((id) => !validIds.contains(id));

        // Không chia sẻ cho người đang được giao.
        sharedIds.removeAll(_getAssignedIds());
      });
    } catch (e) {
      if (mounted) {
        setState(() => loadingUsers = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tải được danh sách người dùng: $e'),
          ),
        );
      }
    }
  }

  String _dateOnly(DateTime? date) {
    if (date == null) return '';

    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
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

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          dueDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (startDate != null &&
        dueDate != null &&
        startDate!.isAfter(dueDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ngày bắt đầu không được sau hạn hoàn thành'),
        ),
      );
      return;
    }

    // Lấy lại danh sách người được giao để loại khỏi danh sách chia sẻ.
    final assignedIds = _getAssignedIds();

    // Chỉ giữ những người được tick và không phải người được giao.
    final sharedUserIds = sharedIds
        .where((id) => id.isNotEmpty && !assignedIds.contains(id))
        .toSet()
        .toList();

    setState(() => saving = true);

    final payload = <String, dynamic>{
      'title': title.text.trim(),
      'description': description.text.trim(),
      'status': status,
      'priority': priority,
      'startDate': startDate == null ? null : _dateOnly(startDate),
      'dueDate': dueDate == null ? null : _dateOnly(dueDate),

      // Luôn gửi người được giao khi tạo hoặc chỉnh sửa.
      'assignedTo': assignedTo,

      // Nếu không tick ai, giá trị gửi lên sẽ là [].
      'sharedWith': sharedUserIds,
    };

    debugPrint('===== TASK SAVE =====');
    debugPrint('assignedTo: $assignedTo');
    debugPrint('assignedIds: $assignedIds');
    debugPrint('sharedIds đang chọn: $sharedIds');
    debugPrint('sharedWith gửi Backend: $sharedUserIds');

    try {
      if (widget.task == null) {
        await ApiService.createTask(payload);
      } else {
        await ApiService.updateTask(widget.task!.id, payload);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.task == null
                ? 'Đã tạo công việc'
                : 'Đã cập nhật công việc và quyền chia sẻ',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  String _userLabel(Map<String, dynamic> user) {
    return '${user['fullName'] ?? 'Không tên'} (${user['email'] ?? ''})';
  }

  @override
  Widget build(BuildContext context) {
    final assignedIds = _getAssignedIds();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.task == null ? 'Thêm công việc' : 'Chỉnh sửa công việc',
        ),
        backgroundColor: const Color(0xFFF5F7FC),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Tên công việc',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: title,
              decoration: const InputDecoration(
                hintText: 'Nhập tên công việc',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Vui lòng nhập tên công việc'
                  : null,
            ),
            const SizedBox(height: 18),

            const Text(
              'Mô tả',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Nhập mô tả chi tiết...',
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Trạng thái',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: status,
              items: const [
                DropdownMenuItem(value: 'todo', child: Text('Chưa thực hiện')),
                DropdownMenuItem(
                  value: 'in-progress',
                  child: Text('Đang thực hiện'),
                ),
                DropdownMenuItem(
                  value: 'completed',
                  child: Text('Đã hoàn thành'),
                ),
              ],
              onChanged: (v) {
                setState(() => status = v ?? status);
              },
            ),
            const SizedBox(height: 18),

            const Text(
              'Mức độ ưu tiên',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: priority,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Thấp')),
                DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                DropdownMenuItem(value: 'high', child: Text('Cao')),
              ],
              onChanged: (v) {
                setState(() => priority = v ?? priority);
              },
            ),
            const SizedBox(height: 18),

            const Text(
              'Ngày bắt đầu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(isStart: true),
              icon: const Icon(Icons.event_available),
              label: Text(
                startDate == null ? 'Chọn ngày bắt đầu' : _dateOnly(startDate),
              ),
            ),
            if (startDate != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => startDate = null),
                  child: const Text('Xóa ngày bắt đầu'),
                ),
              ),
            const SizedBox(height: 10),

            const Text(
              'Hạn hoàn thành',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(isStart: false),
              icon: const Icon(Icons.calendar_month),
              label: Text(
                dueDate == null ? 'Chọn hạn hoàn thành' : _dateOnly(dueDate),
              ),
            ),
            if (dueDate != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => dueDate = null),
                  child: const Text('Xóa hạn hoàn thành'),
                ),
              ),

            const Divider(height: 32),

            const Text(
              'Giao công việc cho',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            if (loadingUsers)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String>(
                value: assignedTo,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Chọn thành viên (không bắt buộc)',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Không giao cho ai'),
                  ),
                  ...users.map(
                        (u) => DropdownMenuItem<String>(
                      value: _getUserId(u),
                      child: Text(
                        _userLabel(u),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    assignedTo = value;

                    if (value != null) {
                      sharedIds.remove(value);
                    }
                  });
                },
              ),

            const SizedBox(height: 20),

            const Text(
              'Chia sẻ công việc với',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Người được chia sẻ có quyền xem công việc.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),

            if (!loadingUsers && users.isEmpty)
              const Text('Chưa có tài khoản người dùng khác.'),

            ...users.where((u) {
              final id = _getUserId(u);
              return id != null && !assignedIds.contains(id);
            }).map((u) {
              final id = _getUserId(u)!;

              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: sharedIds.contains(id),
                title: Text(
                  u['fullName']?.toString() ?? 'Không tên',
                ),
                subtitle: Text(
                  u['email']?.toString() ?? '',
                ),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      sharedIds.add(id);
                    } else {
                      sharedIds.remove(id);
                    }
                  });
                },
              );
            }),

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  saving ? 'Đang lưu...' : 'Lưu công việc',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3867F4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
