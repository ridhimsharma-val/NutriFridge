import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/core/config/supabase_config.dart';
import 'package:nutrifridge/core/utils/auth_validators.dart';
import 'package:nutrifridge/screens/auth/auth_gate.dart';
import 'package:nutrifridge/screens/auth/configuration_error_screen.dart';
import 'package:nutrifridge/screens/auth/forgot_password_screen.dart';
import 'package:nutrifridge/screens/auth/login_screen.dart';
import 'package:nutrifridge/screens/auth/reset_password_screen.dart';
import 'package:nutrifridge/screens/auth/signup_screen.dart';
import 'package:nutrifridge/screens/main_navigation_shell.dart';
import 'package:nutrifridge/services/auth/auth_service.dart';

void main() {
  setUp(() {
    AuthService.testAuthenticatedOverride = null;
    AuthGate.testForceUnconfigured = null;
  });

  tearDown(() {
    AuthService.testAuthenticatedOverride = null;
    AuthGate.testForceUnconfigured = null;
  });

  group('AuthValidators Unit Tests', () {
    test('validateEmail handles invalid and valid cases', () {
      expect(AuthValidators.validateEmail(null), 'Email is required.');
      expect(AuthValidators.validateEmail(''), 'Email is required.');
      expect(AuthValidators.validateEmail('   '), 'Email is required.');
      expect(AuthValidators.validateEmail('invalid-email'), 'Please enter a valid email address.');
      expect(AuthValidators.validateEmail('user@'), 'Please enter a valid email address.');
      expect(AuthValidators.validateEmail('user@test'), 'Please enter a valid email address.');
      expect(AuthValidators.validateEmail('user@test.com'), isNull);
      expect(AuthValidators.validateEmail('user.name+tag@sub.domain.co'), isNull);
    });

    test('validatePassword handles length requirements', () {
      expect(AuthValidators.validatePassword(null), 'Password is required.');
      expect(AuthValidators.validatePassword(''), 'Password is required.');
      expect(AuthValidators.validatePassword('short'), 'Password must be at least 8 characters.');
      expect(AuthValidators.validatePassword('1234567'), 'Password must be at least 8 characters.');
      expect(AuthValidators.validatePassword('12345678'), isNull);
      expect(AuthValidators.validatePassword('strongPassword!'), isNull);
    });

    test('validateConfirmPassword handles mismatch and matching', () {
      expect(AuthValidators.validateConfirmPassword(null, 'password123'), 'Please confirm your password.');
      expect(AuthValidators.validateConfirmPassword('', 'password123'), 'Please confirm your password.');
      expect(AuthValidators.validateConfirmPassword('mismatch', 'password123'), 'Passwords do not match.');
      expect(AuthValidators.validateConfirmPassword('password123', 'password123'), isNull);
    });

    test('validateFullName handles minimum length', () {
      expect(AuthValidators.validateFullName(null), 'Full name is required.');
      expect(AuthValidators.validateFullName(''), 'Full name is required.');
      expect(AuthValidators.validateFullName('A'), 'Name must be at least 2 characters.');
      expect(AuthValidators.validateFullName('Jane Doe'), isNull);
    });

    test('validateRequired handles field names', () {
      expect(AuthValidators.validateRequired(null, 'Field'), 'Field is required.');
      expect(AuthValidators.validateRequired('', 'Email'), 'Email is required.');
      expect(AuthValidators.validateRequired('Value', 'Field'), isNull);
    });
  });

  group('AuthService Error Formatting Tests', () {
    test('formatAuthError humanizes known Supabase error messages', () {
      expect(
        AuthService.formatAuthError('Invalid login credentials'),
        'Incorrect email or password. Please check your credentials and try again.',
      );
      expect(
        AuthService.formatAuthError('User already registered'),
        'An account with this email address already exists. Please sign in instead.',
      );
      expect(
        AuthService.formatAuthError('Email not confirmed'),
        'Please verify your email address before signing in. Check your inbox for the confirmation email.',
      );
      expect(
        AuthService.formatAuthError('Password should be at least 6 characters'),
        'Password must be at least 8 characters long.',
      );
      expect(
        AuthService.formatAuthError('Network request failed'),
        'Network connection error. Please check your internet connection.',
      );
      expect(
        AuthService.formatAuthError('Unknown random failure'),
        'Unknown random failure',
      );
    });
  });

  group('SupabaseConfig Tests', () {
    test('configurationError returns informative message when missing keys', () {
      final err = SupabaseConfig.configurationError;
      // When keys are missing or placeholders, configurationError explains required dart-defines
      expect(err, anyOf(isNull, contains('--dart-define-from-file=supabase.dev.json')));
    });
  });

  group('Auth Screens Widget Tests', () {
    testWidgets('LoginScreen renders inputs and validates empty form submission', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign in to your NutriFridge kitchen'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);

      // Tap Sign In with empty fields to trigger validation
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('LoginScreen password visibility toggles on icon click', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('SignupScreen renders inputs and validates passwords', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SignupScreen(),
        ),
      );

      expect(find.text('Create Account'), findsNWidgets(2));
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);

      // Enter mismatched passwords
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'John Doe');
      await tester.enterText(textFields.at(1), 'test@example.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.enterText(textFields.at(3), 'password999');

      await tester.tap(find.text('Create Account').last);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen renders and validates email', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);

      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required.'), findsOneWidget);
    });

    testWidgets('ResetPasswordScreen renders and validates new password input', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(),
        ),
      );

      expect(find.text('Choose New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('ConfigurationErrorScreen renders diagnostic message', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ConfigurationErrorScreen(),
        ),
      );

      expect(find.text('Configuration Required'), findsOneWidget);
      expect(find.byType(ConfigurationErrorScreen), findsOneWidget);
    });
  });

  group('AuthGate Routing & Session Restore Tests', () {
    testWidgets('AuthGate renders LoginScreen when unauthenticated', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService.testAuthenticatedOverride = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthGate(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainNavigationShell), findsNothing);
    });

    testWidgets('AuthGate renders MainNavigationShell when authenticated (restored session)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService.testAuthenticatedOverride = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthGate(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('AuthGate renders ConfigurationErrorScreen when unconfigured', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthGate.testForceUnconfigured = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthGate(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConfigurationErrorScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
