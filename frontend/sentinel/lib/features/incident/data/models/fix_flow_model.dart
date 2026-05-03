import '../../domain/entities/fix_flow.dart';
import 'checklist_item_model.dart';

class FixFlowModel {
  const FixFlowModel({
    required this.id,
    required this.title,
    required this.confidence,
    required this.isAttempted,
    required this.checklistItems,
  });

  final String id;
  final String title;
  final double confidence;
  final bool isAttempted;
  final List<ChecklistItemModel> checklistItems;

  factory FixFlowModel.fromJson(Map<String, dynamic> json) {
    return FixFlowModel(
      id: json['id'] as String,
      title: json['title'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      isAttempted: json['is_attempted'] as bool,
      checklistItems: (json['checklist_items'] as List<dynamic>)
          .map((e) => ChecklistItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  FixFlow toEntity() => FixFlow(
        id: id,
        title: title,
        confidence: confidence,
        isAttempted: isAttempted,
        checklistItems: checklistItems.map((e) => e.toEntity()).toList(),
      );
}
