import 'package:flutter/foundation.dart';

@immutable
class ChecklistItem {
  const ChecklistItem({
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
}
