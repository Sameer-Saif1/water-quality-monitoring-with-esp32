import 'package:flutter/material.dart';
import '../../models/thresholds.dart';
import '../../services/sensor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

class AlertsScreen extends StatefulWidget {
  final SensorService service;
  const AlertsScreen({super.key, required this.service});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Thresholds _current = const Thresholds();
  bool _dirty = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Thresholds>(
      stream: widget.service.thresholdsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData && !_dirty) {
          _current = snapshot.data!;
        }

        return Center(
          child: ResponsiveContainer(
            maxWidth: 600,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Set the ranges that count as normal for your water source. '
                  'Readings outside these values trigger the warning or alert '
                  'banner on the dashboard for everyone with access.',
                  style: AppText.body.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                _ThresholdCard(
                  title: 'pH range',
                  child: Column(
                    children: [
                      _RangeSlider(
                        label: 'Minimum',
                        value: _current.phMin,
                        min: 0,
                        max: 14,
                        divisions: 28,
                        onChanged: (v) => _update(_current.copyWith(phMin: v)),
                      ),
                      _RangeSlider(
                        label: 'Maximum',
                        value: _current.phMax,
                        min: 0,
                        max: 14,
                        divisions: 28,
                        onChanged: (v) => _update(_current.copyWith(phMax: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ThresholdCard(
                  title: 'Turbidity limit',
                  child: _RangeSlider(
                    label: 'Max NTU',
                    value: _current.turbidityMax,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) =>
                        _update(_current.copyWith(turbidityMax: v)),
                  ),
                ),
                const SizedBox(height: 16),
                _ThresholdCard(
                  title: 'TDS limit',
                  child: _RangeSlider(
                    label: 'Max ppm',
                    value: _current.tdsMax,
                    min: 0,
                    max: 1500,
                    divisions: 30,
                    onChanged: (v) => _update(_current.copyWith(tdsMax: v)),
                  ),
                ),
                const SizedBox(height: 16),
                _ThresholdCard(
                  title: 'Temperature limit',
                  child: _RangeSlider(
                    label: 'Max °C',
                    value: _current.tempMax,
                    min: 0,
                    max: 50,
                    divisions: 25,
                    onChanged: (v) => _update(_current.copyWith(tempMax: v)),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _dirty && !_saving ? _save : null,
                  child: Text(
                    _saving ? 'Saving…' : (_dirty ? 'Save thresholds' : 'Saved'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _update(Thresholds t) {
    setState(() {
      _current = t;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.service.saveThresholds(_current);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thresholds saved')),
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ThresholdCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RangeSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _RangeSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: AppText.label)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.end,
            style: AppText.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
