import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Singleton service for all Firebase Realtime Database interactions.
class DatabaseService {
  DatabaseService._() {
    // Explicitly set the database URL so the SDK always connects to the
    // correct Realtime Database instance (especially needed on Android).
    FirebaseDatabase.instance.databaseURL =
        'https://aquasense-6b25f-default-rtdb.firebaseio.com';
  }
  static final DatabaseService instance = DatabaseService._();

  DatabaseReference get _db => FirebaseDatabase.instance.ref();

  // ─── Controls ───────────────────────────────────────────────────────────────

  /// Stream of the current mode ("AUTO" or "MANUAL").
  Stream<String> get modeStream =>
      _db.child('Controls/mode').onValue.map((event) {
        final val = event.snapshot.value;
        debugPrint('[DB] mode = $val');
        return (val as String?) ?? 'AUTO';
      }).handleError((e) {
        debugPrint('[DB] modeStream error: $e');
      });

  /// Stream of the current pump state (true/false).
  Stream<bool> get pumpStream =>
      _db.child('Controls/pump').onValue.map((event) {
        final val = event.snapshot.value;
        debugPrint('[DB] pump = $val');
        if (val is bool) return val;
        if (val is num) return val == 1;
        if (val is String) {
          final lower = val.trim().toLowerCase();
          return lower == 'true' || lower == '1' || lower == 'on';
        }
        return false;
      }).handleError((e) {
        debugPrint('[DB] pumpStream error: $e');
      });

  /// Set the system mode to "AUTO" or "MANUAL".
  Future<void> setMode(String mode) async {
    try {
      debugPrint('[DB] setMode -> $mode');
      await _db.child('Controls/mode').set(mode);
    } catch (e) {
      debugPrint('[DB] setMode error: $e');
    }
  }

  /// Set the pump state (true/false) (only meaningful in MANUAL mode).
  Future<void> setPump(bool on) async {
    try {
      debugPrint('[DB] setPump -> $on');
      await _db.child('Controls/pump').set(on);
    } catch (e) {
      debugPrint('[DB] setPump error: $e');
    }
  }

  // ─── Percentages ────────────────────────────────────────────────────────────

  /// Stream of tank water level percentage (0–100).
  Stream<double> get tankPercentageStream =>
      _db.child('percentage/tank').onValue.map((event) {
        final val = event.snapshot.value;
        debugPrint('[DB] tank% = $val');
        if (val is num) return val.toDouble();
        return 0.0;
      }).handleError((e) {
        debugPrint('[DB] tankPercentageStream error: $e');
      });

  /// Stream of well water level percentage (0–100).
  Stream<double> get wellPercentageStream =>
      _db.child('percentage/well').onValue.map((event) {
        final val = event.snapshot.value;
        debugPrint('[DB] well% = $val');
        if (val is num) return val.toDouble();
        return 0.0;
      }).handleError((e) {
        debugPrint('[DB] wellPercentageStream error: $e');
      });

  // ─── Water Usage ────────────────────────────────────────────────────────────

  /// Stream of all entries under `WaterUsage/` as a map of date-string → liters.
  Stream<Map<String, double>> get waterUsageStream =>
      _db.child('WaterUsage').onValue.map((event) {
        final val = event.snapshot.value;
        debugPrint('[DB] WaterUsage value = $val');
        final result = <String, double>{};
        if (val is Map) {
          final data = Map<String, dynamic>.from(val);
          for (final entry in data.entries) {
            if (entry.value is Map) {
              final dayData = Map<String, dynamic>.from(entry.value as Map);
              final liters = dayData['liters'];
              if (liters is num) {
                result[entry.key] = liters.toDouble();
              }
            }
          }
        }
        return result;
      }).handleError((e) {
        debugPrint('[DB] waterUsageStream error: $e');
      });

  /// Fetches all entries under `WaterUsage/` and returns them as a map
  /// of date-string → liters.
  Future<Map<String, double>> fetchWaterUsage() async {
    try {
      final snapshot = await _db.child('WaterUsage').get();
      debugPrint('[DB] WaterUsage exists = ${snapshot.exists}');
      final result = <String, double>{};
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        for (final entry in data.entries) {
          if (entry.value is Map) {
            final dayData = Map<String, dynamic>.from(entry.value as Map);
            final liters = dayData['liters'];
            if (liters is num) {
              result[entry.key] = liters.toDouble();
            }
          }
        }
      }
      debugPrint('[DB] WaterUsage parsed: $result');
      return result;
    } catch (e) {
      debugPrint('[DB] fetchWaterUsage error: $e');
      return {};
    }
  }

  // ─── Configuration ──────────────────────────────────────────────────────────

  /// Stream of all configuration data from Firebase.
  Stream<Map<String, dynamic>> get configurationStream =>
      _db.child('Configuration').onValue.map<Map<String, dynamic>>((event) {
        final val = event.snapshot.value;
        debugPrint('[DB] Configuration value = $val');
        if (val is Map) {
          return Map<String, dynamic>.from(val);
        }
        return <String, dynamic>{};
      }).handleError((e) {
        debugPrint('[DB] configurationStream error: $e');
      });

  /// Updates the tank configuration in Firebase.
  Future<void> updateTankConfiguration({
    required double emptyDistance,
    required double fullDistance,
    required double criticalLow,
    required double radius,
  }) async {
    try {
      debugPrint('[DB] updateTankConfiguration -> $emptyDistance, $fullDistance, $criticalLow, $radius');
      await _db.child('Configuration/tank').set({
        'emptyDistance': emptyDistance,
        'fullDistance': fullDistance,
        'criticalLow': criticalLow,
        'radius': radius,
      });
    } catch (e) {
      debugPrint('[DB] updateTankConfiguration error: $e');
      rethrow;
    }
  }

  /// Updates the well configuration in Firebase.
  Future<void> updateWellConfiguration({
    required double emptyDistance,
    required double fullDistance,
    required double criticalLow,
    required double radius,
  }) async {
    try {
      debugPrint('[DB] updateWellConfiguration -> $emptyDistance, $fullDistance, $criticalLow, $radius');
      await _db.child('Configuration/well').set({
        'emptyDistance': emptyDistance,
        'fullDistance': fullDistance,
        'criticalLow': criticalLow,
        'radius': radius,
      });
    } catch (e) {
      debugPrint('[DB] updateWellConfiguration error: $e');
      rethrow;
    }
  }
}
