import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/pages/home/sub_screens/StreamReplacementScreen.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/WorkFlowWidget.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_notifier.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum representing the different prayer types for video display configuration
enum PrayerType {
  fajr,
  dhuhr,
  asr,
  maghrib,
  isha,
  jumua,
  aid,
}

/// Utility class for generating WorkFlowItems for prayers with video display
class PrayerWorkflowUtils {
  /// Get the SharedPreferences key for a given prayer type
  static String getPrefKeyForPrayer(PrayerType prayerType) {
    switch (prayerType) {
      case PrayerType.fajr:
        return LiveStreamConstants.prefKeyLiveDurationFajr;
      case PrayerType.dhuhr:
        return LiveStreamConstants.prefKeyLiveDurationDhuhr;
      case PrayerType.asr:
        return LiveStreamConstants.prefKeyLiveDurationAsr;
      case PrayerType.maghrib:
        return LiveStreamConstants.prefKeyLiveDurationMaghrib;
      case PrayerType.isha:
        return LiveStreamConstants.prefKeyLiveDurationIsha;
      case PrayerType.jumua:
        return LiveStreamConstants.prefKeyLiveDurationJumua;
      case PrayerType.aid:
        return LiveStreamConstants.prefKeyLiveDurationAid;
    }
  }

  /// Convert salah index (0-4) to PrayerType
  static PrayerType? prayerTypeFromSalahIndex(int salahIndex) {
    switch (salahIndex) {
      case 0:
        return PrayerType.fajr;
      case 1:
        return PrayerType.dhuhr;
      case 2:
        return PrayerType.asr;
      case 3:
        return PrayerType.maghrib;
      case 4:
        return PrayerType.isha;
      default:
        return null;
    }
  }

  /// Get the configured duration for a prayer type from SharedPreferences
  /// Returns the duration in minutes, or 0 if not configured
  static Future<int> getLiveDurationForPrayer(PrayerType prayerType) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = getPrefKeyForPrayer(prayerType);
    return prefs.getInt(prefKey) ?? LiveStreamConstants.defaultLiveDuration;
  }

  /// Save the duration for a prayer type to SharedPreferences
  static Future<void> saveLiveDurationForPrayer(PrayerType prayerType, int durationMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = getPrefKeyForPrayer(prayerType);
    await prefs.setInt(prefKey, durationMinutes);
  }

  /// Get all prayer durations from SharedPreferences
  static Future<Map<PrayerType, int>> getAllPrayerDurations() async {
    final prefs = await SharedPreferences.getInstance();
    final durations = <PrayerType, int>{};

    for (final prayerType in PrayerType.values) {
      final prefKey = getPrefKeyForPrayer(prayerType);
      durations[prayerType] = prefs.getInt(prefKey) ?? LiveStreamConstants.defaultLiveDuration;
    }

    return durations;
  }

  /// Check if live stream is enabled in SharedPreferences
  static Future<bool> isLiveStreamEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(LiveStreamConstants.prefKeyEnabled) ?? false;
  }

  /// Generate WorkFlowItems for video display during a prayer
  /// 
  /// Parameters:
  /// - [prayerType]: The type of prayer (fajr, dhuhr, etc.)
  /// - [iqamaTime]: The iqama time when the video should start
  /// - [currentTime]: Current time (used for skip logic)
  /// - [occurrences]: List of DateTime occurrences for the prayer (used for Jumua/Aid with multiple times)
  /// 
  /// Returns a list of WorkFlowItems for video display, one for each occurrence
  static Future<List<WorkFlowItem>> generateVideoWorkflowItems({
    required PrayerType prayerType,
    required DateTime iqamaTime,
    required DateTime currentTime,
    List<DateTime>? occurrences,
  }) async {
    final items = <WorkFlowItem>[];

    // Check if live stream is enabled
    final isEnabled = await isLiveStreamEnabled();
    if (!isEnabled) {
      return items;
    }

    // Get the configured duration for this prayer
    final durationMinutes = await getLiveDurationForPrayer(prayerType);
    if (durationMinutes <= 0) {
      return items;
    }

    final duration = Duration(minutes: durationMinutes);

    // Handle multiple occurrences (for Jumua and Aid)
    final timesToProcess = occurrences ?? [iqamaTime];

    for (final startTime in timesToProcess) {
      final endTime = startTime.add(duration);

      items.add(
        WorkFlowItem(
          builder: (context, next) => _PrayerVideoScreen(
            onDone: next,
            prayerType: prayerType,
          ),
          duration: duration,
          skip: currentTime.isAfter(endTime),
          disabled: false,
        ),
      );
    }

    return items;
  }

  /// Generate a single WorkFlowItem for video display during a prayer
  /// This is a simplified version that returns a single item based on salah index
  static Future<WorkFlowItem?> generateSingleVideoWorkflowItem({
    required int salahIndex,
    required DateTime iqamaTime,
    required DateTime currentTime,
  }) async {
    final prayerType = prayerTypeFromSalahIndex(salahIndex);
    if (prayerType == null) return null;

    // Check if live stream is enabled
    final isEnabled = await isLiveStreamEnabled();
    if (!isEnabled) {
      return null;
    }

    // Get the configured duration for this prayer
    final durationMinutes = await getLiveDurationForPrayer(prayerType);
    if (durationMinutes <= 0) {
      return null;
    }

    final duration = Duration(minutes: durationMinutes);
    final endTime = iqamaTime.add(duration);

    return WorkFlowItem(
      builder: (context, next) => _PrayerVideoScreen(
        onDone: next,
        prayerType: prayerType,
      ),
      duration: duration,
      skip: currentTime.isAfter(endTime),
      disabled: false,
    );
  }
}

/// Widget that displays the video stream during a prayer
class _PrayerVideoScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  final PrayerType prayerType;

  const _PrayerVideoScreen({
    required this.onDone,
    required this.prayerType,
  });

  @override
  ConsumerState<_PrayerVideoScreen> createState() => _PrayerVideoScreenState();
}

class _PrayerVideoScreenState extends ConsumerState<_PrayerVideoScreen> {
  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(liveStreamProvider);

    return streamState.when(
      data: (state) {
        // Check if stream is enabled and active
        if (!state.isEnabled || state.streamStatus != LiveStreamStatus.active) {
          // If stream is not available, call onDone to skip to next workflow item
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onDone();
          });
          return Container(color: Colors.black);
        }

        // Use the existing StreamReplacementScreen for displaying the video
        return const StreamReplacementScreen();
      },
      loading: () => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (error, stack) {
        // On error, skip to next workflow item
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onDone();
        });
        return Container(color: Colors.black);
      },
    );
  }
}
