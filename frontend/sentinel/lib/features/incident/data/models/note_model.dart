import '../../domain/entities/note.dart';

class NoteModel {
  const NoteModel({
    required this.id,
    required this.incidentId,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String incidentId;
  final String content;
  final DateTime updatedAt;

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      incidentId: json['incident_id'] as String,
      content: json['content'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Note toEntity() => Note(
        id: id,
        incidentId: incidentId,
        content: content,
        updatedAt: updatedAt,
      );
}
