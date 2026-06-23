import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/water_reading.dart';
import '../../services/sensor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

class HistoryScreen extends StatefulWidget {
  final SensorService service;
  const HistoryScreen({super.key, required this.service});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Metric { pH, temp, turbidity, tds }

class _HistoryScreenState extends State<HistoryScreen> {
  _Metric _selected = _Metric.pH;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WaterReading>>(
      stream: widget.service.historyStream(limit: 60),
      builder: (context, snapshot) {
        final data = snapshot.data ?? [];

        return Center(
          child: ResponsiveContainer(
            maxWidth: 760,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricSelector(
                  selected: _selected,
                  onChanged: (m) => setState(() => _selected = m),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 360,
                  child: data.length < 2
                      ? Center(
                          child: Text(
                            'Collecting data…\nCheck back in a few minutes.',
                            textAlign: TextAlign.center,
                            style: AppText.body
                                .copyWith(color: AppColors.textMuted),
                          ),
                        )
                      : _HistoryChart(data: data, metric: _selected),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricSelector extends StatelessWidget {
  final _Metric selected;
  final ValueChanged<_Metric> onChanged;

  const _MetricSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = {
      _Metric.pH: 'pH',
      _Metric.temp: 'Temp',
      _Metric.turbidity: 'Turbidity',
      _Metric.tds: 'TDS',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.entries.map((e) {
          final isSelected = e.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: isSelected,
              onSelected: (_) => onChanged(e.key),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accent.withValues(alpha: 0.25),
              side: BorderSide(
                color: isSelected ? AppColors.accent : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final List<WaterReading> data;
  final _Metric metric;

  const _HistoryChart({required this.data, required this.metric});

  double _valueFor(WaterReading r) {
    switch (metric) {
      case _Metric.pH:
        return r.pH;
      case _Metric.temp:
        return r.waterTemp;
      case _Metric.turbidity:
        return r.turbidity;
      case _Metric.tds:
        return r.tds;
    }
  }

  String get _unit {
    switch (metric) {
      case _Metric.pH:
        return '';
      case _Metric.temp:
        return '°C';
      case _Metric.turbidity:
        return 'NTU';
      case _Metric.tds:
        return 'ppm';
    }
  }

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (int i = 0; i < data.length; i++)
        FlSpot(i.toDouble(), _valueFor(data[i])),
    ];

    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY) * 0.15).clamp(0.5, double.infinity);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ((maxY - minY) / 4).clamp(0.5, double.infinity),
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(metric == _Metric.pH ? 1 : 0),
                  style: AppText.label.copyWith(fontSize: 10),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: AppColors.accent,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.25),
                    AppColors.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceRaised,
              getTooltipItems: (spots) => spots.map((s) {
                return LineTooltipItem(
                  '${s.y.toStringAsFixed(2)} $_unit',
                  AppText.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
