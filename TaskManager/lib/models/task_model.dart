class TaskModel {
  final String id, title, description, status, priority;
  final DateTime? startDate, dueDate, createdAt;
  final Map<String, dynamic>? createdBy, assignedTo;
  final List<Map<String, dynamic>> sharedWith;

  const TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.status = 'todo',
    this.priority = 'medium',
    this.startDate,
    this.dueDate,
    this.createdAt,
    this.createdBy,
    this.assignedTo,
    this.sharedWith = const [],
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());
    Map<String, dynamic>? parseUser(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final rawShared = json['sharedWith'];
    final shared = rawShared is List
        ? rawShared.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return TaskModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Không có tiêu đề').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'todo').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      startDate: parseDate(json['startDate']),
      dueDate: parseDate(json['dueDate']),
      createdAt: parseDate(json['createdAt']),
      createdBy: parseUser(json['createdBy']),
      assignedTo: parseUser(json['assignedTo']),
      sharedWith: shared,
    );
  }

  String get creatorName => createdBy?['fullName']?.toString() ?? 'Không rõ';
  String get assigneeName => assignedTo?['fullName']?.toString() ?? '';
}
