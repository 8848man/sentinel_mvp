import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentinel/features/auth/data/providers/auth_repository_provider.dart';
import 'core/router/app_router.dart';
import 'design_system/tokens/colors.dart';

class SentinelApp extends ConsumerWidget {
  const SentinelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.read(authRepositoryProvider).signOut();
    return MaterialApp.router(
      title: 'Sentinel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bgPrimary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentBlue,
          surface: AppColors.bgCard,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
