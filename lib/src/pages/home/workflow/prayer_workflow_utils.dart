import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/WorkFlowWidget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for generating WorkFlowItems for live broadcast during prayers
class PrayerWorkflowUtils {
  /// Prayer indices
  static const int prayerFajr = 0;
  static const int prayerDhuhr = 1;
  static const int prayerAsr = 2;
  static const int prayerMaghrib = 3;
  static const int prayerIsha = 4;

  /// Get the live broadcast duration for a specific prayer from SharedPreferences
  /// Returns the duration in minutes, or null if not enabled
  static Future<int?> getLiveDurationForPrayer(int prayerIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final enableDaily = prefs.getBool(LiveStreamConstants.prefKeyEnableDaily) ?? false;

    if (!enableDaily) return null;

    switch (prayerIndex) {
      case prayerFajr:
        return prefs.getInt(LiveStreamConstants.prefKeyDurationFajr) ?? LiveStreamConstants.defaultDurationFajr;
      case prayerDhuhr:
        return prefs.getInt(LiveStreamConstants.prefKeyDurationDhuhr) ?? LiveStreamConstants.defaultDurationDhuhr;
      case prayerAsr:
        return prefs.getInt(LiveStreamConstants.prefKeyDurationAsr) ?? LiveStreamConstants.defaultDurationAsr;
      case prayerMaghrib:
        return prefs.getInt(LiveStreamConstants.prefKeyDurationMaghrib) ?? LiveStreamConstants.defaultDurationMaghrib;
      case prayerIsha:
        return prefs.getInt(LiveStreamConstants.prefKeyDurationIsha) ?? LiveStreamConstants.defaultDurationIsha;
      default:
        return null;
    }
  }

  /// Get the live broadcast duration for Jumua from SharedPreferences
  /// Returns the duration in minutes, or null if not enabled
  static Future<int?> getLiveDurationForJumua() async {
    final prefs = await SharedPreferences.getInstance();
    final enableJumua = prefs.getBool(LiveStreamConstants.prefKeyEnableJumua) ?? false;

    if (!enableJumua) return null;

    return prefs.getInt(LiveStreamConstants.prefKeyDurationJumua) ?? LiveStreamConstants.defaultDurationJumua;
  }

  /// Get the live broadcast duration for Aid from SharedPreferences
  /// Returns the duration in minutes, or null if not enabled
  static Future<int?> getLiveDurationForAid() async {
    final prefs = await SharedPreferences.getInstance();
    final enableAid = prefs.getBool(LiveStreamConstants.prefKeyEnableAid) ?? false;

    if (!enableAid) return null;

    return prefs.getInt(LiveStreamConstants.prefKeyDurationAid) ?? LiveStreamConstants.defaultDurationAid;
  }

