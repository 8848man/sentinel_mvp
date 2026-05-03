import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../di/incident_module.dart';
import '../../../domain/entities/incident.dart';

final incidentDetailProvider = FutureProvider.family<Incident, String>(
  (ref, id) => ref.read(getIncidentDetailUseCaseProvider).call(id),
);
