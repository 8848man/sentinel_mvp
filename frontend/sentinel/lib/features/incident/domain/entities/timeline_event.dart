import 'package:flutter/foundation.dart';

@immutable
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.event,
    required this.occurredAt,
  });

  final String id;
  final String event;
  final DateTime occurredAt;
}
