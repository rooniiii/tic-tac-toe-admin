import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Card frame used around each chart.
class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.purple.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Vertical bar chart: one bar per label.
class VerticalBarChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final double height;
  final Color color;

  const VerticalBarChart({
    super.key,
    required this.labels,
    required this.values,
    this.height = 150,
    this.color = AppTheme.neonCyan,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 0 : values.reduce(math.max);

    if (maxValue == 0) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No games in this period.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return SizedBox(
      height: height + 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final fraction = values[i] / maxValue;

          return Expanded(
            child: Tooltip(
              message: '${labels[i]}: ${values[i]} games',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    values[i] == 0 ? '' : '${values[i]}',
                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: math.max(2, height * fraction),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: values[i] == 0
                          ? Colors.white12
                          : color.withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ChartSegment {
  final String label;
  final int value;
  final Color color;

  const ChartSegment(this.label, this.value, this.color);
}

/// One horizontal bar split into coloured parts, with a legend.
class StackedRatioBar extends StatelessWidget {
  final List<ChartSegment> segments;

  const StackedRatioBar({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.value);

    if (total == 0) {
      return const Text(
        'No results yet.',
        style: TextStyle(color: Colors.white54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 22,
            child: Row(
              children: segments
                  .where((s) => s.value > 0)
                  .map(
                    (s) => Expanded(
                      flex: s.value,
                      child: Container(color: s.color),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: segments.map((s) {
            final percent = (s.value / total * 100).toStringAsFixed(1);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${s.label} ${s.value} ($percent%)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Ranked list with a horizontal bar per row.
class HorizontalBarList extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final String unit;
  final Color color;

  const HorizontalBarList({
    super.key,
    required this.labels,
    required this.values,
    this.unit = '',
    this.color = AppTheme.neonPink,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Text(
        'No players yet.',
        style: TextStyle(color: Colors.white54),
      );
    }

    final maxValue = math.max(1, values.reduce(math.max));

    return Column(
      children: List.generate(values.length, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${i + 1}. ${labels[i]}',
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  Text(
                    '${values[i]}$unit',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: values[i] / maxValue,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
