import '../../domain/entities/timeline_event.dart';

class TimelineEventModel {
  const TimelineEventModel({
    required this.id,
    required this.event,
    required this.occurredAt,
  });

  final String id;
  final String event;
  final DateTime occurredAt;

  factory TimelineEventModel.fromJson(Map<String, dynamic> json) {
    return TimelineEventModel(
      id: json['id'] as String,
      event: json['event'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
    );
  }

  TimelineEvent toEntity() => TimelineEvent(
        id: id,
        event: event,
        occurredAt: occurredAt,
      );
}
