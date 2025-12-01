import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/repeating_workflow_widget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for creating prayer live workflow items
class PrayerWorkflowUtils {
  /// Creates a list of RepeatingWorkflowItem for prayer live streaming.
  ///
  /// Parameters:
  /// - [prayerKey]: The key for the prayer (e.g., 'fajr', 'dhuhr', 'jumua', 'aid')
  /// - [label]: A human-readable label for the prayer (used for debug purposes)
  /// - [getOccurrences]: A function that returns a list of DateTime occurrences for this prayer
  /// - [mosqueManager]: The MosqueManager instance to get prayer times
  /// - [defaultMinutes]: The default duration in minutes if not found in preferences
  /// - [liveStreamBuilder]: The widget builder function that creates the live stream UI
  ///
  /// Returns a Future that resolves to a list of RepeatingWorkflowItem objects.
  ///
  /// If the duration is 0, the workflow triggers on ADHAN (actualTimes) instead of IQAMA (actualIqamaTimes).
  static Future<List<RepeatingWorkflowItem>> makePrayerLiveWorkFlowItems({
    required String prayerKey,
    required String label,
    required List<DateTime> Function(MosqueManager mosqueManager) getOccurrences,
    required MosqueManager mosqueManager,
    required int defaultMinutes,
    required Widget Function(BuildContext context, VoidCallback next) liveStreamBuilder,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Get the duration from preferences
    final durationKey = _getDurationKey(prayerKey);
    final durationMinutes = prefs.getInt(durationKey) ?? defaultMinutes;

    // Check if this prayer type is enabled
    final enableKey = _getEnableKey(prayerKey);
    final isEnabled = prefs.getBool(enableKey) ?? false;

    if (!isEnabled) {
      return [];
    }

    final occurrences = getOccurrences(mosqueManager);
    final List<RepeatingWorkflowItem> items = [];

    for (int i = 0; i < occurrences.length; i++) {
      final occurrence = occurrences[i];

      items.add(
        RepeatingWorkflowItem(
          debugName: '${prayerKey.toUpperCase()} Live Stream $i',
          builder: liveStreamBuilder,
          dateTime: occurrence,
          duration: durationMinutes > 0 ? Duration(minutes: durationMinutes) : null,
          repeatingDuration: _getRepeatingDuration(prayerKey),
          showInitial: () {
            final now = mosqueManager.mosqueDate();
            if (now.isBefore(occurrence)) return false;

            // Check if we're still within the duration window
            final endTime = occurrence.add(Duration(minutes: durationMinutes > 0 ? durationMinutes : 30));
            return now.isBefore(endTime);
          },
        ),
      );
    }

    return items;
  }

  /// Get the SharedPreferences key for the duration based on prayer key
  static String _getDurationKey(String prayerKey) {
    switch (prayerKey.toLowerCase()) {
      case 'fajr':
        return LiveStreamConstants.prefKeyLiveDurationFajr;
      case 'dhuhr':
        return LiveStreamConstants.prefKeyLiveDurationDhuhr;
      case 'asr':
        return LiveStreamConstants.prefKeyLiveDurationAsr;
      case 'maghrib':
        return LiveStreamConstants.prefKeyLiveDurationMaghrib;
      case 'isha':
        return LiveStreamConstants.prefKeyLiveDurationIsha;
      case 'jumua':
        return LiveStreamConstants.prefKeyLiveDurationJumua;
      case 'aid':
        return LiveStreamConstants.prefKeyLiveDurationAid;
      default:
        return LiveStreamConstants.prefKeyLiveDurationFajr;
    }
  }

  /// Get the SharedPreferences key for the enable switch based on prayer key
  static String _getEnableKey(String prayerKey) {
    switch (prayerKey.toLowerCase()) {
      case 'fajr':
      case 'dhuhr':
      case 'asr':
      case 'maghrib':
      case 'isha':
        return LiveStreamConstants.prefKeyLiveEnableDaily;
      case 'jumua':
        return LiveStreamConstants.prefKeyLiveEnableJumua;
      case 'aid':
        return LiveStreamConstants.prefKeyLiveEnableAid;
      default:
        return LiveStreamConstants.prefKeyLiveEnableDaily;
    }
  }

  /// Get the repeating duration for a prayer type
  static Duration _getRepeatingDuration(String prayerKey) {
    switch (prayerKey.toLowerCase()) {
      case 'fajr':
      case 'dhuhr':
      case 'asr':
      case 'maghrib':
      case 'isha':
        return 1.days;
      case 'jumua':
        return 7.days;
      case 'aid':
        // Aid repeats yearly, but we use a large duration since it's calculated differently
        return 365.days;
      default:
        return 1.days;
    }
  }

  /// Get the default duration in minutes for a prayer
  static int getDefaultDuration(String prayerKey) {
    switch (prayerKey.toLowerCase()) {
      case 'fajr':
        return LiveStreamConstants.defaultDurationFajr;
      case 'dhuhr':
        return LiveStreamConstants.defaultDurationDhuhr;
      case 'asr':
        return LiveStreamConstants.defaultDurationAsr;
      case 'maghrib':
        return LiveStreamConstants.defaultDurationMaghrib;
      case 'isha':
        return LiveStreamConstants.defaultDurationIsha;
      case 'jumua':
        return LiveStreamConstants.defaultDurationJumua;
      case 'aid':
        return LiveStreamConstants.defaultDurationAid;
      default:
        return 10;
    }
  }

  /// Get occurrences for daily prayers based on prayer index
  /// Returns the appropriate time based on whether duration is 0 (ADHAN) or not (IQAMA)
  static Future<List<DateTime>> getDailyPrayerOccurrences({
    required MosqueManager mosqueManager,
    required int prayerIndex,
    required String prayerKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final durationKey = _getDurationKey(prayerKey);
    final duration = prefs.getInt(durationKey) ?? getDefaultDuration(prayerKey);

    // If duration is 0, use ADHAN time (actualTimes), otherwise use IQAMA time (actualIqamaTimes)
    if (duration == 0) {
      return [mosqueManager.actualTimes()[prayerIndex]];
    } else {
      return [mosqueManager.actualIqamaTimes()[prayerIndex]];
    }
  }

  /// Check if live streaming is enabled for a specific prayer type
  static Future<bool> isLiveEnabledForPrayer(String prayerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final enableKey = _getEnableKey(prayerKey);
    return prefs.getBool(enableKey) ?? false;
  }

  /// Get the configured duration for a specific prayer
  static Future<int> getDurationForPrayer(String prayerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final durationKey = _getDurationKey(prayerKey);
    return prefs.getInt(durationKey) ?? getDefaultDuration(prayerKey);
  }
}
