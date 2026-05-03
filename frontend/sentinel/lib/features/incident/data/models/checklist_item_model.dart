import '../../domain/entities/checklist_item.dart';

class ChecklistItemModel {
  const ChecklistItemModel({
    required this.id,
    required this.stepNumber,
    required this.description,
    required this.isCompleted,
    required this.updatedAt,
  });

  final String id;
  final int stepNumber;
  final String description;
  final bool isCompleted;
  final DateTime updatedAt;

  factory ChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistItemModel(
      id: json['id'] as String,
      stepNumber: json['step_number'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      isCompleted: json['is_completed'] as bool,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  ChecklistItem toEntity() => ChecklistItem(
        id: id,
        stepNumber: stepNumber,
        description: description,
        isCompleted: isCompleted,
        updatedAt: updatedAt,
      );
}
