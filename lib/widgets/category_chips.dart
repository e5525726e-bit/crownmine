import 'package:flutter/material.dart';

import '../models/food_category.dart';
import 'press_scale.dart';

/// 橫向可捲動的餐飲種類列（像外送平台）。
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final FoodCategory selected;
  final ValueChanged<FoodCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: FoodCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = FoodCategory.values[i];
          final on = c == selected;
          return PressScale(
            onTap: () => onChanged(c),
            haptic: true,
            scale: 0.95,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? theme.colorScheme.primary : theme.cardTheme.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${c.emoji} ${c.label}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: on ? theme.colorScheme.onPrimary : null,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
