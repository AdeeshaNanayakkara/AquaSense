import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/database_service.dart';
import 'widgets/water_tank_painter.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;

  // Firebase data
  double _tankPercent = 0;
  double _wellPercent = 0;
  String _mode = 'AUTO';
  bool _pumpOn = false;
  Map<String, double> _waterUsage = {};

  // Subscriptions
  final List<StreamSubscription> _subs = [];

  // Wave animation controller
  late AnimationController _waveController;

  final _dbService = DatabaseService.instance;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Subscribe to real-time streams
    _subs.add(_dbService.tankPercentageStream.listen(
      (val) { if (mounted) setState(() => _tankPercent = val); },
      onError: (e) => debugPrint('[STREAM] tank% error: $e'),
    ));
    _subs.add(_dbService.wellPercentageStream.listen(
      (val) { if (mounted) setState(() => _wellPercent = val); },
      onError: (e) => debugPrint('[STREAM] well% error: $e'),
    ));
    _subs.add(_dbService.modeStream.listen(
      (val) { if (mounted) setState(() => _mode = val); },
      onError: (e) => debugPrint('[STREAM] mode error: $e'),
    ));
    _subs.add(_dbService.pumpStream.listen(
      (val) { if (mounted) setState(() => _pumpOn = val); },
      onError: (e) => debugPrint('[STREAM] pump error: $e'),
    ));
    _subs.add(_dbService.waterUsageStream.listen(
      (val) { if (mounted) setState(() => _waterUsage = val); },
      onError: (e) => debugPrint('[STREAM] waterUsage error: $e'),
    ));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _waveController.dispose();
    super.dispose();
  }

  // ─── Status helpers ───────────────────────────────────────────────────────

  String _tankStatusLabel(double pct) {
    if (pct <= 20) return 'Low Water Level';
    if (pct < 85) return 'Tank Filling / Normal';
    return 'Tank Full';
  }

  Color _tankStatusColor(double pct) {
    if (pct <= 20) return AppColors.error;
    if (pct < 85) return AppColors.warning;
    return AppColors.success;
  }

  IconData _tankStatusIcon(double pct) {
    if (pct <= 20) return Icons.warning_amber_rounded;
    if (pct < 85) return Icons.autorenew_rounded;
    return Icons.check_circle_rounded;
  }

  // ─── Water usage helpers ──────────────────────────────────────────────────

  /// Returns usage entries for the last 7 days, sorted newest first.
  List<MapEntry<String, double>> _lastWeekUsage() {
    final now = DateTime.now();
    final entries = <MapEntry<String, double>>[];
    double totalUsage = 0;
    
    // First, try to populate relative to the real-time current date (last 7 days)
    for (int i = 1; i <= 7; i++) {
      final date = now.subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final val = _waterUsage[key] ?? 0;
      totalUsage += val;
      entries.add(MapEntry(key, val));
    }

    // If the calendar days are entirely empty but we have entries in the database,
    // fall back to showing the latest 7 available records from the database
    // so mock/demo data is visible.
    if (totalUsage == 0 && _waterUsage.isNotEmpty) {
      final sortedKeys = _waterUsage.keys.toList()..sort();
      final latestKeys = sortedKeys.length > 7
          ? sortedKeys.sublist(sortedKeys.length - 7)
          : sortedKeys;

      final fallbackEntries = <MapEntry<String, double>>[];
      for (final key in latestKeys) {
        fallbackEntries.add(MapEntry(key, _waterUsage[key] ?? 0));
      }
      // Return newest-first order
      return fallbackEntries.reversed.toList();
    }

    return entries;
  }

  double _yesterdayUsage() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final key =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    
    if (_waterUsage.containsKey(key)) {
      return _waterUsage[key] ?? 0;
    }

    // Fallback: If yesterday's date has no data, return the most recent database record
    if (_waterUsage.isNotEmpty) {
      final sortedKeys = _waterUsage.keys.toList()..sort();
      final latestKey = sortedKeys.last;
      return _waterUsage[latestKey] ?? 0;
    }

    return 0;
  }

  double _lastWeekTotal() {
    return _lastWeekUsage().fold(0.0, (sum, e) => sum + e.value);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.water_drop_rounded,
              color: AppColors.secondary,
              size: AppSizes.iconMd,
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Badge(
              label: Text('2'),
              child: Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 4),
          const _UserAvatarMenu(),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcoming User
            Text(
              'Hello, ${FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? 'User'}!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your water management system is running smoothly.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ═══════════════════════════════════════════════════════════════
            // SECTION 1 — Live Sensor Data
            // ═══════════════════════════════════════════════════════════════
            _buildSensorSection(theme, isDark),

            const SizedBox(height: AppSpacing.md),

            // ═══════════════════════════════════════════════════════════════
            // STATUS STRIP
            // ═══════════════════════════════════════════════════════════════
            _buildStatusStrip(theme),

            const SizedBox(height: AppSpacing.md),

            // ═══════════════════════════════════════════════════════════════
            // SECTION 2 — System Controls
            // ═══════════════════════════════════════════════════════════════
            _buildControlsSection(theme, isDark),

            const SizedBox(height: AppSpacing.lg),

            // ═══════════════════════════════════════════════════════════════
            // SECTION 3 — Water Usage
            // ═══════════════════════════════════════════════════════════════
            _buildWaterUsageSection(theme, isDark),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1 — Live Sensor Data
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSensorSection(ThemeData theme, bool isDark) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Mode badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LIVE WATER LEVELS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _modeBadge(),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Tank + Well row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ── Main Tank (large) ──────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Animated Tank
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          return SizedBox(
                            width: 120,
                            height: 160,
                            child: CustomPaint(
                              painter: WaterTankPainter(
                                waterLevel: _tankPercent / 100.0,
                                wavePhase:
                                    _waveController.value * 2 * math.pi,
                                waterColor: AppColors.secondary,
                                tankBorderColor:
                                    Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Tank percentage (high priority)
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: _tankPercent),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Text(
                            '${value.toStringAsFixed(0)}%',
                            style:
                                theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 38,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Main Tank',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Divider ────────────────────────────────────────────
                Container(
                  width: 1,
                  height: 120,
                  color: Colors.white12,
                ),

                // ── Well (smaller) ─────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // Circular well gauge
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: _wellPercent / 100.0),
                                duration:
                                    const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 7,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: Colors.white12,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      AppColors.secondaryLight,
                                    ),
                                  );
                                },
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween(end: _wellPercent),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return Text(
                                  '${value.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Well',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeBadge() {
    final isAuto = _mode == 'AUTO';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isAuto
            ? AppColors.success.withValues(alpha: 0.2)
            : AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAuto
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.warning.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAuto ? Icons.auto_mode_rounded : Icons.pan_tool_rounded,
            color: isAuto ? AppColors.success : AppColors.warning,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            isAuto ? 'AUTO' : 'MANUAL',
            style: TextStyle(
              color: isAuto ? AppColors.success : AppColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS STRIP
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatusStrip(ThemeData theme) {
    final statusColor = _tankStatusColor(_tankPercent);
    final statusLabel = _tankStatusLabel(_tankPercent);
    final statusIcon = _tankStatusIcon(_tankPercent);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              statusIcon,
              key: ValueKey(statusIcon),
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                statusLabel,
                key: ValueKey(statusLabel),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          // Percentage chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_tankPercent.toStringAsFixed(0)}%',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2 — System Controls
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildControlsSection(ThemeData theme, bool isDark) {
    final isAuto = _mode == 'AUTO';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Controls',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Auto / Manual Mode Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // Mode toggle row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAuto
                            ? Icons.auto_mode_rounded
                            : Icons.pan_tool_rounded,
                        color: AppColors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Operating Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAuto
                                ? 'System controls the pump automatically'
                                : 'Manual pump control enabled',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Segmented toggle
                    _buildModeToggle(theme, isDark),
                  ],
                ),

                // Motor switch (only visible in MANUAL mode)
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _pumpOn
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.settings_input_component_rounded,
                              color: _pumpOn
                                  ? AppColors.success
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Water Pump Motor',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _pumpOn
                                      ? 'Motor is running'
                                      : 'Motor is off',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _pumpOn
                                        ? AppColors.success
                                        : (isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _pumpOn,
                            activeTrackColor: AppColors.success,
                            onChanged: (val) {
                              setState(() => _pumpOn = val);
                              _dbService.setPump(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  crossFadeState: isAuto
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 350),
                  sizeCurve: Curves.easeInOut,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle(ThemeData theme, bool isDark) {
    final isAuto = _mode == 'AUTO';
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton('Auto', isAuto, () {
            setState(() => _mode = 'AUTO');
            _dbService.setMode('AUTO');
          }, isDark),
          _modeButton('Manual', !isAuto, () {
            setState(() => _mode = 'MANUAL');
            _dbService.setMode('MANUAL');
          }, isDark),
        ],
      ),
    );
  }

  Widget _modeButton(
      String label, bool selected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3 — Water Usage
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWaterUsageSection(ThemeData theme, bool isDark) {
    final weekEntries = _lastWeekUsage();
    final yesterdayLiters = _yesterdayUsage();
    final weekTotal = _lastWeekTotal();
    final maxLiters =
        weekEntries.isEmpty ? 1.0 : weekEntries.map((e) => e.value).reduce(math.max).clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Water Usage',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Yesterday + Week total side by side
        Row(
          children: [
            Expanded(
              child: _usageSummaryCard(
                theme,
                isDark,
                'Yesterday',
                '${yesterdayLiters.toStringAsFixed(0)} L',
                Icons.today_rounded,
                AppColors.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _usageSummaryCard(
                theme,
                isDark,
                'Last 7 Days',
                '${weekTotal.toStringAsFixed(0)} L',
                Icons.date_range_rounded,
                AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Bar chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Breakdown',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: weekEntries.reversed.map((entry) {
                      final fraction = entry.value / maxLiters;
                      final dayLabel = entry.key.substring(8); // dd
                      final monthLabel = entry.key.substring(5, 7); // mm

                      return Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Value label
                              Text(
                                entry.value > 0
                                    ? entry.value.toStringAsFixed(0)
                                    : '-',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Bar
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                height: (100 * fraction).clamp(4.0, 100.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.secondary,
                                      AppColors.secondaryDark,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Day label
                              Text(
                                '$dayLabel/$monthLabel',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark
                                      ? AppColors.darkTextDisabled
                                      : AppColors.lightTextDisabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _usageSummaryCard(
    ThemeData theme,
    bool isDark,
    String title,
    String value,
    IconData icon,
    Color accentColor,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Avatar + Sign-Out popup menu in the AppBar
// ─────────────────────────────────────────────────────────────────────────────

class _UserAvatarMenu extends StatelessWidget {
  const _UserAvatarMenu();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) async {
        if (value == 'signout') {
          await AuthService.instance.signOut();
          // AuthWrapper's StreamBuilder automatically navigates to LoginScreen
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: 10),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary,
          backgroundImage:
              photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
