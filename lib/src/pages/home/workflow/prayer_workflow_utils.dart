// utilitaire pour générer WorkFlowItem(s) pour les prières (gère daily/jumua/aid)
// - respecte les switches : live_enable_daily, live_enable_jumua, live_enable_aid
// - lit les durées depuis SharedPreferences live_duration_<prayerKey>
// - si duration == 0 pour une prière quotidienne, déclenchement à l'Adhan (actualTimes) au lieu de l'iqama
// - gère multi-occurrences (Jumua/Aid) et tronque la durée pour éviter chevauchement (buffer: live_buffer_<prayerKey> ou 10min)
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mawaqit/src/pages/home/sub_screens/JummuaLive.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/WorkFlowWidget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';

const _prefKeyPrefix = 'live_duration_'; // live_duration_fajr ...
const _prefEnableDaily = 'live_enable_daily';
const _prefEnableJumua = 'live_enable_jumua';
const _prefEnableAid = 'live_enable_aid';
const _prefBufferPrefix = 'live_buffer_'; // optional per-prayer buffer in minutes, fallback to 10

/// mapping prayerKey -> daily index (fajr..isha)
const Map<String, int> _dailyIndex = {
  'fajr': 0,
  'dhuhr': 1,
  'asr': 2,
  'maghrib': 3,
  'isha': 4,
};

Future<int> _loadDuration(String key, {int defaultMinutes = 10}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefKeyPrefix$key') ?? defaultMinutes;
  } catch (e) {
    log('Error loading duration $key: $e');
    return defaultMinutes;
  }
}

Future<int> _loadBuffer(String key, {int defaultMinutes = 10}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefBufferPrefix$key') ?? defaultMinutes;
  } catch (e) {
    log('Error loading buffer $key: $e');
    return defaultMinutes;
  }
}

Future<bool> _isGroupEnabled(String group) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    switch (group) {
      case 'daily':
        return prefs.getBool(_prefEnableDaily) ?? false;
      case 'jumua':
        return prefs.getBool(_prefEnableJumua) ?? false;
      case 'aid':
        return prefs.getBool(_prefEnableAid) ?? false;
      default:
        return false;
    }
  } catch (e) {
    log('Error checking enabled $group: $e');
    return false;
  }
}

/// Génère des WorkFlowItem pour une prière donnée (0..n occurrences).
/// - prayerKey: 'fajr','dhuhr','asr','maghrib','isha','jumua','aid'
/// - getOccurrences: fonction retournant List<DateTime> des heures pertinentes :
///     * pour daily: la fonction peut être ignorée (on lira actualIqamaTimes()/actualTimes())
///     * pour jumua/aid: getOccurrences doit retourner les heures de prière (0..n)
/// - mosqueManager: instance
Future<List<WorkFlowItem>> makePrayerLiveWorkFlowItems({
  required String prayerKey,
  required String label,
  required List<DateTime> Function()? getOccurrences,
  required MosqueManager mosqueManager,
  int defaultMinutes = 10,
}) async {
  // Respect switches
  try {
    if (_dailyIndex.containsKey(prayerKey)) {
      final enabled = await _isGroupEnabled('daily');
      if (!enabled) return [];
    } else if (prayerKey == 'jumua') {
      final enabled = await _isGroupEnabled('jumua');
      if (!enabled) return [];
    } else if (prayerKey == 'aid') {
      final enabled = await _isGroupEnabled('aid');
      if (!enabled) return [];
    }
  } catch (e) {
    log('Error reading enable switches: $e');
  }

  final configuredMinutes = await _loadDuration(prayerKey, defaultMinutes: defaultMinutes);
  final bufferMinutes = await _loadBuffer(prayerKey, defaultMinutes: 10);

  final now = mosqueManager.mosqueDate();

  // Determine occurrences list
  List<DateTime> occurrences = [];

  // DAILY prayers: if configuredMinutes == 0 -> trigger on ADHAN (actualTimes); else on IQAMA
  if (_dailyIndex.containsKey(prayerKey)) {
    final idx = _dailyIndex[prayerKey]!;
    try {
      if (configuredMinutes == 0) {
        // Use adhan times (actualTimes)
        final adhanTimes = mosqueManager.actualTimes();
        final dt = adhanTimes[idx];
        if (dt != null) occurrences = [dt];
      } else {
        // Use iqama times
        final iqamaTimes = mosqueManager.actualIqamaTimes();
        final dt = iqamaTimes[idx];
        if (dt != null) occurrences = [dt];
      }
    } catch (e) {
      log('Error obtaining daily occurrences for $prayerKey: $e');
      occurrences = [];
    }
  } else {
    // jumua / aid: rely on provided getOccurrences OR fallback to mosqueManager helpers
    if (getOccurrences != null) {
      try {
        occurrences = getOccurrences();
      } catch (e) {
        log('Error calling getOccurrences for $prayerKey: $e');
        occurrences = [];
      }
    } else {
      // Fallbacks:
      if (prayerKey == 'jumua') {
        final dt = mosqueManager.activeJumuaaDate();
        if (dt != null) occurrences = [dt];
      } else if (prayerKey == 'aid') {
        // try to fallback to actualTimes when isEid
        try {
          if (mosqueManager.isEidFirstDay(0)) {
            occurrences = mosqueManager.actualTimes();
          }
        } catch (e) {
          log('Error fallback aid dates: $e');
          occurrences = [];
        }
      }
    }
  }

  // Normalize and sort occurrences
  occurrences = occurrences.where((d) => d != null).toList()..sort((a, b) => a.compareTo(b));

  final items = <WorkFlowItem>[];

  if (occurrences.isEmpty) return items;

  for (var i = 0; i < occurrences.length; i++) {
    final start = occurrences[i];
    final nextStart = (i + 1 < occurrences.length) ? occurrences[i + 1] : null;
    // raw end if no truncation
    final rawEnd = start.add(Duration(minutes: configuredMinutes));
    DateTime effectiveEnd = rawEnd;

    if (nextStart != null) {
      // enforce buffer before the next occurrence
      final maxAllowedEnd = nextStart.subtract(Duration(minutes: bufferMinutes));
      if (maxAllowedEnd.isBefore(effectiveEnd)) {
        effectiveEnd = maxAllowedEnd;
      }
    }

    final effectiveDuration = effectiveEnd.difference(start);

    // Skip if already ended
    if (now.isAfter(effectiveEnd)) {
      continue;
    }

    // Determine the duration the item should run when reached:
    Duration durationToShow;
    if (now.isBefore(start)) {
      durationToShow = effectiveDuration;
    } else {
      durationToShow = effectiveEnd.difference(now);
    }

    if (durationToShow.inSeconds <= 0) continue;

    final skip = now.isAfter(effectiveEnd);

    items.add(
      WorkFlowItem(
        builder: (context, next) {
          // Reuse the existing JummuaLive screen which supports RTSP/YouTube
          return JummuaLive(onDone: next);
        },
        skip: skip,
        duration: durationToShow,
      ),
    );
  }

  return items;
}