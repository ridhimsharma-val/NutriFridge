import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/food_image/food_image_model.dart';
import '../../services/food_image/food_image_service.dart';

/// Reusable bottom sheet for browsing candidate photos and changing entity image.
class FoodImagePickerSheet extends StatefulWidget {
  final String entityName;
  final FoodEntityType entityType;
  final String? category;

  const FoodImagePickerSheet({
    super.key,
    required this.entityName,
    required this.entityType,
    this.category,
  });

  static Future<FoodImageModel?> show(
    BuildContext context, {
    required String entityName,
    required FoodEntityType entityType,
    String? category,
  }) {
    return showModalBottomSheet<FoodImageModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodImagePickerSheet(
        entityName: entityName,
        entityType: entityType,
        category: category,
      ),
    );
  }

  @override
  State<FoodImagePickerSheet> createState() => _FoodImagePickerSheetState();
}

class _FoodImagePickerSheetState extends State<FoodImagePickerSheet> {
  late final TextEditingController _searchController;
  bool _isLoading = false;
  String? _errorMessage;
  List<FoodImageCandidate> _candidates = [];
  FoodImageCandidate? _selectedCandidate;
  bool _hasOverride = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.entityName);
    _hasOverride = FoodImageService.instance.hasUserOverride(
      name: widget.entityName,
      type: widget.entityType,
    );
    _performSearch(widget.entityName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await FoodImageService.instance.searchCandidates(
        query: cleanQuery,
        type: widget.entityType,
        perPage: 10,
      );

      if (mounted) {
        setState(() {
          _candidates = results;
          _isLoading = false;
          if (results.isEmpty) {
            _errorMessage = 'No photographs found for "$cleanQuery". Try a simpler keyword.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to search images. Please check your connection.';
        });
      }
    }
  }

  Future<void> _applySelection() async {
    if (_selectedCandidate == null) return;

    setState(() => _isLoading = true);
    try {
      final result = await FoodImageService.instance.setUserOverride(
        name: widget.entityName,
        type: widget.entityType,
        candidate: _selectedCandidate!,
      );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to save photo selection.';
        });
      }
    }
  }

  Future<void> _restoreAutomatic() async {
    setState(() => _isLoading = true);
    try {
      final result = await FoodImageService.instance.restoreAutomaticImage(
        name: widget.entityName,
        type: widget.entityType,
        category: widget.category,
      );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to restore automatic photo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: AppColors.warmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Photo',
                      style: AppTypography.greeting.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutralCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.entityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.neutralCharcoal),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search input
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder, width: 1.0),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _performSearch,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralCharcoal,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search real food photography...',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.forestGreen),
                  onPressed: () => _performSearch(_searchController.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Main Candidate Area
          Flexible(
            child: _buildCandidatesContent(),
          ),

          const SizedBox(height: 12),

          // Actions Row
          Row(
            children: [
              if (_hasOverride) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _restoreAutomatic,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.forestGreen,
                      side: const BorderSide(color: AppColors.forestGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      'Restore Auto',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_selectedCandidate == null || _isLoading) ? null : _applySelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.cardBorder,
                    disabledForegroundColor: Colors.black26,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Apply Photo',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Pixabay Attribution
          Center(
            child: Text(
              'Photography provided by Pixabay',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesContent() {
    if (_isLoading && _candidates.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: AppColors.forestGreen),
        ),
      );
    }

    if (_errorMessage != null && _candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_outlined, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: _candidates.length,
      itemBuilder: (context, index) {
        final candidate = _candidates[index];
        final isSelected = _selectedCandidate?.photoId == candidate.photoId;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCandidate = candidate;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.forestGreen : AppColors.cardBorder,
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: AppColors.forestGreen.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                else
                  AppColors.softShadow,
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    candidate.thumbnailUrl.isNotEmpty ? candidate.thumbnailUrl : candidate.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.cardBorder.withValues(alpha: 0.3),
                      child: const Icon(Icons.broken_image_rounded, color: AppColors.textSecondary),
                    ),
                  ),

                  // Subtle gradient bottom scrim with photographer attribution
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Text(
                        candidate.photographerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Selection checkmark badge
                  if (isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.forestGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
