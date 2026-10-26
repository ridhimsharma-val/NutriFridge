import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/app_image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'meal_analysis_screen.dart';

/// Screen 1 of the Log Meal feature: Photo capture and plate selection.
class LogMealScreen extends StatefulWidget {
  const LogMealScreen({super.key});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final XFile? file = await AppImagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );

      if (file == null) {
        // User cancelled camera or gallery picker
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final bytes = await file.readAsBytes();

      if (mounted) {
        setState(() {
          _selectedImage = file;
          _imageBytes = bytes;
          _isLoading = false;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (e.code == 'camera_access_denied') {
          _showFeedback('Camera permission was denied. You can enable it in Settings or choose from Gallery.');
        } else if (e.code == 'photo_access_denied') {
          _showFeedback('Photo gallery permission was denied. You can enable it in Settings.');
        } else {
          _showFeedback('Permission needed to access ${source == ImageSource.camera ? 'camera' : 'photos'}.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showFeedback('Could not select photo. Please try again.');
      }
    }
  }

  void _showChangePhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.tealPrimary),
              title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.tealPrimary),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onAnalyzeMeal() {
    if (_imageBytes == null && _selectedImage == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MealAnalysisScreen(
          imageBytes: _imageBytes,
          imageFile: _selectedImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = _imageBytes != null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgGradientTop,
            Color(0xFFF7FAF8),
            AppColors.bgGradientBottom,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: Text(
            'Log Meal',
            style: AppTypography.sectionTitle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle Header
                      Text(
                        "Let's see what you had.",
                        style: AppTypography.greeting.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Take a photo of your plate to estimate its nutrition.',
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Main Photo Area
                      _buildPhotoArea(hasImage),

                      const SizedBox(height: 18),

                      // Camera and Gallery Actions
                      _buildActionButtons(hasImage),

                      const SizedBox(height: 16),

                      // Helpful Note
                      Center(
                        child: Text(
                          'Clear lighting and top-down angles provide the most accurate estimate.',
                          textAlign: TextAlign.center,
                          style: AppTypography.subtitle.copyWith(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom-pinned Primary CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: hasImage ? _onAnalyzeMeal : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealPrimary,
                      disabledBackgroundColor: const Color(0xFFD3DDD7),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFF8B9D94),
                      elevation: hasImage ? 2 : 0,
                      shadowColor: hasImage
                          ? AppColors.tealPrimary.withValues(alpha: 0.35)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Analyze Meal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoArea(bool hasImage) {
    const double areaHeight = 290;

    return Container(
      width: double.infinity,
      height: areaHeight,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasImage ? AppColors.tealPrimary.withValues(alpha: 0.4) : AppColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: const [AppColors.softShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.tealPrimary,
                  strokeWidth: 2.5,
                ),
              )
            : hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      // Selected Photo
                      Image.memory(
                        _imageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),

                      // Change Photo / Retake Pill
                      Positioned(
                        bottom: 14,
                        right: 14,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showChangePhotoOptions,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.refresh_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Change Photo',
                                    style: AppTypography.badgeText.copyWith(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    color: const Color(0xFFF9FBFA),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Subtle camera symbol container
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.tealLight.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 28,
                              color: AppColors.tealPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Capture your meal',
                          style: AppTypography.cardTitle.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Take a photo of your plate to estimate its nutrition.',
                          textAlign: TextAlign.center,
                          style: AppTypography.subtitle.copyWith(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildActionButtons(bool hasImage) {
    return Column(
      children: [
        // Primary: Take Photo
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded, size: 19),
            label: const Text(
              'Take Photo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealPrimary,
              foregroundColor: Colors.white,
              elevation: 1.5,
              shadowColor: AppColors.tealPrimary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Secondary: Choose from Gallery
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 19),
            label: const Text(
              'Choose from Gallery',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.cardWhite,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
