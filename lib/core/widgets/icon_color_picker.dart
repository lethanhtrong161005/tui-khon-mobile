import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/category_icons.dart';

/// Colors offered when creating categories and goals.
const List<String> kPaletteColors = [
  '#FF7043', '#EF5350', '#EC407A', '#AB47BC', '#7E57C2', '#5C6BC0',
  '#42A5F5', '#26C6DA', '#26A69A', '#66BB6A', '#9CCC65', '#FFA726',
  '#8D6E63', '#78909C',
];

/// Grid of Material icons from [CategoryIcons]; the selected one is outlined.
class IconPickerGrid extends StatelessWidget {
  const IconPickerGrid({super.key, required this.selected, required this.onChanged, this.color = AppColors.primary});

  final String selected;
  final ValueChanged<String> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in CategoryIcons.names)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChanged(name),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: name == selected ? color.withOpacity(0.15) : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: name == selected ? color : Colors.transparent, width: 2),
              ),
              child: Icon(CategoryIcons.resolve(name), color: name == selected ? color : AppColors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final hex in kPaletteColors)
          GestureDetector(
            onTap: () => onChanged(hex),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorFromHex(hex),
                shape: BoxShape.circle,
                border: Border.all(color: hex == selected ? AppColors.onSurface : Colors.transparent, width: 3),
              ),
              child: hex == selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ),
      ],
    );
  }
}
