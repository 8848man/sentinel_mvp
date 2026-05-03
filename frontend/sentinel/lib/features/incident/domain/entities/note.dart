import 'package:flutter/foundation.dart';

@immutable
class Note {
  const Note({
    required this.id,
    required this.incidentId,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String incidentId;
  final String content;
  final DateTime updatedAt;
}
