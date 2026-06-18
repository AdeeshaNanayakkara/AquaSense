import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../core/services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dbService = DatabaseService.instance;
  StreamSubscription? _configSubscription;

  // Controllers for Tank
  final _tankEmptyCtrl = TextEditingController();
  final _tankFullCtrl = TextEditingController();
  final _tankCritCtrl = TextEditingController();
  final _tankRadiusCtrl = TextEditingController();

  // Controllers for Well
  final _wellEmptyCtrl = TextEditingController();
  final _wellFullCtrl = TextEditingController();
  final _wellCritCtrl = TextEditingController();
  final _wellRadiusCtrl = TextEditingController();

  // Form Keys for validation
  final _tankFormKey = GlobalKey<FormState>();
  final _wellFormKey = GlobalKey<FormState>();

  bool _isLoading = false;

  // Track if fields have been manually edited (to prevent overwrite from stream)
  bool _tankEdited = false;
  bool _wellEdited = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Re-trigger setState to update UI diagrams when tab changes
      setState(() {});
    });

    // Listen to configuration data in real-time
    _configSubscription = _dbService.configurationStream.listen((data) {
      if (!mounted) return;
      setState(() {
        // Populate tank if not edited by user
        if (!_tankEdited && data['tank'] != null) {
          final tank = data['tank'] as Map;
          _tankEmptyCtrl.text = (tank['emptyDistance'] ?? 100).toString();
          _tankFullCtrl.text = (tank['fullDistance'] ?? 10).toString();
          _tankCritCtrl.text = (tank['criticalLow'] ?? 80).toString();
          _tankRadiusCtrl.text = (tank['radius'] ?? 50).toString();
        }

        // Populate well if not edited by user
        if (!_wellEdited && data['well'] != null) {
          final well = data['well'] as Map;
          _wellEmptyCtrl.text = (well['emptyDistance'] ?? 200).toString();
          _wellFullCtrl.text = (well['fullDistance'] ?? 20).toString();
          _wellCritCtrl.text = (well['criticalLow'] ?? 150).toString();
          _wellRadiusCtrl.text = (well['radius'] ?? 60).toString();
        }
      });
    }, onError: (e) {
      debugPrint('[SETTINGS] Stream error: $e');
    });
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _tabController.dispose();
    _tankEmptyCtrl.dispose();
    _tankFullCtrl.dispose();
    _tankCritCtrl.dispose();
    _tankRadiusCtrl.dispose();
    _wellEmptyCtrl.dispose();
    _wellFullCtrl.dispose();
    _wellCritCtrl.dispose();
    _wellRadiusCtrl.dispose();
    super.dispose();
  }

  // ─── Save Handlers ──────────────────────────────────────────────────────────

  Future<void> _saveSettings(bool isTank) async {
    final formKey = isTank ? _tankFormKey : _wellFormKey;
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isTank) {
        final empty = double.parse(_tankEmptyCtrl.text);
        final full = double.parse(_tankFullCtrl.text);
        final crit = double.parse(_tankCritCtrl.text);
        final rad = double.parse(_tankRadiusCtrl.text);

        await _dbService.updateTankConfiguration(
          emptyDistance: empty,
          fullDistance: full,
          criticalLow: crit,
          radius: rad,
        );
        setState(() => _tankEdited = false);
      } else {
        final empty = double.parse(_wellEmptyCtrl.text);
        final full = double.parse(_wellFullCtrl.text);
        final crit = double.parse(_wellCritCtrl.text);
        final rad = double.parse(_wellRadiusCtrl.text);

        await _dbService.updateWellConfiguration(
          emptyDistance: empty,
          fullDistance: full,
          criticalLow: crit,
          radius: rad,
        );
        setState(() => _wellEdited = false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('${isTank ? "Tank" : "Well"} settings saved successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to save settings: $e'),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Diagram Helper Values ──────────────────────────────────────────────────

  double _getSafeDouble(String text, double defaultValue) {
    if (text.isEmpty) return defaultValue;
    return double.tryParse(text) ?? defaultValue;
  }

  // ─── Build Method ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'System Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.md - 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'Water Tank'),
                Tab(text: 'Well'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSettingsTab(true, theme, isDark),
          _buildSettingsTab(false, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(bool isTank, ThemeData theme, bool isDark) {
    final formKey = isTank ? _tankFormKey : _wellFormKey;
    final emptyCtrl = isTank ? _tankEmptyCtrl : _wellEmptyCtrl;
    final fullCtrl = isTank ? _tankFullCtrl : _wellFullCtrl;
    final critCtrl = isTank ? _tankCritCtrl : _wellCritCtrl;
    final radiusCtrl = isTank ? _tankRadiusCtrl : _wellRadiusCtrl;

    // Fetch dynamic values for visual preview
    final emptyVal = _getSafeDouble(emptyCtrl.text, isTank ? 100 : 200);
    final fullVal = _getSafeDouble(fullCtrl.text, isTank ? 10 : 20);
    final critVal = _getSafeDouble(critCtrl.text, isTank ? 80 : 150);
    final radiusVal = _getSafeDouble(radiusCtrl.text, isTank ? 50 : 60);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dynamic Graphical Diagram Card
            _buildDiagramCard(isTank, emptyVal, fullVal, critVal, radiusVal, theme, isDark),
            const SizedBox(height: AppSpacing.md),

            // Form Inputs Card
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isTank ? Icons.waves_rounded : Icons.opacity_rounded,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${isTank ? "Tank" : "Well"} Dimensions (cm)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.lg),

                    // Empty Distance Input
                    _buildInputField(
                      controller: emptyCtrl,
                      label: 'Empty Distance',
                      description: 'Distance from the sensor to the container bottom (represents 0% level).',
                      icon: Icons.vertical_align_bottom_rounded,
                      isDark: isDark,
                      onChanged: (val) {
                        setState(() {
                          if (isTank) {
                            _tankEdited = true;
                          } else {
                            _wellEdited = true;
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter empty distance';
                        }
                        final val = double.tryParse(value);
                        if (val == null || val <= 0) {
                          return 'Enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Full Distance Input
                    _buildInputField(
                      controller: fullCtrl,
                      label: 'Full Distance',
                      description: 'Distance from the sensor to maximum water height (represents 100% level).',
                      icon: Icons.vertical_align_top_rounded,
                      isDark: isDark,
                      onChanged: (val) {
                        setState(() {
                          if (isTank) {
                            _tankEdited = true;
                          } else {
                            _wellEdited = true;
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter full distance';
                        }
                        final val = double.tryParse(value);
                        if (val == null || val <= 0) {
                          return 'Enter a valid positive number';
                        }
                        final empty = double.tryParse(emptyCtrl.text) ?? double.infinity;
                        if (val >= empty) {
                          return 'Must be less than empty distance ($empty cm)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Critical Low Input
                    _buildInputField(
                      controller: critCtrl,
                      label: 'Critical Low Threshold',
                      description: 'Distance threshold from sensor when alert triggers (must be below normal levels).',
                      icon: Icons.error_outline_rounded,
                      isDark: isDark,
                      onChanged: (val) {
                        setState(() {
                          if (isTank) {
                            _tankEdited = true;
                          } else {
                            _wellEdited = true;
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter critical threshold';
                        }
                        final val = double.tryParse(value);
                        if (val == null || val <= 0) {
                          return 'Enter a valid positive number';
                        }
                        final empty = double.tryParse(emptyCtrl.text) ?? double.infinity;
                        final full = double.tryParse(fullCtrl.text) ?? 0.0;
                        if (val >= empty) {
                          return 'Must be less than empty distance ($empty cm)';
                        }
                        if (val <= full) {
                          return 'Must be greater than full distance ($full cm)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Radius Input
                    _buildInputField(
                      controller: radiusCtrl,
                      label: 'Container Radius',
                      description: 'Internal radius of the cylindrical container (used for accurate volume math).',
                      icon: Icons.blur_circular_rounded,
                      isDark: isDark,
                      onChanged: (val) {
                        setState(() {
                          if (isTank) {
                            _tankEdited = true;
                          } else {
                            _wellEdited = true;
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter container radius';
                        }
                        final val = double.tryParse(value);
                        if (val == null || val <= 0) {
                          return 'Enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : () => _saveSettings(isTank),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                elevation: 3,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      'Save ${isTank ? "Tank" : "Well"} Configuration',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ─── Input Field Builder ────────────────────────────────────────────────────

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String description,
    required IconData icon,
    required bool isDark,
    required FormFieldValidator<String> validator,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
            suffixText: 'cm',
            suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Graphical Diagram Card ─────────────────────────────────────────────────

  Widget _buildDiagramCard(
    bool isTank,
    double emptyVal,
    double fullVal,
    double critVal,
    double radiusVal,
    ThemeData theme,
    bool isDark,
  ) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visual Parameter Meanings',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hover lines to see values in centimeters (cm) relative to the sensor.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Canvas drawing diagram
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CustomPaint(
                  painter: ConfigDiagramPainter(
                    emptyDistance: emptyVal,
                    fullDistance: fullVal,
                    criticalLow: critVal,
                    radiusDistance: radiusVal,
                    isWell: !isTank,
                    isDarkTheme: isDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Painter for Parameter Illustration ───────────────────────────────

class ConfigDiagramPainter extends CustomPainter {
  final double emptyDistance;
  final double fullDistance;
  final double criticalLow;
  final double radiusDistance;
  final bool isWell;
  final bool isDarkTheme;

  ConfigDiagramPainter({
    required this.emptyDistance,
    required this.fullDistance,
    required this.criticalLow,
    required this.radiusDistance,
    required this.isWell,
    required this.isDarkTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Define coordinate bounds for container drawing
    // We will place the graphic in the center-left and labels on the right
    final containerLeft = w * 0.15;
    final containerRight = w * 0.55;
    final containerWidth = containerRight - containerLeft;
    final containerTop = h * 0.18;
    final containerBottom = h * 0.85;
    final containerHeight = containerBottom - containerTop;

    final linePaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final containerPaint = Paint()
      ..color = isDarkTheme ? AppColors.darkBorder : AppColors.lightBorder.withValues(alpha: 0.8)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // ─── 1. Draw Tank or Well Structure ───────────────────────────────────────
    if (isWell) {
      // Well is drawn as a deep vertical shaft
      final path = Path()
        ..moveTo(containerLeft, containerTop - 15)
        ..lineTo(containerLeft, containerBottom)
        ..lineTo(containerRight, containerBottom)
        ..lineTo(containerRight, containerTop - 15);
      canvas.drawPath(path, containerPaint);

      // Well bricks/shading lines for aesthetics
      final brickPaint = Paint()
        ..color = (isDarkTheme ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.3)
        ..strokeWidth = 1.0;
      for (double y = containerTop; y < containerBottom; y += 25) {
        canvas.drawLine(Offset(containerLeft, y), Offset(containerLeft - 8, y), brickPaint);
        canvas.drawLine(Offset(containerRight, y), Offset(containerRight + 8, y), brickPaint);
      }
    } else {
      // Tank is drawn as a cylinder shape (rounded top/bottom)
      final rect = Rect.fromLTRB(containerLeft, containerTop, containerRight, containerBottom);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.lg));
      canvas.drawRRect(rrect, containerPaint);

      // Tank top lid detail
      final lidPaint = Paint()
        ..color = isDarkTheme ? AppColors.darkBorder : AppColors.lightBorder
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(containerLeft + containerWidth * 0.35, containerTop - 5,
            containerLeft + containerWidth * 0.65, containerTop),
        lidPaint,
      );
    }

    // ─── 2. Draw Sensor Icon at Top ──────────────────────────────────────────
    final sensorX = containerLeft + containerWidth / 2;
    final sensorY = containerTop;

    final sensorBasePaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;
    
    // Draw sensor block
    canvas.drawCircle(Offset(sensorX, sensorY), 6.0, sensorBasePaint);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(sensorX, sensorY - 4), width: 14, height: 6),
      sensorBasePaint,
    );

    // Draw sensor wave lines (ultrasonic waves going down)
    final wavePaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawArc(Rect.fromCircle(center: Offset(sensorX, sensorY + 8), radius: 6),
        0.2, 2.8, false, wavePaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(sensorX, sensorY + 14), radius: 10),
        0.4, 2.4, false, wavePaint);

    // ─── 3. Draw Water fill preview representation ────────────────────────────
    // We assume emptyDistance is the bottom, and fullDistance is the top.
    // Critical Low lies somewhere in between.
    // Let's map these to heights in the diagram:
    // emptyDistance maps to containerBottom
    // fullDistance maps to containerTop + 20 (we leave some space below sensor)
    
    final fullY = containerTop + containerHeight * 0.20;
    final emptyY = containerBottom;

    // Critical low maps proportionally between fullDistance and emptyDistance
    // Avoid division by zero
    final range = emptyDistance - fullDistance;
    final double critY;
    if (range <= 0) {
      critY = containerTop + containerHeight * 0.70;
    } else {
      final ratio = (criticalLow - fullDistance) / range;
      critY = fullY + (emptyY - fullY) * ratio.clamp(0.0, 1.0);
    }

    // Fill water up to critical low level as semi-transparent blue
    final waterPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    if (isWell) {
      canvas.drawRect(
        Rect.fromLTRB(containerLeft + 1.5, critY, containerRight - 1.5, containerBottom - 1.5),
        waterPaint,
      );
    } else {
      // Clip to fit cylinder RRect
      canvas.save();
      final rect = Rect.fromLTRB(containerLeft, containerTop, containerRight, containerBottom);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.lg));
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTRB(containerLeft, critY, containerRight, containerBottom),
        waterPaint,
      );
      canvas.restore();
    }

    // ─── 4. Horizontal Marker Lines ──────────────────────────────────────────
    // Sensor Line (Top Reference)
    linePaint.color = isDarkTheme ? Colors.white30 : Colors.black26;
    linePaint.strokeWidth = 1.0;
    _drawDashedLine(canvas, Offset(containerLeft - 10, containerTop), Offset(containerRight + 25, containerTop), linePaint);
    _drawLabel(canvas, "Sensor Level (0 cm)", Offset(containerRight + 30, containerTop - 6), isDarkTheme ? Colors.white70 : Colors.black54, 9, false);

    // Full Level Line (100% Water)
    linePaint.color = AppColors.success;
    linePaint.strokeWidth = 1.5;
    _drawDashedLine(canvas, Offset(containerLeft - 10, fullY), Offset(containerRight + 25, fullY), linePaint);
    _drawLabel(canvas, "Full Level (100%)", Offset(containerRight + 30, fullY - 6), AppColors.success, 10, true);

    // Critical Low Line
    linePaint.color = AppColors.error;
    linePaint.strokeWidth = 1.5;
    _drawDashedLine(canvas, Offset(containerLeft - 10, critY), Offset(containerRight + 25, critY), linePaint);
    _drawLabel(canvas, "Critical Low Threshold", Offset(containerRight + 30, critY - 6), AppColors.error, 10, true);

    // Bottom Level Line (0% Water)
    linePaint.color = isDarkTheme ? Colors.white38 : Colors.black38;
    linePaint.strokeWidth = 1.2;
    _drawDashedLine(canvas, Offset(containerLeft - 10, containerBottom), Offset(containerRight + 25, containerBottom), linePaint);
    _drawLabel(canvas, "Bottom (0% Water)", Offset(containerRight + 30, containerBottom - 6), isDarkTheme ? Colors.white70 : Colors.black54, 9, false);

    // ─── 5. Measurement Bracket Arrows on the Left Side ──────────────────────
    final arrowX = containerLeft - 30;
    final arrowPaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // A. Full Distance Bracket (Sensor -> Full Level)
    _drawArrow(canvas, Offset(arrowX, containerTop), Offset(arrowX, fullY), arrowPaint);
    _drawLabel(canvas, "Full Dist: ${fullDistance.toStringAsFixed(0)} cm", Offset(arrowX - 8, (containerTop + fullY) / 2 - 6), AppColors.secondary, 9, true, alignRight: true);

    // B. Critical Low Bracket (Sensor -> Critical Low)
    final critArrowX = containerLeft - 65;
    _drawArrow(canvas, Offset(critArrowX, containerTop), Offset(critArrowX, critY), arrowPaint);
    _drawLabel(canvas, "Crit Low: ${criticalLow.toStringAsFixed(0)} cm", Offset(critArrowX - 8, (containerTop + critY) / 2 - 6), AppColors.secondary, 9, true, alignRight: true);

    // C. Empty Distance Bracket (Sensor -> Bottom)
    final emptyArrowX = containerLeft - 100;
    _drawArrow(canvas, Offset(emptyArrowX, containerTop), Offset(emptyArrowX, containerBottom), arrowPaint);
    _drawLabel(canvas, "Empty Dist: ${emptyDistance.toStringAsFixed(0)} cm", Offset(emptyArrowX - 8, (containerTop + containerBottom) / 2 - 6), AppColors.secondary, 9, true, alignRight: true);

    // D. Radius Bracket (Center bottom -> Right bottom)
    final radiusY = containerBottom + 18;
    final centerBottomX = containerLeft + containerWidth / 2;
    final rArrowPaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    
    // Draw horizontal line from center to right
    canvas.drawLine(Offset(centerBottomX, radiusY), Offset(containerRight, radiusY), rArrowPaint);
    // Draw end caps
    canvas.drawLine(Offset(centerBottomX, radiusY - 3), Offset(centerBottomX, radiusY + 3), rArrowPaint);
    canvas.drawLine(Offset(containerRight, radiusY - 3), Offset(containerRight, radiusY + 3), rArrowPaint);
    // Draw label
    _drawLabel(canvas, "Radius: ${radiusDistance.toStringAsFixed(0)} cm", Offset(centerBottomX + 4, radiusY - 5), AppColors.secondary, 8, true);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = p1.dx;
    final double endX = p2.dx;

    while (startX < endX) {
      canvas.drawLine(
        Offset(startX, p1.dy),
        Offset((startX + dashWidth).clamp(startX, endX), p1.dy),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  void _drawArrow(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    // Draw vertical connector line
    canvas.drawLine(p1, p2, paint);

    // Draw horizontal caps at top and bottom
    canvas.drawLine(Offset(p1.dx - 4, p1.dy), Offset(p1.dx + 4, p1.dy), paint);
    canvas.drawLine(Offset(p2.dx - 4, p2.dy), Offset(p2.dx + 4, p2.dy), paint);

    // Draw arrowheads pointing out/in
    final arrowSize = 4.0;
    // Top arrow head
    canvas.drawLine(p1, Offset(p1.dx - arrowSize, p1.dy + arrowSize), paint);
    canvas.drawLine(p1, Offset(p1.dx + arrowSize, p1.dy + arrowSize), paint);
    // Bottom arrow head
    canvas.drawLine(p2, Offset(p2.dx - arrowSize, p2.dy - arrowSize), paint);
    canvas.drawLine(p2, Offset(p2.dx + arrowSize, p2.dy - arrowSize), paint);
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize,
    bool bold, {
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final x = alignRight ? offset.dx - tp.width : offset.dx;
    tp.paint(canvas, Offset(x, offset.dy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
