class TaskModel {
  final String id, title, description, status, priority;
  final DateTime? dueDate;

  const TaskModel({
    required this.id, required this.title, this.description = '',
    this.status = 'todo', this.priority = 'medium', this.dueDate,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Không có tiêu đề').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'todo').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      dueDate: json['dueDate'] == null ? null : DateTime.tryParse(json['dueDate'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title, 'description': description, 'status': status,
    'priority': priority, if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
  };
}
