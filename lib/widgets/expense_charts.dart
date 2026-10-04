import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/expense.dart';

/// Interactive + animated pie chart for expense categories.
///
/// Uses CustomPainter to draw the chart.
/// Interaction: tap a slice to select it.
/// Animation: slices animate from 0% to 100% when the widget appears.
class ExpensePieChart extends StatefulWidget {
  final List<Expense> expenses;

  const ExpensePieChart({
    super.key,
    required this.expenses,
  });

  @override
  State<ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<ExpensePieChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant ExpensePieChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.expenses.length != widget.expenses.length) {
      _selectedIndex = null;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ChartItem> get _items {
    final totals = <String, double>{};

    for (final expense in widget.expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }

    final items = totals.entries
        .map(
          (entry) => _ChartItem(
            label: entry.key,
            value: entry.value,
          ),
        )
        .where((item) => item.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return items;
  }

  void _handleTap(
    TapUpDetails details,
    Size size,
  ) {
    final items = _items;
    if (items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final point = details.localPosition;
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final radius = math.min(size.width, size.height) * 0.34;

    // Ignore taps outside the donut.
    if (distance < radius * 0.45 || distance > radius * 1.35) {
      return;
    }

    var angle = math.atan2(dy, dx);
    final startAngle = -math.pi / 2;

    var normalized = angle - startAngle;
    while (normalized < 0) {
      normalized += math.pi * 2;
    }

    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );

    var cursor = 0.0;

    for (var i = 0; i < items.length; i++) {
      final sweep = items[i].value / total * math.pi * 2;

      if (normalized >= cursor && normalized <= cursor + sweep) {
        setState(() {
          _selectedIndex = i;
        });
        return;
      }

      cursor += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    if (items.isEmpty) {
      return const _EmptyChartCard(
        title: 'Spending by Category',
        message: 'Add expenses to see the pie chart.',
      );
    }

    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );

    final selected = _selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < items.length
        ? items[_selectedIndex!]
        : null;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending by Category',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a slice to inspect the category.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chartSize = Size(
                    constraints.maxWidth,
                    240,
                  );

                  return GestureDetector(
                    onTapUp: (details) {
                      _handleTap(details, chartSize);
                    },
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return CustomPaint(
                          size: chartSize,
                          painter: _ExpensePiePainter(
                            items: items,
                            selectedIndex: _selectedIndex,
                            progress: Curves.easeOutCubic.transform(
                              _controller.value,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              _SelectedInfo(
                label: selected.label,
                amount: selected.value,
                percent: selected.value / total,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var i = 0; i < items.length; i++)
                  _LegendItem(
                    label: items[i].label,
                    value: items[i].value,
                    selected: i == _selectedIndex,
                    onTap: () {
                      setState(() {
                        _selectedIndex = i;
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive + animated bar chart for the 6 most recent months.
///
/// Uses CustomPainter to draw bars.
/// Interaction: tap a bar to select a month.
/// Animation: bars grow from zero to their real height.
class MonthlyExpenseBarChart extends StatefulWidget {
  final List<Expense> expenses;

  const MonthlyExpenseBarChart({
    super.key,
    required this.expenses,
  });

  @override
  State<MonthlyExpenseBarChart> createState() =>
      _MonthlyExpenseBarChartState();
}

class _MonthlyExpenseBarChartState extends State<MonthlyExpenseBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant MonthlyExpenseBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.expenses.length != widget.expenses.length) {
      _selectedIndex = null;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_MonthItem> get _months {
    final now = DateTime.now();
    final result = <_MonthItem>[];

    for (var offset = 5; offset >= 0; offset--) {
      final date = DateTime(now.year, now.month - offset, 1);

      double total = 0;

      for (final expense in widget.expenses) {
        DateTime? expenseDate = DateTime.tryParse(expense.date);

        expenseDate ??= DateTime.tryParse(expense.createdAt);

        if (expenseDate == null) continue;

        if (expenseDate.year == date.year &&
            expenseDate.month == date.month) {
          total += expense.amount;
        }
      }

      result.add(
        _MonthItem(
          label: _monthShortName(date.month),
          fullLabel:
              '${_monthShortName(date.month)} ${date.year}',
          value: total,
        ),
      );
    }

    return result;
  }

  void _handleTap(
    TapUpDetails details,
    Size size,
  ) {
    final months = _months;
    if (months.isEmpty) return;

    final left = 38.0;
    final right = 14.0;
    final usableWidth = size.width - left - right;
    final slotWidth = usableWidth / months.length;

    final x = details.localPosition.dx;

    if (x < left || x > size.width - right) {
      return;
    }

    var index = ((x - left) / slotWidth).floor();

    if (index < 0) index = 0;
    if (index >= months.length) index = months.length - 1;

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = _months;

    if (months.every((month) => month.value <= 0)) {
      return const _EmptyChartCard(
        title: 'Monthly Spending',
        message: 'Add expenses to see monthly spending.',
      );
    }

    final selected = _selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < months.length
        ? months[_selectedIndex!]
        : null;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Spending',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a bar to inspect the month.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chartSize = Size(
                    constraints.maxWidth,
                    260,
                  );

                  return GestureDetector(
                    onTapUp: (details) {
                      _handleTap(details, chartSize);
                    },
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return CustomPaint(
                          size: chartSize,
                          painter: _MonthlyBarPainter(
                            months: months,
                            selectedIndex: _selectedIndex,
                            progress: Curves.easeOutCubic.transform(
                              _controller.value,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 4),
              _SelectedInfo(
                label: selected.fullLabel,
                amount: selected.value,
                percent: null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpensePiePainter extends CustomPainter {
  final List<_ChartItem> items;
  final int? selectedIndex;
  final double progress;

  _ExpensePiePainter({
    required this.items,
    required this.selectedIndex,
    required this.progress,
  });

  final List<Color> palette = const [
    Color(0xFF1976D2),
    Color(0xFF42A5F5),
    Color(0xFF7E57C2),
    Color(0xFF26A69A),
    Color(0xFFFFA726),
    Color(0xFFEF5350),
    Color(0xFF78909C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );

    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    var startAngle = -math.pi / 2;

    for (var i = 0; i < items.length; i++) {
      final sweep =
          (items[i].value / total) * math.pi * 2 * progress;

      if (sweep <= 0) continue;

      final isSelected = i == selectedIndex;

      final midAngle = startAngle + sweep / 2;

      final offset = isSelected
          ? Offset(
              math.cos(midAngle) * 10,
              math.sin(midAngle) * 10,
            )
          : Offset.zero;

      final paint = Paint()
        ..color = palette[i % palette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 54 : 46
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect.shift(offset),
        startAngle,
        sweep,
        false,
        paint,
      );

      startAngle += sweep;
    }

    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      radius - 25,
      holePaint,
    );

    final selected = selectedIndex != null &&
            selectedIndex! >= 0 &&
            selectedIndex! < items.length
        ? items[selectedIndex!]
        : null;

    final centerText = selected?.label ?? 'Total';
    final centerValue = selected != null
        ? _formatMoney(selected.value)
        : _formatMoney(total);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: centerText,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: radius * 1.2);

    final valuePainter = TextPainter(
      text: TextSpan(
        text: centerValue,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy - 22,
      ),
    );

    valuePainter.paint(
      canvas,
      Offset(
        center.dx - valuePainter.width / 2,
        center.dy + 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ExpensePiePainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.progress != progress;
  }
}

class _MonthlyBarPainter extends CustomPainter {
  final List<_MonthItem> months;
  final int? selectedIndex;
  final double progress;

  _MonthlyBarPainter({
    required this.months,
    required this.selectedIndex,
    required this.progress,
  });

  final List<Color> palette = const [
    Color(0xFF1976D2),
    Color(0xFF42A5F5),
    Color(0xFF7E57C2),
    Color(0xFF26A69A),
    Color(0xFFFFA726),
    Color(0xFFEF5350),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final left = 38.0;
    final right = 14.0;
    final top = 18.0;
    final bottom = 42.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final maxValue = months.fold<double>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );

    if (maxValue <= 0) return;

    final baseline = top + chartHeight;

    // Grid lines.
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * (i / 4);

      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    final slotWidth = chartWidth / months.length;
    final barWidth = slotWidth * 0.52;

    for (var i = 0; i < months.length; i++) {
      final value = months[i].value;
      final barHeight =
          (value / maxValue) * chartHeight * progress;

      final x = left +
          slotWidth * i +
          (slotWidth - barWidth) / 2;

      final isSelected = i == selectedIndex;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          baseline - barHeight,
          barWidth,
          math.max(0, barHeight),
        ),
        const Radius.circular(10),
      );

      final paint = Paint()
        ..color = isSelected
            ? palette[i % palette.length].withValues(alpha: 0.95)
            : palette[i % palette.length].withValues(alpha: 0.72);

      canvas.drawRRect(rect, paint);

      // Value above selected bar.
      if (isSelected && progress > 0.9 && value > 0) {
        final painter = TextPainter(
          text: TextSpan(
            text: formatCompactMoney(value),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: slotWidth);

        painter.paint(
          canvas,
          Offset(
            x + (barWidth - painter.width) / 2,
            math.max(0, baseline - barHeight - 22),
          ),
        );
      }

      // Month label.
      final labelPainter = TextPainter(
        text: TextSpan(
          text: months[i].label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth);

      labelPainter.paint(
        canvas,
        Offset(
          x + (barWidth - labelPainter.width) / 2,
          baseline + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyBarPainter oldDelegate) {
    return oldDelegate.months != months ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.progress != progress;
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final double value;
  final bool selected;
  final VoidCallback onTap;

  const _LegendItem({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.blue
                    : Colors.blue.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label • ${_formatMoney(value)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedInfo extends StatelessWidget {
  final String label;
  final double amount;
  final double? percent;

  const _SelectedInfo({
    required this.label,
    required this.amount,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (percent != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${(percent! * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          Text(
            _formatMoney(amount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartCard extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyChartCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bar_chart_outlined,
                    size: 52,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartItem {
  final String label;
  final double value;

  const _ChartItem({
    required this.label,
    required this.value,
  });
}

class _MonthItem {
  final String label;
  final String fullLabel;
  final double value;

  const _MonthItem({
    required this.label,
    required this.fullLabel,
    required this.value,
  });
}

/// Uses the same money formatter as the main app when available.
/// Keep this local so the chart file is self-contained.
String _formatMoney(double amount) {
  final value = amount.round().toString();

  return '${value.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  )} ₫';
}

String formatCompactMoney(double amount) {
  if (amount >= 1000000000) {
    return '${(amount / 1000000000).toStringAsFixed(1)}B';
  }

  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }

  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(0)}K';
  }

  return amount.round().toString();
}

String _monthShortName(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  if (month < 1 || month > 12) {
    return '';
  }

  return names[month - 1];
}
