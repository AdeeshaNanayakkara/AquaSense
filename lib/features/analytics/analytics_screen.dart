import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../core/services/database_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _dbService = DatabaseService.instance;
  final List<StreamSubscription> _subs = [];

  // Firebase states
  Map<String, double> _waterUsage = {};
  double _tankPercent = 0.0;
  double _wellPercent = 0.0;
  Map<String, dynamic> _config = {};

  // UI state
  int _selectedDays = 7; // 7 or 30
  bool _isLineChart = true; // line chart or bar chart toggle
  int? _hoveredIndex; // index of the point currently tapped/hovered in the chart

  @override
  void initState() {
    super.initState();

    // Subscribe to water usage
    _subs.add(_dbService.waterUsageStream.listen((usage) {
      if (mounted) setState(() => _waterUsage = usage);
    }, onError: (e) => debugPrint('[ANALYTICS] usage error: $e')));

    // Subscribe to levels to calculate reserve metrics
    _subs.add(_dbService.tankPercentageStream.listen((val) {
      if (mounted) setState(() => _tankPercent = val);
    }, onError: (e) => debugPrint('[ANALYTICS] tank error: $e')));

    _subs.add(_dbService.wellPercentageStream.listen((val) {
      if (mounted) setState(() => _wellPercent = val);
    }, onError: (e) => debugPrint('[ANALYTICS] well error: $e')));

    // Subscribe to configuration parameters
    _subs.add(_dbService.configurationStream.listen((val) {
      if (mounted) setState(() => _config = val);
    }, onError: (e) => debugPrint('[ANALYTICS] config error: $e')));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  // ─── Data Filtering & Processing ────────────────────────────────────────────

  /// Returns sorted list of entries representing daily usage for the selected period.
  /// Falls back to latest entries in database if current calendar dates are empty.
  List<MapEntry<String, double>> _getFilteredData() {
    final now = DateTime.now();
    final entries = <MapEntry<String, double>>[];
    double total = 0;

    // Try to get calendar dates relative to now
    for (int i = _selectedDays - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final val = _waterUsage[key] ?? 0.0;
      total += val;
      entries.add(MapEntry(key, val));
    }

    // Fallback: If no real-time calendar entries match, take the latest available records
    if (total == 0 && _waterUsage.isNotEmpty) {
      final sortedKeys = _waterUsage.keys.toList()..sort();
      final latestKeys = sortedKeys.length > _selectedDays
          ? sortedKeys.sublist(sortedKeys.length - _selectedDays)
          : sortedKeys;

      final fallbackEntries = <MapEntry<String, double>>[];
      for (final key in latestKeys) {
        fallbackEntries.add(MapEntry(key, _waterUsage[key] ?? 0.0));
      }
      return fallbackEntries;
    }

    return entries;
  }

  // ─── Analytics Computations ──────────────────────────────────────────────────

  double _calculateTotal(List<MapEntry<String, double>> data) {
    return data.fold(0.0, (sum, item) => sum + item.value);
  }

  double _calculateAverage(List<MapEntry<String, double>> data) {
    if (data.isEmpty) return 0.0;
    // Average over actual data points or selected range
    return _calculateTotal(data) / data.length;
  }

  MapEntry<String, double>? _calculatePeak(List<MapEntry<String, double>> data) {
    if (data.isEmpty) return null;
    MapEntry<String, double> peak = data.first;
    for (final item in data) {
      if (item.value > peak.value) {
        peak = item;
      }
    }
    return peak;
  }

  /// Estimates the number of remaining days before system goes completely empty
  /// using custom capacities calculated from the container radius and height configs.
  double _calculateReserveDays(double dailyAvg) {
    if (dailyAvg <= 0) return double.nan;

    // Default capacities if config is missing (Liters)
    double tankCapacity = 1000.0; 
    double wellCapacity = 3000.0;

    if (_config['tank'] != null) {
      final tank = _config['tank'] as Map;
      final empty = (tank['emptyDistance'] ?? 100.0) as num;
      final full = (tank['fullDistance'] ?? 10.0) as num;
      final radius = (tank['radius'] ?? 50.0) as num;
      
      final usableHeight = empty - full;
      if (usableHeight > 0 && radius > 0) {
        // Volume (Liters) = (pi * r^2 * h) / 1000 where r and h are in cm
        tankCapacity = (math.pi * math.pow(radius.toDouble(), 2) * usableHeight.toDouble()) / 1000.0;
      }
    }

    if (_config['well'] != null) {
      final well = _config['well'] as Map;
      final empty = (well['emptyDistance'] ?? 200.0) as num;
      final full = (well['fullDistance'] ?? 20.0) as num;
      final radius = (well['radius'] ?? 60.0) as num;

      final usableHeight = empty - full;
      if (usableHeight > 0 && radius > 0) {
        // Volume (Liters) = (pi * r^2 * h) / 1000 where r and h are in cm
        wellCapacity = (math.pi * math.pow(radius.toDouble(), 2) * usableHeight.toDouble()) / 1000.0;
      }
    }

    final tankLiters = (_tankPercent / 100.0) * tankCapacity;
    final wellLiters = (_wellPercent / 100.0) * wellCapacity;
    final totalLiters = tankLiters + wellLiters;
    return totalLiters / dailyAvg;
  }

  String _formatDateLabel(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final dt = DateTime(year, month, day);

      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} $day';
    } catch (_) {
      return dateStr;
    }
  }

  // ─── Build Method ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final data = _getFilteredData();
    final totalUsage = _calculateTotal(data);
    final avgUsage = _calculateAverage(data);
    final peakEntry = _calculatePeak(data);
    final reserveDays = _calculateReserveDays(avgUsage);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Water Analytics',
          style: theme.textTheme.titleLarge?.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Timeframe & Chart Style controls ───────────────────────────
            _buildChartFilters(theme, isDark),
            const SizedBox(height: AppSpacing.md),

            // ─── Interactive Chart Card ─────────────────────────────────────
            _buildChartCard(data, theme, isDark),
            const SizedBox(height: AppSpacing.md),

            // ─── KPI Cards Grid ─────────────────────────────────────────────
            _buildKpiGrid(totalUsage, avgUsage, peakEntry, reserveDays, theme, isDark),
            const SizedBox(height: AppSpacing.md),

            // ─── System Insights ────────────────────────────────────────────
            _buildSystemInsights(avgUsage, reserveDays, theme, isDark),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ─── UI Segmented Filters ──────────────────────────────────────────────────

  Widget _buildChartFilters(ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Timeframe selector
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _filterButton('7 Days', _selectedDays == 7, () {
                setState(() {
                  _selectedDays = 7;
                  _hoveredIndex = null;
                });
              }, isDark),
              _filterButton('30 Days', _selectedDays == 30, () {
                setState(() {
                  _selectedDays = 30;
                  _hoveredIndex = null;
                });
              }, isDark),
            ],
          ),
        ),

        // Chart type selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.show_chart_rounded,
                  color: _isLineChart ? AppColors.secondary : (isDark ? Colors.white38 : Colors.black38),
                  size: 20,
                ),
                onPressed: () => setState(() => _isLineChart = true),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: Icon(
                  Icons.bar_chart_rounded,
                  color: !_isLineChart ? AppColors.secondary : (isDark ? Colors.white38 : Colors.black38),
                  size: 20,
                ),
                onPressed: () => setState(() => _isLineChart = false),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterButton(String label, bool selected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ─── Graphical Chart Display Card ──────────────────────────────────────────

  Widget _buildChartCard(List<MapEntry<String, double>> data, ThemeData theme, bool isDark) {
    if (data.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 240,
          child: Center(
            child: Text('No water usage data available.'),
          ),
        ),
      );
    }

    final maxVal = data.map((e) => e.value).reduce(math.max).clamp(1.0, double.infinity);
    final showTooltip = _hoveredIndex != null && _hoveredIndex! < data.length;

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Water Usage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showTooltip)
                  Text(
                    '${data[_hoveredIndex!].value.toStringAsFixed(0)} Liters',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              showTooltip
                  ? _formatDateLabel(data[_hoveredIndex!].key)
                  : 'Tap or drag across the chart to view specific dates.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: showTooltip 
                    ? AppColors.secondary
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Interactive Drawing Canvas
            GestureDetector(
              onTapUp: (details) => _handleChartTap(details.localPosition, data.length),
              onPanUpdate: (details) => _handleChartTap(details.localPosition, data.length),
              child: Container(
                height: 180,
                width: double.infinity,
                color: Colors.transparent, // Capture gesture hits
                child: CustomPaint(
                  painter: AnalyticsChartPainter(
                    data: data,
                    maxVal: maxVal,
                    isLineChart: _isLineChart,
                    isDarkTheme: isDark,
                    hoveredIndex: _hoveredIndex,
                  ),
                ),
              ),
            ),
            
            // X-Axis Labels Row
            const SizedBox(height: 12),
            _buildXAxisLabels(data, isDark),
          ],
        ),
      ),
    );
  }

  void _handleChartTap(Offset localPos, int dataCount) {
    if (dataCount == 0) return;
    // Find index based on percentage position
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final totalWidth = renderBox.size.width - (AppSpacing.md * 2) - 16; // Margins estimate
    final xRatio = (localPos.dx / totalWidth).clamp(0.0, 1.0);
    
    // Convert to index
    int index = (xRatio * (dataCount - 1)).round();
    if (index >= 0 && index < dataCount) {
      setState(() {
        _hoveredIndex = index;
      });
    }
  }

  Widget _buildXAxisLabels(List<MapEntry<String, double>> data, bool isDark) {
    if (data.length <= 7) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: data.map((e) {
          final label = e.key.substring(8); // dd
          return Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
            ),
          );
        }).toList(),
      );
    } else {
      // For 30 points, print labels at intervals of 5
      final widgets = <Widget>[];
      for (int i = 0; i < data.length; i++) {
        if (i % 5 == 0 || i == data.length - 1) {
          widgets.add(Text(
            data[i].key.substring(5), // mm-dd
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
            ),
          ));
        } else {
          widgets.add(const SizedBox.shrink());
        }
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: widgets,
      );
    }
  }

  // ─── KPI Cards Grid ────────────────────────────────────────────────────────

  Widget _buildKpiGrid(
    double total,
    double average,
    MapEntry<String, double>? peak,
    double reserveDays,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _kpiCard(
                title: 'Total Consumed',
                value: '${total.toStringAsFixed(0)} L',
                subtitle: 'Selected timeframe total',
                icon: Icons.water_drop_rounded,
                iconColor: AppColors.secondary,
                isDark: isDark,
                theme: theme,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _kpiCard(
                title: 'Daily Average',
                value: '${average.toStringAsFixed(1)} L/d',
                subtitle: 'Consumption per day',
                icon: Icons.equalizer_rounded,
                iconColor: AppColors.info,
                isDark: isDark,
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _kpiCard(
                title: 'Peak Usage',
                value: peak != null ? '${peak.value.toStringAsFixed(0)} L' : '-',
                subtitle: peak != null ? _formatDateLabel(peak.key) : 'No usage logs',
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.warning,
                isDark: isDark,
                theme: theme,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _kpiCard(
                title: 'Reserve Life',
                value: reserveDays.isNaN
                    ? 'N/A'
                    : (reserveDays.isInfinite
                        ? 'Infinite'
                        : '${reserveDays.toStringAsFixed(1)} days'),
                subtitle: 'Time until empty',
                icon: Icons.hourglass_empty_rounded,
                iconColor: reserveDays < 3.0 ? AppColors.error : AppColors.success,
                isDark: isDark,
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                Icon(icon, color: iconColor, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Insights Section ──────────────────────────────────────────────────────

  Widget _buildSystemInsights(double dailyAvg, double reserveDays, ThemeData theme, bool isDark) {
    final insights = <Widget>[];

    // Insight 1: Based on usage average
    if (dailyAvg > 120.0) {
      insights.add(_insightItem(
        title: 'High Usage Warning',
        text: 'Your average consumption is higher than usual. Consider inspect pipelines for valves seepage.',
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.error,
        isDark: isDark,
        theme: theme,
      ));
    } else if (dailyAvg > 0) {
      insights.add(_insightItem(
        title: 'Healthy Conservation',
        text: 'Your daily consumption is within excellent parameters. Great job conserving resources!',
        icon: Icons.wb_sunny_rounded,
        iconColor: AppColors.success,
        isDark: isDark,
        theme: theme,
      ));
    }

    // Insight 2: Based on Reserve life
    if (!reserveDays.isNaN && !reserveDays.isInfinite) {
      if (reserveDays < 3.0) {
        insights.add(_insightItem(
          title: 'Critical Reserves Alert',
          text: 'At current consumption rates, your total water reserves (Well + Tank) will empty in less than 3 days.',
          icon: Icons.hourglass_bottom_rounded,
          iconColor: AppColors.error,
          isDark: isDark,
          theme: theme,
        ));
      } else if (reserveDays < 7.0) {
        insights.add(_insightItem(
          title: 'Moderate Storage Reserves',
          text: 'Water reserves will support household operation for about a week. Keep an eye on well replenishment.',
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.warning,
          isDark: isDark,
          theme: theme,
        ));
      }
    }

    // Default insight if none triggered
    if (insights.isEmpty) {
      insights.add(_insightItem(
        title: 'System Initializing',
        text: 'Usage logs are compiling. Insights on conservation efficiency will display here as data grows.',
        icon: Icons.analytics_outlined,
        iconColor: AppColors.secondary,
        isDark: isDark,
        theme: theme,
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dynamic Conservation Insights',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: AppSpacing.lg),
            ...insights,
          ],
        ),
      ),
    );
  }

  Widget _insightItem({
    required String title,
    required String text,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painter for Line & Bar Charting ──────────────────────────────────

class AnalyticsChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final double maxVal;
  final bool isLineChart;
  final bool isDarkTheme;
  final int? hoveredIndex;

  AnalyticsChartPainter({
    required this.data,
    required this.maxVal,
    required this.isLineChart,
    required this.isDarkTheme,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final w = size.width;
    final h = size.height;

    // Define margins
    final startX = 10.0;
    final endX = w - 10.0;
    final startY = 10.0;
    final endY = h - 10.0;
    final graphWidth = endX - startX;
    final graphHeight = endY - startY;

    final double stepX = data.length > 1 ? graphWidth / (data.length - 1) : graphWidth;

    // Helper to map y value to coordinate
    double getY(double val) {
      final fraction = val / maxVal;
      return endY - (graphHeight * fraction);
    }

    if (isLineChart) {
      // ─── DRAW LINE / AREA CHART ────────────────────────────────────────────
      final path = Path();
      final fillPath = Path();

      path.moveTo(startX, getY(data.first.value));
      fillPath.moveTo(startX, endY);
      fillPath.lineTo(startX, getY(data.first.value));

      for (int i = 1; i < data.length; i++) {
        final x = startX + (i * stepX);
        final y = getY(data[i].value);
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      fillPath.lineTo(startX + ((data.length - 1) * stepX), endY);
      fillPath.close();

      // Draw Gradient Fill under line
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.secondary.withValues(alpha: 0.35),
            AppColors.secondary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(startX, startY, endX, endY))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Draw Main line
      final linePaint = Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);

      // Draw highlighted/hovered indicator lines and circles
      final dotPaint = Paint()..style = PaintingStyle.fill;
      final strokeDotPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white;

      for (int i = 0; i < data.length; i++) {
        final x = startX + (i * stepX);
        final y = getY(data[i].value);

        if (hoveredIndex == i) {
          // Draw vertical line guide
          final guidePaint = Paint()
            ..color = AppColors.secondary.withValues(alpha: 0.25)
            ..strokeWidth = 1.0;
          canvas.drawLine(Offset(x, startY), Offset(x, endY), guidePaint);

          // Draw large pulsing dot
          dotPaint.color = AppColors.secondary;
          canvas.drawCircle(Offset(x, y), 6.0, dotPaint);
          canvas.drawCircle(Offset(x, y), 4.5, strokeDotPaint);
        } else {
          // Small regular dots for 7 days, skip for 30 days to avoid clutter
          if (data.length <= 7) {
            dotPaint.color = AppColors.secondaryDark;
            canvas.drawCircle(Offset(x, y), 3.0, dotPaint);
          }
        }
      }
    } else {
      // ─── DRAW BAR CHART ────────────────────────────────────────────────────
      final barWidthRatio = data.length > 7 ? 0.70 : 0.50;
      final double computedBarWidth = (stepX * barWidthRatio).clamp(4.0, 32.0);

      final barPaint = Paint()..style = PaintingStyle.fill;

      for (int i = 0; i < data.length; i++) {
        final centerX = startX + (i * stepX);
        final y = getY(data[i].value);

        final rect = Rect.fromLTRB(
          centerX - computedBarWidth / 2,
          y,
          centerX + computedBarWidth / 2,
          endY,
        );

        final isHovered = hoveredIndex == i;
        barPaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isHovered
              ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
              : [AppColors.secondary, AppColors.secondaryDark],
        ).createShader(rect);

        // Draw rounded top bar
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(rrect, barPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
