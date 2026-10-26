import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Centralized service for image capture (camera) and image selection (gallery).
/// Ensures "Take Photo" always routes to the device camera, and "Choose from Gallery"
/// always routes to the photo gallery.
class AppImagePicker {
  static final ImagePicker _picker = ImagePicker();

  /// Optional test handler for automated testing.
  static Future<XFile?> Function(ImageSource source)? mockHandler;

  /// Captures an image explicitly from the device camera.
  static Future<XFile?> takePhoto({
    double maxWidth = 1600,
    double maxHeight = 1600,
    int imageQuality = 88,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    return pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      preferredCameraDevice: preferredCameraDevice,
    );
  }

  /// Chooses an image explicitly from the device photo gallery.
  static Future<XFile?> chooseFromGallery({
    double maxWidth = 1600,
    double maxHeight = 1600,
    int imageQuality = 88,
  }) async {
    return pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  static final Uint8List sampleMockBytes = Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0,
    0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120,
    156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68,
    174, 66, 96, 130
  ]);

  /// Explicitly picks an image using the provided [source].
  /// Never routes [ImageSource.camera] to gallery or vice versa.
  static Future<XFile?> pickImage({
    required ImageSource source,
    double maxWidth = 1600,
    double maxHeight = 1600,
    int imageQuality = 88,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    if (mockHandler != null) {
      return mockHandler!(source);
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: preferredCameraDevice,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      return file;
    } on MissingPluginException {
      // In headless test environments where platform channels are not registered,
      // provide a fallback memory-backed photo so tests don't crash.
      if (kDebugMode) {
        return XFile.fromData(sampleMockBytes, name: 'test_photo.png');
      }
      rethrow;
    }
  }
}
