import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:styleum/services/ai_analysis_service.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/theme/theme.dart';

class ItemDetailScreen extends StatefulWidget {
  final WardrobeItem item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late WardrobeItem _item;
  final WardrobeService _wardrobeService = WardrobeService();

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _item.itemName ?? 'Item Details',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            if (_item.photoUrl != null)
              AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  _item.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.border,
                    child: const Icon(Icons.image_not_supported, size: 64),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Details Section
                  const Text(
                    'DETAILS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to edit',
                    style: TextStyle(fontSize: 11, color: AppColors.slate),
                  ),
                  const SizedBox(height: 12),

                  _buildDetailRow('Category', _item.category.name, 'category'),
                  _buildDetailRow('Color', _item.colorPrimary, 'primary_color'),
                  _buildDetailRow('Style', _item.styleBucket.name, 'style_bucket'),
                  _buildDetailRow('Formality', _item.formality.name, 'formality'),
                  if (_item.eraDetected != null)
                    _buildDetailRow('Era', _item.eraDetected!, 'era_detected'),

                  const SizedBox(height: 24),

                  // Vibes Section
                  if (_item.vibeScores.isNotEmpty) ...[
                    const Text(
                      'VIBES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildVibeChips(),
                    const SizedBox(height: 24),
                  ],

                  // Tags Section
                  if (_item.tags.isNotEmpty) ...[
                    const Text(
                      'Tags',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _item.tags.map((tag) => Chip(
                        label: Text(tag),
                        backgroundColor: AppColors.filterTagBg,
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // AI Description
                  if (_item.denseCaption != null) ...[
                    const Text(
                      'AI Description',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _item.denseCaption!,
                      style: const TextStyle(color: AppColors.textMuted, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, String field) {
    return GestureDetector(
      onTap: () => _showEditSheet(field, label, value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value.replaceAll('_', ' '),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildVibeChips() {
    final sortedVibes = _item.vibeScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortedVibes.take(5).map((entry) {
        return GestureDetector(
          onTap: () => _showVibeConfirmSheet(entry.key, entry.value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              entry.key,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showEditSheet(String field, String label, String currentValue) {
    final controller = TextEditingController(text: currentValue.replaceAll('_', ' '));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit $label', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('AI predicted: $currentValue', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Your correction',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final newValue = controller.text.trim().toLowerCase().replaceAll(' ', '_');
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  if (newValue.isNotEmpty && newValue != currentValue) {
                    await StyleLearningService().editTag(
                      itemId: _item.id,
                      field: field,
                      oldValue: currentValue,
                      newValue: newValue,
                    );
                    if (!mounted) return;
                    navigator.pop();
                    HapticFeedback.mediumImpact();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Thanks! We\'ll remember this.')),
                    );
                    // Return true to indicate changes were made
                    navigator.pop(true);
                  } else {
                    navigator.pop();
                  }
                },
                child: const Text('Save Correction', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVibeConfirmSheet(String vibeName, double score) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Is this $vibeName?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('AI confidence: ${score.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      StyleLearningService().rejectVibe(_item.id, vibeName);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Got it - not $vibeName')),
                      );
                    },
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      StyleLearningService().confirmVibe(_item.id, vibeName);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Confirmed as $vibeName!')),
                      );
                    },
                    child: const Text('Yes', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteItem();
    }
  }

  Future<void> _deleteItem() async {
    HapticFeedback.mediumImpact();
    
    final success = await _wardrobeService.deleteWardrobeItem(
      _item.id,
      _item.photoUrl,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item deleted'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true); // Return true to indicate deletion
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete item. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
