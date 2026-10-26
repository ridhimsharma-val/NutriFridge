import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Reusable camera & photo selection preview component
class FoodScanPreview extends StatelessWidget {
  final String? previewImageAsset;
  final Uint8List? previewImageBytes;
  final String modeTitle;
  final String promptText;
  final bool isAnalyzing;
  final String analyzeButtonLabel;
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseGallery;
  final VoidCallback? onAnalyze;

  const FoodScanPreview({
    super.key,
    required this.previewImageAsset,
    this.previewImageBytes,
    this.modeTitle = 'Food Camera',
    this.promptText = 'Position food item in frame',
    this.isAnalyzing = false,
    this.analyzeButtonLabel = 'Analyze Food',
    required this.onTakePhoto,
    required this.onChooseGallery,
    this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Camera / Image Viewfinder Frame
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF14201B),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image or Camera Viewfinder Placeholder
                if (previewImageBytes != null)
                  Image.memory(
                    previewImageBytes!,
                    fit: BoxFit.cover,
                  )
                else if (previewImageAsset != null)
                  Image.asset(
                    previewImageAsset!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.image_not_supported_rounded,
                          color: Colors.white54,
                          size: 48,
                        ),
                      );
                    },
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.2),
                        radius: 0.8,
                        colors: [
                          Color(0xFF263830),
                          Color(0xFF131D18),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white70,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            promptText,
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "Take Photo" or choose from "Gallery"',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Viewfinder Corner Brackets Overlay
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: CustomPaint(
                    painter: _ViewfinderBracketPainter(
                      color: (previewImageBytes != null || previewImageAsset != null)
                          ? AppColors.tealAccent.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),

                // Top Badge indicator
                Positioned(
                  top: 16,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: previewImageAsset != null
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          previewImageAsset != null ? 'Ready to analyze' : modeTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Analyzing Animation Overlay
                if (isAnalyzing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.72),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 52,
                            height: 52,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.tealAccent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Analyzing your food...',
                            style: AppTypography.cardTitle.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildAnalysisStep('Identifying food', true),
                          const SizedBox(height: 6),
                          _buildAnalysisStep('Estimating quantity', true),
                          const SizedBox(height: 6),
                          _buildAnalysisStep('Selecting category', true),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Controls Area at the Bottom
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // If an image is selected, show prominent Analyze CTA button
              if (previewImageAsset != null && !isAnalyzing) ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onAnalyze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealPrimary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: AppColors.tealPrimary.withValues(alpha: 0.4),
                      shape: RoundedRectangle400Border(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          analyzeButtonLabel,
                          style: AppTypography.cardTitle.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Photo capture / selection actions
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Take Photo',
                      onTap: onTakePhoto,
                      isPrimary: previewImageBytes == null && previewImageAsset == null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: onChooseGallery,
                      isPrimary: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisStep(String title, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4ADE80),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: isPrimary ? AppColors.tealPrimary : AppColors.cardWhite,
          foregroundColor: isPrimary ? Colors.white : AppColors.textPrimary,
          side: BorderSide(
            color: isPrimary ? AppColors.tealPrimary : AppColors.cardBorder,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isPrimary ? 2 : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : AppColors.tealPrimary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isPrimary ? Colors.white : AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoundedRectangle400Border extends RoundedRectangleBorder {
  const RoundedRectangle400Border({super.borderRadius});
}

/// Custom painter for camera viewfinder corner brackets
class _ViewfinderBracketPainter extends CustomPainter {
  final Color color;

  const _ViewfinderBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderBracketPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
