import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isPumpActive = false;
  double _waterLevel = 72.5; // Dummy percentage

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                color: theme.brightness == Brightness.dark 
                    ? AppColors.darkTextPrimary 
                    : AppColors.primary,
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
              'Hello, User!',
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

            // Tank Level Visualizer Card (Major visual asset)
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MAIN TANK LEVEL',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_waterLevel.toStringAsFixed(1)}%',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Approx. 1,450 Liters remaining',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.secondaryLight,
                              ),
                            ),
                          ],
                        ),
                        // Circular Water Level indicator
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 70,
                                height: 70,
                                child: CircularProgressIndicator(
                                  value: _waterLevel / 100,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.secondaryLight,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.opacity_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Quick stats within card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCardStat('Daily Usage', '124L', Icons.insights_rounded),
                          Container(width: 1, height: 24, color: Colors.white12),
                          _buildCardStat('Quality Index', 'Optimal', Icons.check_circle_outline_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Controls Section Title
            Text(
              'System Controls',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Pump Controller Item
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isPumpActive 
                        ? AppColors.secondary.withValues(alpha: 0.15) 
                        : Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings_input_component_rounded,
                    color: _isPumpActive ? AppColors.secondary : Colors.grey,
                  ),
                ),
                title: const Text(
                  'Water Inflow Pump',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_isPumpActive ? 'Status: Active and filling' : 'Status: Standby'),
                trailing: Switch.adaptive(
                  value: _isPumpActive,
                  activeTrackColor: AppColors.secondary,
                  onChanged: (value) {
                    setState(() {
                      _isPumpActive = value;
                      if (_isPumpActive) {
                        // Simulate water filling
                        _simulateFilling();
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Grid of telemetry values
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.4,
              children: [
                _buildTelemetryCard(
                  theme,
                  'Water Temp',
                  '24.8°C',
                  Icons.thermostat_rounded,
                  AppColors.secondary,
                ),
                _buildTelemetryCard(
                  theme,
                  'pH Level',
                  '7.2 pH',
                  Icons.science_outlined,
                  Colors.green.shade400,
                ),
                _buildTelemetryCard(
                  theme,
                  'Total Outflow',
                  '480 L/d',
                  Icons.trending_down_rounded,
                  Colors.orange.shade400,
                ),
                _buildTelemetryCard(
                  theme,
                  'TDS Value',
                  '180 ppm',
                  Icons.water_rounded,
                  Colors.purple.shade400,
                ),
              ],
            ),
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

  Widget _buildCardStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondaryLight, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetryCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: color, size: 22),
              ],
            ),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.dark 
                    ? AppColors.darkTextPrimary 
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _simulateFilling() {
    if (!_isPumpActive) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (_isPumpActive && _waterLevel < 100.0 && mounted) {
        setState(() {
          _waterLevel = (_waterLevel + 0.8).clamp(0.0, 100.0);
        });
        _simulateFilling();
      }
    });
  }
}
