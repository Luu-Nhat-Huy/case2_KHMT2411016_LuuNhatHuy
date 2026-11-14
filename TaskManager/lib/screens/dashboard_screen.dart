
import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../services/api_service.dart';
import 'task_form_screen.dart';
import 'task_detail_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const DashboardScreen({super.key, required this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final searchController = TextEditingController();

  List<TaskModel> tasks = [];

  bool loading = true;

  String view = 'all';
  String statusFilter = 'all';
  String priorityFilter = 'all';

  String sortBy = 'createdAt';
  String order = 'desc';

  Map<String, dynamic>? user;

  static const Color blue = Color(0xFF3867F4);

  @override
  void initState() {
    super.initState();
    _loadUser();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =====================================================
  // TẢI THÔNG TIN NGƯỜI DÙNG
  // =====================================================

  Future<void> _loadUser() async {
    try {
      final value = await ApiService.getProfile();

      if (mounted) {
        setState(() => user = value);
      }
    } catch (_) {
      try {
        final value = await ApiService.getUser();

        if (mounted) {
          setState(() => user = value);
        }
      } catch (e) {
        if (mounted) {
          _message('Không thể tải thông tin người dùng: $e', error: true);
        }
      }
    }
  }

  // =====================================================
  // TẢI DANH SÁCH CÔNG VIỆC
  // =====================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() => loading = true);

    try {
      final rows = await ApiService.getTasks(
        search: searchController.text,
        status: statusFilter,
        priority: priorityFilter,
        sortBy: sortBy,
        order: order,
        view: view,
      );

      if (!mounted) return;

      setState(() {
        tasks = rows.map((item) => TaskModel.fromJson(item)).toList();
      });
    } catch (e) {
      if (mounted) {
        _message(e.toString(), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor:
        error ? Colors.red.shade700 : const Color(0xFF238A62),
      ),
    );
  }

  // =====================================================
  // MỞ FORM THÊM / CHỈNH SỬA
  // =====================================================

  Future<void> _openForm([TaskModel? task]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: task),
      ),
    );

    if (changed == true) {
      _load();
    }
  }

  // =====================================================
  // XEM CHI TIẾT CÔNG VIỆC
  // =====================================================

  Future<void> _openDetail(TaskModel task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(taskId: task.id),
      ),
    );

    if (mounted) {
      _load();
    }
  }

  // =====================================================
  // KIỂM TRA VAI TRÒ NGƯỜI DÙNG
  // =====================================================

  String _idOf(dynamic value) {
    if (value is Map) {
      return (value['_id'] ?? value['id'] ?? '').toString();
    }

    return value?.toString() ?? '';
  }

  bool _isOwner(TaskModel task) {
    return _idOf(task.createdBy) == _idOf(user);
  }

  bool _isAssignee(TaskModel task) {
    final currentUserId = _idOf(user);

    return _idOf(task.assignedTo) == currentUserId ||
        task.assignedUsers.any(
              (u) => _idOf(u) == currentUserId,
        );
  }

  // =====================================================
  // XÓA CÔNG VIỆC
  // =====================================================

  Future<void> _delete(TaskModel task) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc?'),
        content: Text(
          'Bạn có chắc muốn xóa "${task.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    try {
      await ApiService.deleteTask(task.id);

      _message('Đã xóa công việc');

      _load();
    } catch (e) {
      _message(e.toString(), error: true);
    }
  }

  // =====================================================
  // CẬP NHẬT TRẠNG THÁI
  // =====================================================

  Future<void> _changeStatus(TaskModel task) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Cập nhật trạng thái',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final item in const [
              ('todo', 'Chưa thực hiện'),
              ('in-progress', 'Đang thực hiện'),
              ('completed', 'Đã hoàn thành'),
            ])
              ListTile(
                title: Text(item.$2),
                trailing: task.status == item.$1
                    ? const Icon(Icons.check, color: blue)
                    : null,
                onTap: () => Navigator.pop(ctx, item.$1),
              ),
          ],
        ),
      ),
    );

    if (selected == null || selected == task.status) return;

    try {
      await ApiService.updateTask(
        task.id,
        {'status': selected},
      );

      _message('Đã cập nhật trạng thái');

      _load();
    } catch (e) {
      _message(e.toString(), error: true);
    }
  }

  // =====================================================
  // ĐĂNG XUẤT
  // =====================================================

  Future<void> _logout() async {
    await ApiService.clearSession();
    widget.onLogout();
  }

  // =====================================================
  // HÀM HIỂN THỊ
  // =====================================================

  String _viewLabel(String value) {
    switch (value) {
      case 'created':
        return 'Tôi tạo';

      case 'responsible':
        return 'Tôi phụ trách';

      case 'shared':
        return 'Được chia sẻ';

      default:
        return 'Tất cả';
    }
  }

  bool _isDone(String status) => status == 'completed';

  bool _isPending(String status) => status == 'todo';

  String _statusLabel(String status) {
    if (status == 'completed') {
      return 'Đã hoàn thành';
    }

    if (status == 'in-progress') {
      return 'Đang thực hiện';
    }

    return 'Chưa thực hiện';
  }

  String _priorityLabel(String priority) {
    if (priority == 'high') return 'Cao';
    if (priority == 'low') return 'Thấp';

    return 'Trung bình';
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // =====================================================
  // DASHBOARD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final name = user?['fullName']?.toString() ?? 'Bạn';

    final done = tasks.where((t) => _isDone(t.status)).length;

    final pending = tasks.where((t) => _isPending(t.status)).length;

    final doing = tasks.length - done - pending;

    final completionRate =
    tasks.isEmpty ? 0.0 : done / tasks.length;

    final completionPercent =
    (completionRate * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),

      // APP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FC),
        title: const Text(
          'Task Manager',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Hồ sơ cá nhân',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );

              _loadUser();
            },
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),

      // NÚT THÊM CÔNG VIỆC
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm việc'),
      ),

      // NỘI DUNG
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
          children: [
            // LỜI CHÀO
            Text(
              'Xin chào, $name 👋',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17213A),
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Theo dõi công việc cá nhân và công việc nhóm.',
              style: TextStyle(color: Color(0xFF7A849B)),
            ),

            const SizedBox(height: 18),

            // =================================================
            // TỔNG QUAN VÀ TIẾN ĐỘ
            // =================================================

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF3867F4),
                    Color(0xFF6C8CFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TỔNG QUAN DANH SÁCH ĐANG XEM',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: .5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${tasks.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  Text(
                    _viewLabel(view),
                    style: const TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 18),

                  // THỐNG KÊ TRẠNG THÁI
                  Row(
                    children: [
                      _stat(
                        'Cần làm',
                        pending,
                        Icons.radio_button_unchecked,
                      ),
                      _stat(
                        'Đang làm',
                        doing,
                        Icons.timelapse,
                      ),
                      _stat(
                        'Hoàn thành',
                        done,
                        Icons.check_circle_outline,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // THANH TIẾN ĐỘ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tiến độ hoàn thành',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '$completionPercent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 9),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: completionRate,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(.25),
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    '$done/${tasks.length} công việc đã hoàn thành',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // =================================================
            // PHÂN LOẠI THEO VAI TRÒ
            // =================================================

            const Text(
              'Phân loại công việc',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Lọc công việc theo vai trò của bạn.',
              style: TextStyle(
                color: Color(0xFF8993A7),
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final item in const [
                  ('all', 'Tất cả'),
                  ('created', 'Tôi tạo'),
                  ('responsible', 'Tôi phụ trách'),
                  ('shared', 'Được chia sẻ'),
                ])
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: view == item.$1,
                    onSelected: (_) {
                      setState(() => view = item.$1);
                      _load();
                    },
                    selectedColor: const Color(0xFFDFE7FF),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            // =================================================
            // TÌM KIẾM
            // =================================================

            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên công việc',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {
                    searchController.clear();
                    _load();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // =================================================
            // LỌC TRẠNG THÁI VÀ ƯU TIÊN
            // =================================================

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: statusFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Tất cả'),
                      ),
                      DropdownMenuItem(
                        value: 'todo',
                        child: Text('Chưa làm'),
                      ),
                      DropdownMenuItem(
                        value: 'in-progress',
                        child: Text('Đang làm'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Hoàn thành'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        statusFilter = v ?? 'all';
                      });
                      _load();
                    },
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: priorityFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ưu tiên',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Tất cả'),
                      ),
                      DropdownMenuItem(
                        value: 'low',
                        child: Text('Thấp'),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('Trung bình'),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Text('Cao'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        priorityFilter = v ?? 'all';
                      });
                      _load();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // =================================================
            // SẮP XẾP
            // =================================================

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: sortBy,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sắp xếp theo',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'createdAt',
                        child: Text('Ngày tạo'),
                      ),
                      DropdownMenuItem(
                        value: 'dueDate',
                        child: Text('Hạn hoàn thành'),
                      ),
                      DropdownMenuItem(
                        value: 'priority',
                        child: Text('Mức ưu tiên'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        sortBy = v ?? 'createdAt';
                      });
                      _load();
                    },
                  ),
                ),

                IconButton(
                  tooltip: order == 'desc'
                      ? 'Giảm dần'
                      : 'Tăng dần',
                  onPressed: () {
                    setState(() {
                      order = order == 'desc' ? 'asc' : 'desc';
                    });
                    _load();
                  },
                  icon: Icon(
                    order == 'desc'
                        ? Icons.south
                        : Icons.north,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // =================================================
            // DANH SÁCH CÔNG VIỆC
            // =================================================

            if (loading)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (tasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 42,
                      color: Color(0xFF9AA4B8),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Chưa có công việc nào',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Thử đổi danh sách hoặc tạo công việc mới.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF7A849B),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...tasks.map(_taskCard),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // THẺ THỐNG KÊ
  // =====================================================

  Widget _stat(String label, int value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // THẺ CÔNG VIỆC
  // =====================================================

  Widget _taskCard(TaskModel task) {
    final done = _isDone(task.status);

    final color = done
        ? const Color(0xFF20A779)
        : _isPending(task.status)
        ? const Color(0xFFED9B36)
        : blue;

    final owner = _isOwner(task);
    final assignee = _isAssignee(task);

    return InkWell(
      onTap: () => _openDetail(task),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.025),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 78,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF26314A),
                    ),
                  ),

                  if (task.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        task.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8993A7),
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 7),

                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _tag(
                        _statusLabel(task.status),
                        color,
                      ),

                      _tag(
                        'Ưu tiên: ${_priorityLabel(task.priority)}',
                        const Color(0xFF77839A),
                      ),

                      if (task.dueDate != null)
                        _tag(
                          'Hạn: ${_date(task.dueDate!)}',
                          const Color(0xFF77839A),
                        ),

                      if (task.assigneeName.isNotEmpty)
                        _tag(
                          'Phụ trách: ${task.assigneeName}',
                          blue,
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Người tạo: ${task.creatorName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8993A7),
                    ),
                  ),
                ],
              ),
            ),

            // NGƯỜI PHỤ TRÁCH CÓ THỂ CẬP NHẬT TRẠNG THÁI
            if (assignee && !owner)
              IconButton(
                tooltip: 'Cập nhật trạng thái',
                onPressed: () => _changeStatus(task),
                icon: const Icon(
                  Icons.flag_outlined,
                  color: blue,
                ),
              ),

            // CHỈ NGƯỜI TẠO ĐƯỢC HIỆN MENU SỬA / XÓA
            if (owner)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    _openForm(task);
                  }

                  if (v == 'delete') {
                    _delete(task);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Chỉnh sửa'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // NHÃN CÔNG VIỆC
  // =====================================================

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
