import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_colors.dart';
import 'screens/splash/magic_fridge_splash.dart';
import 'services/recipe/saved_recipes_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for mobile status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase backend client
  await SupabaseManager.initialize();

  // Initialize Saved Recipes repository
  await SavedRecipesService.instance.init();

  runApp(const NutriFridgeApp());
}

class NutriFridgeApp extends StatelessWidget {
  const NutriFridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriFridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.softCream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryForest,
          primary: AppColors.primaryForest,
          secondary: AppColors.freshGreen,
          surface: AppColors.pureWhite,
          brightness: Brightness.light,
        ),
        splashColor: AppColors.paleMint.withValues(alpha: 0.3),
        highlightColor: Colors.transparent,
      ),
      builder: (context, child) {
        // Enforce mobile-first phone screen proportion (e.g. 390x844) on desktop/web while letting mobile fill natively
        return Center(
          child: Container(
            color: const Color(0xFFE4ECE7), // Subtle phone wrapper background on ultra-wide screens
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430, // Fits iPhone 14/15/16 Pro Max and smaller phone form factors
              ),
              child: ClipRect(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      home: const MagicFridgeSplashScreen(),
    );
  }
}
