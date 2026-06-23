import 'package:flutter/material.dart';
import '../../models/water_reading.dart';
import '../../services/sensor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ph_gauge.dart';
import '../../widgets/reading_tile.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/status_banner.dart';

class DashboardScreen extends StatefulWidget {
  final SensorService service;
  const DashboardScreen({super.key, required this.service});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? _lastUpdate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WaterReading?>(
      stream: widget.service.latestReadingStream(),
      builder: (context, snapshot) {
        final reading = snapshot.data;
        if (reading != null) {
          _lastUpdate = DateTime.now();
        }
        final isStale = widget.service.isStale(_lastUpdate);

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = readingGridColumns(constraints.maxWidth);

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: ResponsiveContainer(
                  maxWidth: 760,
                  child: Column(
                    children: [
                      StatusBanner(
                        status: reading?.status ?? WaterStatus.good,
                        isStale: isStale,
                        lastUpdate: _lastUpdate,
                      ),
                      const SizedBox(height: 20),

                      if (reading == null && !snapshot.hasData)
                        const _LoadingState()
                      else ...[
                        Center(
                          child: PhGauge(pH: reading?.pH ?? 7.0, size: 200),
                        ),
                        const SizedBox(height: 24),

                        GridView.count(
                          crossAxisCount: columns,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          children: [
                            ReadingTile(
                              label: 'Temperature',
                              value: (reading?.waterTemp ?? 0).toStringAsFixed(1),
                              unit: '°C',
                              icon: Icons.thermostat_rounded,
                              accentColor: AppColors.warning,
                            ),
                            ReadingTile(
                              label: 'Turbidity',
                              value: (reading?.turbidity ?? 0).toStringAsFixed(0),
                              unit: 'NTU',
                              icon: Icons.blur_on_rounded,
                              accentColor: AppColors.accentDim,
                            ),
                            ReadingTile(
                              label: 'TDS',
                              value: (reading?.tds ?? 0).toStringAsFixed(0),
                              unit: 'ppm',
                              icon: Icons.grain_rounded,
                              accentColor: AppColors.accent,
                            ),
                            ReadingTile(
                              label: 'Conductivity',
                              value: (reading?.ec ?? 0).toStringAsFixed(2),
                              unit: 'mS/cm',
                              icon: Icons.bolt_rounded,
                              accentColor: AppColors.phHigh,
                            ),
                          ],
                        ),

                        if (reading?.rssi != null) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi_rounded,
                                  size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Signal: ${reading!.rssi} dBm',
                                style: AppText.label,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 16),
          Text('Connecting to sensor station…',
              style: AppText.body.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
