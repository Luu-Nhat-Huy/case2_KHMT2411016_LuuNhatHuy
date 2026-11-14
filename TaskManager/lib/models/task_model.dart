
class TaskModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;

  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? createdAt;

  final Map<String, dynamic>? createdBy;
  final Map<String, dynamic>? assignedTo;
  final Map<String, dynamic>? primaryAssignee;

  final List<Map<String, dynamic>> assignedUsers;
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
    this.primaryAssignee,
    this.assignedUsers = const [],
    this.sharedWith = const [],
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null || value.toString().isEmpty) {
        return null;
      }

      return DateTime.tryParse(value.toString());
    }

    Map<String, dynamic>? parseUser(dynamic value) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }

      // Nếu Backend trả về ID dạng String.
      if (value is String && value.isNotEmpty) {
        return {'_id': value};
      }

      return null;
    }

    List<Map<String, dynamic>> parseUserList(dynamic value) {
      if (value is! List) {
        return [];
      }

      return value.map<Map<String, dynamic>>((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }

        if (item is String) {
          return {'_id': item};
        }

        return <String, dynamic>{};
      }).where((item) => item.isNotEmpty).toList();
    }

    final rawAssigned = json['assignedUsers'];
    final assigned = parseUserList(rawAssigned);

    final rawShared = json['sharedWith'];
    final shared = <Map<String, dynamic>>[];

    if (rawShared is List) {
      for (final item in rawShared) {
        if (item is Map) {
          final entry = Map<String, dynamic>.from(item);

          shared.add(entry);
        } else if (item is String) {
          shared.add({
            'user': item,
            'permission': 'viewer',
          });
        }
      }
    }

    final assignedTo = parseUser(json['assignedTo']);

    final primaryAssignee =
        parseUser(json['primaryAssignee']) ?? assignedTo;

    final finalAssignedUsers = assigned.isNotEmpty
        ? assigned
        : (assignedTo == null ? <Map<String, dynamic>>[] : [assignedTo]);

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
      assignedTo: assignedTo,
      primaryAssignee: primaryAssignee,
      assignedUsers: finalAssignedUsers,
      sharedWith: shared,
    );
  }

  String get creatorName {
    return createdBy?['fullName']?.toString() ?? 'Không rõ';
  }

  String get assigneeName {
    return assignedTo?['fullName']?.toString() ?? '';
  }
}
