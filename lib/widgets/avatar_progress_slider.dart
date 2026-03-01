import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/smpl_avatar_service.dart';
import '../utils/constants.dart';

/// Horizontal timeline that lets the user swipe between avatar snapshots.
///
/// Usage:
/// ```dart
/// AvatarProgressSlider(
///   snapshots: _snapshots,
///   selectedIndex: _selectedIndex,
///   onSnapshotSelected: (i) => setState(() => _selectedIndex = i),
/// )
/// ```
class AvatarProgressSlider extends StatefulWidget {
  final List<AvatarSnapshot> snapshots;
  final int selectedIndex;
  final ValueChanged<int> onSnapshotSelected;

  const AvatarProgressSlider({
    super.key,
    required this.snapshots,
    required this.selectedIndex,
    required this.onSnapshotSelected,
  });

  @override
  State<AvatarProgressSlider> createState() => _AvatarProgressSliderState();
}

class _AvatarProgressSliderState extends State<AvatarProgressSlider> {
  late final ScrollController _scrollCtrl;
  static const double _itemWidth = 72.0;
  static const double _itemSpacing = 12.0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(AvatarProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (!_scrollCtrl.hasClients) return;
    final targetOffset = widget.selectedIndex * (_itemWidth + _itemSpacing);
    _scrollCtrl.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.snapshots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.timeline, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Progress Timeline',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.snapshots.length} snapshot${widget.snapshots.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Scrollable date chips ────────────────────────────────────────
        SizedBox(
          height: 72,
          child: ListView.builder(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.snapshots.length,
            itemBuilder: (ctx, i) {
              final snap = widget.snapshots[i];
              final isSelected = i == widget.selectedIndex;
              return _DateChip(
                snapshot: snap,
                isSelected: isSelected,
                width: _itemWidth,
                spacing: _itemSpacing,
                onTap: () => widget.onSnapshotSelected(i),
              );
            },
          ),
        ),

        // ── Delta badge between first and current ────────────────────────
        if (widget.snapshots.length > 1 && widget.selectedIndex > 0)
          _DeltaBadge(
            first: widget.snapshots.first,
            current: widget.snapshots[widget.selectedIndex],
          ),
      ],
    );
  }
}

// ─── Date chip ────────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final AvatarSnapshot snapshot;
  final bool isSelected;
  final double width;
  final double spacing;
  final VoidCallback onTap;

  const _DateChip({
    required this.snapshot,
    required this.isSelected,
    required this.width,
    required this.spacing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(snapshot.date);
    final label = dt != null ? DateFormat('MMM d').format(dt) : snapshot.date;
    final year  = dt != null ? dt.year.toString() : '';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        margin: EdgeInsets.only(right: spacing),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.charcoal,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              year,
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : AppColors.textSecondary.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Delta badge ──────────────────────────────────────────────────────────────

class _DeltaBadge extends StatelessWidget {
  final AvatarSnapshot first;
  final AvatarSnapshot current;

  const _DeltaBadge({required this.first, required this.current});

  @override
  Widget build(BuildContext context) {
    final weightDelta = _delta(current.weight, first.weight);
    final waistDelta  = _delta(current.waist,  first.waist);

    if (weightDelta == null && waistDelta == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Text(
            'Since start:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (weightDelta != null)
            _DeltaItem(label: 'Weight', delta: weightDelta, unit: 'kg'),
          if (waistDelta != null)
            _DeltaItem(label: 'Waist', delta: waistDelta, unit: 'cm'),
        ],
      ),
    );
  }

  double? _delta(double? current, double? first) {
    if (current == null || first == null) return null;
    return current - first;
  }
}

class _DeltaItem extends StatelessWidget {
  final String label;
  final double delta;
  final String unit;

  const _DeltaItem({
    required this.label,
    required this.delta,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = delta > 0;
    final isNeutral  = delta.abs() < 0.1;
    final color = isNeutral
        ? AppColors.textSecondary
        : (isPositive ? Colors.redAccent : Colors.greenAccent);
    final sign = isNeutral ? '' : (isPositive ? '+' : '');

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          '$sign${delta.toStringAsFixed(1)} $unit',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