  /// Check if live broadcast is enabled for daily prayers
  static Future<bool> isDailyLiveEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(LiveStreamConstants.prefKeyEnableDaily) ?? false;
  }

  /// Check if live broadcast is enabled for Jumua
  static Future<bool> isJumuaLiveEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(LiveStreamConstants.prefKeyEnableJumua) ?? false;
  }

  /// Check if live broadcast is enabled for Aid
  static Future<bool> isAidLiveEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(LiveStreamConstants.prefKeyEnableAid) ?? false;
  }

  /// Get the start time for a prayer live broadcast
  /// If duration is 0, returns the Adhan time (actualTimes)
  /// Otherwise, returns the Iqama time (actualIqamaTimes)
  static DateTime getLiveStartTime(MosqueManager mosqueManager, int prayerIndex, int duration) {
    if (duration == 0) {
      // Trigger at Adhan time
      dev.log('📺 [PRAYER_WORKFLOW] Prayer $prayerIndex: Duration is 0, using Adhan time');
      return mosqueManager.actualTimes()[prayerIndex];
    } else {
      // Trigger at Iqama time
      dev.log('📺 [PRAYER_WORKFLOW] Prayer $prayerIndex: Duration is $duration min, using Iqama time');
      return mosqueManager.actualIqamaTimes()[prayerIndex];
    }
  }

  /// Generate a WorkFlowItem for live broadcasting a prayer
  /// 
  /// Parameters:
  /// - mosqueManager: The MosqueManager instance for prayer times
  /// - prayerIndex: The index of the prayer (0-4 for Fajr-Isha)
  /// - duration: The broadcast duration in minutes
  /// - liveStreamBuilder: A function that builds the live stream widget
  /// - onDone: Callback when the workflow item is complete
  /// 
  /// Returns a WorkFlowItem configured for live broadcasting
  static WorkFlowItem generateLiveWorkflowItem({
    required MosqueManager mosqueManager,
    required int prayerIndex,
    required int duration,
    required Widget Function(BuildContext context, VoidCallback next) liveStreamBuilder,
  }) {
    final now = mosqueManager.mosqueDate();
    final startTime = getLiveStartTime(mosqueManager, prayerIndex, duration);
    // Use fallback duration when duration is 0 (Adhan trigger mode)
    final effectiveDuration = duration > 0 ? duration : LiveStreamConstants.fallbackDurationForAdhanTrigger;
    final endTime = startTime.add(Duration(minutes: effectiveDuration));

    dev.log('📺 [PRAYER_WORKFLOW] Generating WorkFlowItem for prayer $prayerIndex');
    dev.log('📺 [PRAYER_WORKFLOW] Start: $startTime, Duration: $effectiveDuration min, End: $endTime');

    return WorkFlowItem(
      builder: liveStreamBuilder,
      duration: Duration(minutes: effectiveDuration),
      skip: now.isAfter(endTime),
    );
  }

  /// Generate a WorkFlowItem for Jumua live broadcasting
  static WorkFlowItem generateJumuaLiveWorkflowItem({
    required MosqueManager mosqueManager,
    required int duration,
    required Widget Function(BuildContext context, VoidCallback next) liveStreamBuilder,
  }) {
    final now = mosqueManager.mosqueDate();
    final jumuaTime = mosqueManager.activeJumuaaDate();
    final endTime = jumuaTime.add(Duration(minutes: duration));

    dev.log('📺 [PRAYER_WORKFLOW] Generating Jumua WorkFlowItem');
    dev.log('📺 [PRAYER_WORKFLOW] Jumua Start: $jumuaTime, Duration: $duration min, End: $endTime');

    return WorkFlowItem(
      builder: liveStreamBuilder,
      duration: Duration(minutes: duration),
      skip: now.isAfter(endTime),
      disabled: now.weekday != DateTime.friday,
    );
  }

  /// Get all live broadcast settings at once
  static Future<LiveBroadcastSettings> getAllSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return LiveBroadcastSettings(
      enableDaily: prefs.getBool(LiveStreamConstants.prefKeyEnableDaily) ?? false,
      enableJumua: prefs.getBool(LiveStreamConstants.prefKeyEnableJumua) ?? false,
      enableAid: prefs.getBool(LiveStreamConstants.prefKeyEnableAid) ?? false,
      durationFajr: prefs.getInt(LiveStreamConstants.prefKeyDurationFajr) ?? LiveStreamConstants.defaultDurationFajr,
      durationDhuhr: prefs.getInt(LiveStreamConstants.prefKeyDurationDhuhr) ?? LiveStreamConstants.defaultDurationDhuhr,
      durationAsr: prefs.getInt(LiveStreamConstants.prefKeyDurationAsr) ?? LiveStreamConstants.defaultDurationAsr,
      durationMaghrib:
          prefs.getInt(LiveStreamConstants.prefKeyDurationMaghrib) ?? LiveStreamConstants.defaultDurationMaghrib,
      durationIsha: prefs.getInt(LiveStreamConstants.prefKeyDurationIsha) ?? LiveStreamConstants.defaultDurationIsha,
      durationJumua: prefs.getInt(LiveStreamConstants.prefKeyDurationJumua) ?? LiveStreamConstants.defaultDurationJumua,
      durationAid: prefs.getInt(LiveStreamConstants.prefKeyDurationAid) ?? LiveStreamConstants.defaultDurationAid,
    );
  }
}

/// Data class to hold all live broadcast settings
class LiveBroadcastSettings {
  final bool enableDaily;
  final bool enableJumua;
  final bool enableAid;
  final int durationFajr;
  final int durationDhuhr;
  final int durationAsr;
  final int durationMaghrib;
  final int durationIsha;
  final int durationJumua;
  final int durationAid;

  const LiveBroadcastSettings({
    required this.enableDaily,
    required this.enableJumua,
    required this.enableAid,
    required this.durationFajr,
    required this.durationDhuhr,
    required this.durationAsr,
    required this.durationMaghrib,
    required this.durationIsha,
    required this.durationJumua,
    required this.durationAid,
  });

  /// Get the duration for a specific prayer index
  int getDurationForPrayer(int prayerIndex) {
    switch (prayerIndex) {
      case PrayerWorkflowUtils.prayerFajr:
        return durationFajr;
      case PrayerWorkflowUtils.prayerDhuhr:
        return durationDhuhr;
      case PrayerWorkflowUtils.prayerAsr:
        return durationAsr;
      case PrayerWorkflowUtils.prayerMaghrib:
        return durationMaghrib;
      case PrayerWorkflowUtils.prayerIsha:
        return durationIsha;
      default:
        return 0;
    }
  }

  /// Check if a specific prayer should use Adhan time (duration == 0)
  bool shouldUseAdhanTime(int prayerIndex) {
    return getDurationForPrayer(prayerIndex) == 0;
  }

  @override
  String toString() {
    return 'LiveBroadcastSettings('
        'enableDaily: $enableDaily, '
        'enableJumua: $enableJumua, '
        'enableAid: $enableAid, '
        'fajr: $durationFajr, '
        'dhuhr: $durationDhuhr, '
        'asr: $durationAsr, '
        'maghrib: $durationMaghrib, '
        'isha: $durationIsha, '
        'jumua: $durationJumua, '
        'aid: $durationAid'
        ')';
  }
}
