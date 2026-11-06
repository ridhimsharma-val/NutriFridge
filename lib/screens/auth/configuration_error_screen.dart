import 'package:flutter/material.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Screen displayed when the application is launched without required Supabase credentials.
class ConfigurationErrorScreen extends StatelessWidget {
  const ConfigurationErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final errorMessage = SupabaseConfig.configurationError ??
        'Supabase configuration is missing or invalid.';

    return Scaffold(
      backgroundColor: AppColors.softCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryForest.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.shade200, width: 2),
                      ),
                      child: Icon(
                        Icons.settings_suggest_rounded,
                        color: Colors.amber.shade800,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Configuration Required',
                      style: AppTypography.heading1.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryForest,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage,
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.mutedText,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.softCream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.subtleBorder),
                      ),
                      child: SelectableText(
                        'flutter run --dart-define-from-file=supabase.dev.json',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryForest,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Copy supabase.dev.example.json to supabase.dev.json and fill in your Supabase project credentials.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.mutedText,
                        fontSize: 11.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
