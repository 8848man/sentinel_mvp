import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/features/incident/di/incident_module.dart';
import 'package:sentinel/features/incident/domain/entities/ocr_extraction_result.dart';
import 'package:sentinel/features/incident/domain/repositories/incident_repository.dart';
import 'package:sentinel/features/incident/domain/usecases/extract_log_from_image.dart';
import 'package:sentinel/features/incident/presentation/registration/providers/ocr_flow_provider.dart';

/// Slow fake — never completes until the test resolves [completer], so the
/// 5s/15s message-timer transitions can be observed in isolation from the
/// actual OCR call duration.
class _SlowFakeRepository implements IncidentRepository {
  final completer = Completer<OcrExtractionResult>();

  @override
  Future<OcrExtractionResult> extractLogFromImage(
          Uint8List imageBytes, String filename) =>
      completer.future;

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('OCR processing message advances 0s -> 5s -> 15s on a local timer only',
      (tester) async {
    final repo = _SlowFakeRepository();
    final container = ProviderContainer(overrides: [
      extractLogFromImageUseCaseProvider
          .overrideWithValue(ExtractLogFromImage(repo)),
    ]);
    addTearDown(container.dispose);
    // Keep the autoDispose provider alive for the duration of the test —
    // without an active listener it tears itself down as soon as read().
    final sub = container.listen(ocrFlowProvider, (_, __) {});
    addTearDown(sub.close);

    final notifier = container.read(ocrFlowProvider.notifier);

    // Fire-and-forget: the future never resolves during this test, so we can
    // observe pure timer-driven transitions.
    // ignore: unawaited_futures
    notifier.processImage(Uint8List(0), 'log.png');
    await tester.pump();

    expect(container.read(ocrFlowProvider).stage, OcrFlowStage.uploading);
    expect(container.read(ocrFlowProvider).processingMessage.headline,
        '📷 Extracting text from image...');

    await tester.pump(const Duration(seconds: 5));
    expect(container.read(ocrFlowProvider).processingMessage.headline,
        '📷 Processing screenshot...');

    await tester.pump(const Duration(seconds: 10)); // total 15s
    expect(container.read(ocrFlowProvider).processingMessage.headline,
        '📷 Still processing...');
    expect(container.read(ocrFlowProvider).processingMessage.subtext,
        contains('up to 1 minute'));

    // Resolve the call so the AutoDisposeNotifier's pending timers/futures
    // don't leak past the test.
    repo.completer.complete(const OcrExtractionResult(
      ocrStatus: OcrStatus.ok,
      ocrText: 'x',
      cleanedText: 'x',
      cleanupStatus: OcrCleanupStatus.ok,
      warnings: [],
    ));
    await tester.pump();
  });

  testWidgets(
      'OCR processing message at 360px mobile width does not overflow horizontally',
      (tester) async {
    final repo = _SlowFakeRepository();
    final container = ProviderContainer(overrides: [
      extractLogFromImageUseCaseProvider
          .overrideWithValue(ExtractLogFromImage(repo)),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(ocrFlowProvider, (_, __) {});
    addTearDown(sub.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(360, 800)),
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(builder: (context, ref, _) {
                final state = ref.watch(ocrFlowProvider);
                return SizedBox(
                  width: 360,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 14, height: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(state.processingMessage.headline,
                                softWrap: true),
                            Text(state.processingMessage.subtext,
                                softWrap: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );

    // Trigger processImage from outside the build phase (Riverpod forbids
    // mutating providers during build) and advance through all 3 message
    // stages, asserting no layout overflow at any of them.
    // ignore: unawaited_futures
    container.read(ocrFlowProvider.notifier).processImage(Uint8List(0), 'log.png');
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 10)); // total 15s
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Still processing'), findsOneWidget);

    repo.completer.complete(const OcrExtractionResult(
      ocrStatus: OcrStatus.ok,
      ocrText: 'x',
      cleanedText: 'x',
      cleanupStatus: OcrCleanupStatus.ok,
      warnings: [],
    ));
    await tester.pump();
  });
}
