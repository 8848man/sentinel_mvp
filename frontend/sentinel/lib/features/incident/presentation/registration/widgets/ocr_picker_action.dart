import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../design_system/design_system.dart';
import '../providers/ocr_flow_provider.dart';

/// OCR image-acquisition entry point beside the Raw Log field
/// (sdd/context/04_1_ocr_log_extraction.md Platform Entry Points).
///
/// Both actions resolve to a browser file input under the hood on Flutter
/// Web — `ImageSource.camera` sets the `capture` hint (mobile browsers open
/// the camera/gallery chooser directly), `ImageSource.gallery` does not
/// (desktop opens a plain file dialog). Neither relies on a native-only API
/// — both degrade gracefully on platforms/browsers that ignore `capture`.
class OcrPickerAction extends ConsumerWidget {
  const OcrPickerAction({super.key});

  Future<void> _pick(WidgetRef ref, ImageSource source) async {
    final notifier = ref.read(ocrFlowProvider.notifier);
    notifier.startPicking();
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source);
      if (file == null) {
        notifier.cancel(); // user backed out of the chooser — not an error
        return;
      }
      final bytes = await file.readAsBytes();
      await notifier.processImage(bytes, file.name);
    } catch (_) {
      // Camera permission denial surfaces here on browsers that expose a
      // getUserMedia-style prompt for the camera source; gallery/file-input
      // failures land here too — both degrade to the same actionable message
      // (sdd/context/04_1_ocr_log_extraction.md Error Handling Requirements).
      notifier.reportPickerError(
        source == ImageSource.camera
            ? 'Camera access was denied — choose a file instead.'
            : "Couldn't open the file picker. Please try again.",
      );
    }
  }

  Widget _action(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return GestureDetector(
      onTap: () => _pick(ref, source),
      child: Container(
        // ≥44px tap target on every breakpoint, not just mobile — matches
        // the project's existing mobile touch-target convention
        // (10_4_responsive_incident_flow.md ChecklistItemWidget precedent).
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.accentBlue),
            const SizedBox(width: 4),
            Text(label,
                style: AppText.labelSmall.copyWith(color: AppColors.accentBlue)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobileWidth;

    if (isMobile) {
      // Mobile (<768px): camera OR gallery, per Platform Entry Points table.
      return Wrap(
        spacing: AppSpacing.sm,
        children: [
          _action(context, ref,
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              source: ImageSource.camera),
          _action(context, ref,
              icon: Icons.image_outlined,
              label: 'Gallery',
              source: ImageSource.gallery),
        ],
      );
    }

    // Desktop/tablet: file upload only.
    return _action(context, ref,
        icon: Icons.upload_file_outlined,
        label: 'Add Photo',
        source: ImageSource.gallery);
  }
}
