import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../incident/di/incident_module.dart';
import '../../../incident/domain/entities/incident.dart';

class ArchiveNotifier extends AsyncNotifier<List<Incident>> {
  @override
  Future<List<Incident>> build() {
    ref.listen<int>(incidentListStampProvider, (_, __) => reload());
    return _fetch();
  }

  Future<List<Incident>> _fetch() async {
    final useCase = ref.read(getArchiveIncidentsUseCaseProvider);
    return useCase();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final archiveProvider =
    AsyncNotifierProvider<ArchiveNotifier, List<Incident>>(
  ArchiveNotifier.new,
);
