import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/time/calendar_date.dart';
import '../domain/trend_calculator.dart';
import '../domain/trend_range.dart';
import '../domain/trend_summary.dart';

enum _TrendPreset { sevenDays, thirtyDays, ninetyDays, custom }

class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  _TrendPreset _preset = _TrendPreset.sevenDays;
  TrendRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final eventsValue = ref.watch(allEventsProvider);
    final range = _selectedRange();
    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _RangeSelector(
              selected: _preset,
              range: range,
              onSelected: _selectPreset,
            ),
            const Divider(height: 1),
            Expanded(
              child: eventsValue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: FilledButton.icon(
                    onPressed: () => ref.invalidate(allEventsProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try loading trends again'),
                  ),
                ),
                data: (events) {
                  final summary = const TrendCalculator().calculate(
                    events: events,
                    range: range,
                  );
                  return _TrendContent(summary: summary);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  TrendRange _selectedRange() {
    if (_preset == _TrendPreset.custom && _customRange != null) {
      return _customRange!;
    }
    final now = ref.read(clockProvider)();
    final end = CalendarDate.fromRecordedWallDate(now);
    final days = switch (_preset) {
      _TrendPreset.sevenDays => 7,
      _TrendPreset.thirtyDays => 30,
      _TrendPreset.ninetyDays => 90,
      _TrendPreset.custom => 7,
    };
    final startDate = end.asUtcMidnight.subtract(Duration(days: days - 1));
    return TrendRange(
      start: CalendarDate(startDate.year, startDate.month, startDate.day),
      end: end,
    );
  }

  Future<void> _selectPreset(_TrendPreset preset) async {
    if (preset != _TrendPreset.custom) {
      setState(() => _preset = preset);
      return;
    }
    final now = ref.read(clockProvider)();
    final existing = _customRange;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: existing == null
          ? null
          : DateTimeRange(
              start: DateTime(
                existing.start.year,
                existing.start.month,
                existing.start.day,
              ),
              end: DateTime(
                existing.end.year,
                existing.end.month,
                existing.end.day,
              ),
            ),
      helpText: 'Choose a trends date range',
    );
    if (picked == null) return;
    setState(() {
      _customRange = TrendRange(
        start: CalendarDate.fromRecordedWallDate(picked.start),
        end: CalendarDate.fromRecordedWallDate(picked.end),
      );
      _preset = _TrendPreset.custom;
    });
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.range,
    required this.onSelected,
  });

  final _TrendPreset selected;
  final TrendRange range;
  final ValueChanged<_TrendPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _choice('7 days', _TrendPreset.sevenDays),
                const SizedBox(width: 8),
                _choice('30 days', _TrendPreset.thirtyDays),
                const SizedBox(width: 8),
                _choice('90 days', _TrendPreset.ninetyDays),
                const SizedBox(width: 8),
                _choice('Custom', _TrendPreset.custom),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat.yMMMd().format(range.start.asUtcMidnight)} – '
            '${DateFormat.yMMMd().format(range.end.asUtcMidnight)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, _TrendPreset value) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _TrendContent extends StatelessWidget {
  const _TrendContent({required this.summary});

  final TrendSummary summary;

  @override
  Widget build(BuildContext context) {
    final urinationTotal = summary.dailyTotals.fold<int>(
      0,
      (sum, day) => sum + day.urinationCount,
    );
    final bowelTotal = summary.dailyTotals.fold<int>(
      0,
      (sum, day) => sum + day.bowelMovementCount,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SummaryGrid(
          cards: [
            _SummaryValue(
              label: 'Urination events',
              value: '$urinationTotal',
              icon: Icons.water_drop_outlined,
            ),
            _SummaryValue(
              label: 'Woke to urinate',
              value: '${summary.nocturiaCount}',
              icon: Icons.bedtime_outlined,
            ),
            _SummaryValue(
              label: 'Bowel movements',
              value: '$bowelTotal',
              icon: Icons.circle_outlined,
            ),
            _SummaryValue(
              label: 'Urination avg/day',
              value: summary.averageUrinationEventsPerDay.toStringAsFixed(1),
              icon: Icons.functions,
            ),
            _SummaryValue(
              label: 'Bowel avg/day',
              value: summary.averageBowelMovementEventsPerDay.toStringAsFixed(
                1,
              ),
              icon: Icons.functions,
            ),
            _SummaryValue(
              label: 'All events avg/day',
              value: summary.averageTotalEventsPerDay.toStringAsFixed(1),
              icon: Icons.calculate_outlined,
            ),
            _SummaryValue(
              label: 'Longest urine gap',
              value: _formatInterval(summary.longestUrinationInterval),
              icon: Icons.timelapse_outlined,
            ),
            _SummaryValue(
              label: 'Average urine gap',
              value: _formatInterval(summary.averageUrinationInterval),
              icon: Icons.schedule_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _ChartCard(
          title: 'Events per day',
          subtitle: 'Every date is included, even days with no events.',
          legend: const _ChartLegend(),
          child: _DailyLineChart(totals: summary.dailyTotals),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Urination by hour',
          subtitle: 'Hour of day when each event was recorded.',
          child: _HourlyBarChart(
            values: summary.urinationByHour,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Bowel movements by hour',
          subtitle: 'Hour of day when each event was recorded.',
          child: _HourlyBarChart(
            values: summary.bowelMovementByHour,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Weekly trend',
          subtitle: 'Calendar weeks begin on Monday.',
          legend: const _ChartLegend(),
          child: _AggregateBarChart(
            items: [
              for (final week in summary.weeklyTotals)
                _AggregateItem(
                  label: DateFormat.Md().format(week.weekStart.asUtcMidnight),
                  urination: week.urinationCount,
                  bowel: week.bowelMovementCount,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Monthly trend',
          subtitle: 'Calendar month totals in the selected range.',
          legend: const _ChartLegend(),
          child: _AggregateBarChart(
            items: [
              for (final month in summary.monthlyTotals)
                _AggregateItem(
                  label: DateFormat(
                    'MMM yy',
                  ).format(DateTime.utc(month.year, month.month)),
                  urination: month.urinationCount,
                  bowel: month.bowelMovementCount,
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatInterval(Duration? value) {
    if (value == null) return 'Not enough data';
    if (value.inDays > 0) {
      final hours = value.inHours.remainder(24);
      return '${value.inDays}d ${hours}h';
    }
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${value.inMinutes}m';
  }
}

class _SummaryValue {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cards});

  final List<_SummaryValue> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        final spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(card.icon, size: 26),
                        const SizedBox(height: 10),
                        Text(
                          card.value,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(card.label),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.legend,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? legend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            if (legend != null) ...[const SizedBox(height: 10), legend!],
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        _LegendItem(
          color: Theme.of(context).colorScheme.primary,
          label: 'Urination',
        ),
        _LegendItem(
          color: Theme.of(context).colorScheme.tertiary,
          label: 'Bowel movement',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DailyLineChart extends StatelessWidget {
  const _DailyLineChart({required this.totals});

  final List<DailyEventTotal> totals;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tertiary = Theme.of(context).colorScheme.tertiary;
    final highest = totals.fold<int>(
      0,
      (current, day) => math.max(
        current,
        math.max(day.urinationCount, day.bowelMovementCount),
      ),
    );
    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 72,
      totals.length * 18.0,
    );
    final labelStep = math.max(1, (totals.length / 5).ceil());
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        height: 220,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: math.max(1, totals.length - 1).toDouble(),
            minY: 0,
            maxY: math.max(2, highest + 1).toDouble(),
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 30),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 ||
                        index >= totals.length ||
                        (index % labelStep != 0 &&
                            index != totals.length - 1)) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        DateFormat.Md().format(
                          totals[index].date.asUtcMidnight,
                        ),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var index = 0; index < totals.length; index++)
                    FlSpot(
                      index.toDouble(),
                      totals[index].urinationCount.toDouble(),
                    ),
                ],
                color: primary,
                barWidth: 3,
                isCurved: false,
                dotData: FlDotData(show: totals.length <= 30),
              ),
              LineChartBarData(
                spots: [
                  for (var index = 0; index < totals.length; index++)
                    FlSpot(
                      index.toDouble(),
                      totals[index].bowelMovementCount.toDouble(),
                    ),
                ],
                color: tertiary,
                barWidth: 3,
                isCurved: false,
                dotData: FlDotData(show: totals.length <= 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final highest = values.fold<int>(0, math.max);
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: math.max(2, highest + 1).toDouble(),
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final hour = value.round();
                  if (hour != 0 && hour != 6 && hour != 12 && hour != 18) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      hour == 0
                          ? '12a'
                          : hour == 12
                          ? '12p'
                          : hour < 12
                          ? '${hour}a'
                          : '${hour - 12}p',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var hour = 0; hour < values.length; hour++)
              BarChartGroupData(
                x: hour,
                barRods: [
                  BarChartRodData(
                    toY: values[hour].toDouble(),
                    color: color,
                    width: 7,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AggregateItem {
  const _AggregateItem({
    required this.label,
    required this.urination,
    required this.bowel,
  });

  final String label;
  final int urination;
  final int bowel;
}

class _AggregateBarChart extends StatelessWidget {
  const _AggregateBarChart({required this.items});

  final List<_AggregateItem> items;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tertiary = Theme.of(context).colorScheme.tertiary;
    final highest = items.fold<int>(
      0,
      (value, item) => math.max(value, math.max(item.urination, item.bowel)),
    );
    final width = math.max(
      MediaQuery.sizeOf(context).width - 72,
      items.length * 58.0,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: 210,
        child: BarChart(
          BarChartData(
            maxY: math.max(2, highest + 1).toDouble(),
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 30),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= items.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        items[index].label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var index = 0; index < items.length; index++)
                BarChartGroupData(
                  x: index,
                  barsSpace: 3,
                  barRods: [
                    BarChartRodData(
                      toY: items[index].urination.toDouble(),
                      color: primary,
                      width: 10,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                    BarChartRodData(
                      toY: items[index].bowel.toDouble(),
                      color: tertiary,
                      width: 10,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
