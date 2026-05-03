import 'package:flutter/foundation.dart';
import 'checklist_item.dart';

@immutable
class FixFlow {
  const FixFlow({
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
  final List<ChecklistItem> checklistItems;
}
