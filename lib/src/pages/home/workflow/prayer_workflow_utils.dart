import 'package:mawaqit/src/const/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for prayer workflow live video settings
class PrayerWorkflowUtils {
  /// Get live video duration for a specific prayer
  /// Returns the duration in minutes, or null if not set
  /// If duration is 0, the workflow should trigger on ADHAN instead of IQAMA
  static Future<int> getLiveDurationForPrayer(int prayerIndex) async {
    final prefs = await SharedPreferences.getInstance();
    
    switch (prayerIndex) {
      case 0: // Fajr
        return prefs.getInt(LiveStreamConstants.prefKeyLiveDurationFajr) ?? LiveStreamConstants.defaultDurationFajr;
      case 1: // Dhuhr
        return prefs.getInt(LiveStreamConstants.prefKeyLiveDurationDhuhr) ?? LiveStreamConstants.defaultDurationDhuhr;
      case 2: // Asr
        return prefs.getInt(LiveStreamConstants.prefKeyLiveDurationAsr) ?? LiveStreamConstants.defaultDurationAsr;
      case 3: // Maghrib
        return prefs.getInt(LiveStreamConstants.prefKeyLiveDurationMaghrib) ?? LiveStreamConstants.defaultDurationMaghrib;
      case 4: // Isha
        return prefs.getInt(LiveStreamConstants.prefKeyLiveDurationIsha) ?? LiveStreamConstants.defaultDurationIsha;
      default:
        return 0;
    }
  }

  /// Get live video duration for Jumua
  static Future<int> getLiveDurationForJumua() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(LiveStreamConstants.prefKeyLiveDurationJumua) ?? LiveStreamConstants.defaultDurationJumua;
  }

  /// Get live video duration for Aïd
  static Future<int> getLiveDurationForAid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(LiveStreamConstants.prefKeyLiveDurationAid) ?? LiveStreamConstants.defaultDurationAid;
  }

  /// Check if live mode is enabled for daily prayers
  static Future<bool> isLiveEnabledForDaily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(LiveStreamConstants.prefKeyLiveEnableDaily) ?? false;
  }

  /// Check if live mode is enabled for Jumua
  static Future<bool> isLiveEnabledForJumua() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(LiveStreamConstants.prefKeyLiveEnableJumua) ?? false;
  }

  /// Check if live mode is enabled for Aïd
  static Future<bool> isLiveEnabledForAid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(LiveStreamConstants.prefKeyLiveEnableAid) ?? false;
  }

  /// Determine if the workflow should trigger on ADHAN (actualTimes) instead of IQAMA (actualIqamaTimes)
  /// Per requirements: when duration for a daily prayer is set to 0, the workflow triggers on ADHAN time
  /// This allows users to configure different trigger points for the live stream
  static Future<bool> shouldTriggerOnAdhan(int prayerIndex) async {
    final duration = await getLiveDurationForPrayer(prayerIndex);
    return duration == 0;
  }

  /// Get all live duration settings at once
  static Future<Map<String, int>> getAllLiveDurations() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'fajr': prefs.getInt(LiveStreamConstants.prefKeyLiveDurationFajr) ?? LiveStreamConstants.defaultDurationFajr,
      'dhuhr': prefs.getInt(LiveStreamConstants.prefKeyLiveDurationDhuhr) ?? LiveStreamConstants.defaultDurationDhuhr,
      'asr': prefs.getInt(LiveStreamConstants.prefKeyLiveDurationAsr) ?? LiveStreamConstants.defaultDurationAsr,
      'maghrib': prefs.getInt(LiveStreamConstants.prefKeyLiveDurationMaghrib) ?? LiveStreamConstants.defaultDurationMaghrib,
      'isha': prefs.getInt(LiveStreamConstants.prefKeyLiveDurationIsha) ?? LiveStreamConstants.defaultDurationIsha,
      'jumua': prefs.getInt(LiveStreamConstants.prefKeyLiveDurationJumua) ?? LiveStreamConstants.defaultDurationJumua,
      'aid': prefs.getInt(LiveStreamConstants.prefKeyLiveDurationAid) ?? LiveStreamConstants.defaultDurationAid,
    };
  }

  /// Get all live enable settings at once
  static Future<Map<String, bool>> getAllLiveEnableSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'daily': prefs.getBool(LiveStreamConstants.prefKeyLiveEnableDaily) ?? false,
      'jumua': prefs.getBool(LiveStreamConstants.prefKeyLiveEnableJumua) ?? false,
      'aid': prefs.getBool(LiveStreamConstants.prefKeyLiveEnableAid) ?? false,
    };
  }
}
