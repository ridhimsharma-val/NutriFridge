import 'package:flutter/material.dart';

/// Exterior finish options for the NutriFridge refrigerator
enum FridgeColorFinish {
  midnightNavy,
  matteBlack,
  pearlWhite,
  sageGreen;

  String get displayName {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return 'Midnight Navy';
      case FridgeColorFinish.matteBlack:
        return 'Matte Black';
      case FridgeColorFinish.pearlWhite:
        return 'Pearl White';
      case FridgeColorFinish.sageGreen:
        return 'Sage Green';
    }
  }

  String get description {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return 'Deep navy blue, matching original finish';
      case FridgeColorFinish.matteBlack:
        return 'Premium graphite-black finish';
      case FridgeColorFinish.pearlWhite:
        return 'Soft warm-white appliance finish';
      case FridgeColorFinish.sageGreen:
        return 'Muted sage green, coordinated with NutriFridge';
    }
  }

  Color get swatchColor {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF1D2737);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF1F2124);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFFF3F1EC);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF5D7B6E);
    }
  }

  bool get isLight => this == FridgeColorFinish.pearlWhite;

  List<Color> get bodyGradient {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const [
          Color(0xFF263448), // Top-left specular sheen
          Color(0xFF1D2737), // Midnight body
          Color(0xFF141C28), // Deep shadow navy
        ];
      case FridgeColorFinish.matteBlack:
        return const [
          Color(0xFF2D3035),
          Color(0xFF1F2124),
          Color(0xFF141517),
        ];
      case FridgeColorFinish.pearlWhite:
        return const [
          Color(0xFFFFFFFF),
          Color(0xFFF3F1EC),
          Color(0xFFE5E2D9),
        ];
      case FridgeColorFinish.sageGreen:
        return const [
          Color(0xFF78978A),
          Color(0xFF5D7B6E),
          Color(0xFF456054),
        ];
    }
  }

  Color get borderColor {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF384A62);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF3E4148);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFFD4CFC2);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF88A99B);
    }
  }

  Color get shadowColor {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF090E17);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF050608);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFF252D3A);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF0C1913);
    }
  }

  Color get handleSeamColor {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF0F1520);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF0B0C0D);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFF22262C);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF192A22);
    }
  }

  Color get handleSeamGroove {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF080C12);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF050506);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFF15181C);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF0F1B15);
    }
  }

  Color get hingeColor {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF2B384B);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF26282D);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFF7A838F);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF3B564A);
    }
  }

  Color get hingeBorder {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF485C76);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF42454D);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFF9DA7B4);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF5A7B6C);
    }
  }

  Color get gripIndentationColor {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF0F1520);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF0C0D0E);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFF232830);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF1B2C24);
    }
  }

  Color get gripIndentationBorder {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF35465C);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF303338);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFF565F6E);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF456154);
    }
  }

  Color get levelingFootColor {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF141C28);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF121315);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFF444B54);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF1F3027);
    }
  }

  Color get levelingFootBorder {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return const Color(0xFF4D6076);
      case FridgeColorFinish.matteBlack:
        return const Color(0xFF3B3D44);
      case FridgeColorFinish.pearlWhite:
        return const Color(0xFF8E97A4);
      case FridgeColorFinish.sageGreen:
        return const Color(0xFF526E61);
    }
  }

  double get sheenOpacity {
    switch (this) {
      case FridgeColorFinish.midnightNavy:
        return 0.10;
      case FridgeColorFinish.matteBlack:
        return 0.07;
      case FridgeColorFinish.pearlWhite:
        return 0.20;
      case FridgeColorFinish.sageGreen:
        return 0.12;
    }
  }
}

/// Compartment arrangement options
enum FreezerPosition {
  top,
  bottom;

  String get displayName {
    switch (this) {
      case FreezerPosition.top:
        return 'Freezer on Top';
      case FreezerPosition.bottom:
        return 'Freezer on Bottom';
    }
  }

  String get subtitle {
    switch (this) {
      case FreezerPosition.top:
        return 'Freezer above main refrigerator compartment';
      case FreezerPosition.bottom:
        return 'Freezer below main refrigerator compartment';
    }
  }
}

/// Model encapsulating user's Fridge personalization preferences
class FridgePreferences {
  final FridgeColorFinish exteriorColor;
  final FreezerPosition freezerPosition;

  const FridgePreferences({
    this.exteriorColor = FridgeColorFinish.midnightNavy,
    this.freezerPosition = FreezerPosition.top,
  });

  FridgePreferences copyWith({
    FridgeColorFinish? exteriorColor,
    FreezerPosition? freezerPosition,
  }) {
    return FridgePreferences(
      exteriorColor: exteriorColor ?? this.exteriorColor,
      freezerPosition: freezerPosition ?? this.freezerPosition,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FridgePreferences &&
        other.exteriorColor == exteriorColor &&
        other.freezerPosition == freezerPosition;
  }

  @override
  int get hashCode => Object.hash(exteriorColor, freezerPosition);
}

/// Centralized state repository for Fridge personalization preferences
class FridgePreferencesRepository {
  static FridgePreferences _current = const FridgePreferences();

  /// Change notifier for live preference updates across the app
  static final ValueNotifier<FridgePreferences> notifier =
      ValueNotifier<FridgePreferences>(_current);

  /// Currently active Fridge preferences
  static FridgePreferences get current => _current;

  /// Updates and notifies listeners with new preferences
  static void update(FridgePreferences newPreferences) {
    _current = newPreferences;
    notifier.value = _current;
  }

  /// Resets to default settings (Midnight Navy, Freezer on Top)
  static void reset() {
    _current = const FridgePreferences();
    notifier.value = _current;
  }
}
