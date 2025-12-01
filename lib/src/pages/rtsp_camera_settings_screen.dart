import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/domain/error/rtsp_expceptions.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_notifier.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_state.dart';
import 'package:mawaqit/src/widgets/ScreenWithAnimation.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:mawaqit/src/widgets/safe_youtube_player.dart';

class RTSPCameraSettingsScreen extends ConsumerStatefulWidget {
  const RTSPCameraSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RTSPCameraSettingsScreen> createState() => _RTSPCameraSettingsScreenState();
}

class _RTSPCameraSettingsScreenState extends ConsumerState<RTSPCameraSettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _saveButtonFocusNode = FocusNode();
  final FocusNode _replaceWorkflowWithStreamButtonFocusNode = FocusNode();
  late StreamSubscription<bool> keyboardSubscription;

  Timer? _saveUrlTimer;
  Timer? _saveLiveDurationTimer;

  // Duration controllers for prayers
  final TextEditingController _fajrDurationController = TextEditingController();
  final TextEditingController _dhuhrDurationController = TextEditingController();
  final TextEditingController _asrDurationController = TextEditingController();
  final TextEditingController _maghribDurationController = TextEditingController();
  final TextEditingController _ishaDurationController = TextEditingController();
  final TextEditingController _jumuaDurationController = TextEditingController();
  final TextEditingController _aidDurationController = TextEditingController();

  // Enable switches
  bool _liveEnableDaily = false;
  bool _liveEnableJumua = false;
  bool _liveEnableAid = false;

  @override
  void initState() {
    super.initState();
    dev.log('🖥️ [RTSP_SCREEN] Initializing RTSP Camera Settings Screen');
    var keyboardVisibilityController = KeyboardVisibilityController();
    keyboardSubscription = keyboardVisibilityController.onChange.listen((bool visible) {
      if (!visible) {
        dev.log('⌨️ [RTSP_SCREEN] Keyboard hidden, focusing save button');
        FocusScope.of(context).requestFocus(_replaceWorkflowWithStreamButtonFocusNode);
      }
    });

    // Load the saved URL immediately when screen opens
    _loadSavedUrl();
    // Load live duration settings
    _loadLiveDurationSettings();
  }

  Future<void> _loadSavedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(LiveStreamConstants.prefKeyUrl);
      if (savedUrl != null && savedUrl.isNotEmpty && _urlController.text.isEmpty) {
        dev.log('📝 [RTSP_SCREEN] Loading saved URL on init: $savedUrl');
        _urlController.text = savedUrl;
      }
    } catch (e) {
      dev.log('⚠️ [RTSP_SCREEN] Error loading saved URL: $e');
    }
  }

  Future<void> _loadLiveDurationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load duration values with defaults
      final fajr = prefs.getInt(LiveStreamConstants.prefKeyLiveDurationFajr) ?? LiveStreamConstants.defaultDurationFajr;
      final dhuhr = prefs.getInt(LiveStreamConstants.prefKeyLiveDurationDhuhr) ?? LiveStreamConstants.defaultDurationDhuhr;
      final asr = prefs.getInt(LiveStreamConstants.prefKeyLiveDurationAsr) ?? LiveStreamConstants.defaultDurationAsr;
      final maghrib = prefs.getInt(LiveStreamConstants.prefKeyLiveDurationMaghrib) ?? LiveStreamConstants.defaultDurationMaghrib;
      final isha = prefs.getInt(LiveStreamConstants.prefKeyLiveDurationIsha) ?? LiveStreamConstants.defaultDurationIsha;
      final jumua = prefs.getInt(LiveStreamConstants.prefKeyLiveDurationJumua) ?? LiveStreamConstants.defaultDurationJumua;
      final aid = prefs.getInt(LiveStreamConstants.prefKeyLiveDurationAid) ?? LiveStreamConstants.defaultDurationAid;

      // Load enable switches
      final enableDaily = prefs.getBool(LiveStreamConstants.prefKeyLiveEnableDaily) ?? false;
      final enableJumua = prefs.getBool(LiveStreamConstants.prefKeyLiveEnableJumua) ?? false;
      final enableAid = prefs.getBool(LiveStreamConstants.prefKeyLiveEnableAid) ?? false;

      setState(() {
        _fajrDurationController.text = fajr.toString();
        _dhuhrDurationController.text = dhuhr.toString();
        _asrDurationController.text = asr.toString();
        _maghribDurationController.text = maghrib.toString();
        _ishaDurationController.text = isha.toString();
        _jumuaDurationController.text = jumua.toString();
        _aidDurationController.text = aid.toString();

        _liveEnableDaily = enableDaily;
        _liveEnableJumua = enableJumua;
        _liveEnableAid = enableAid;
      });

      dev.log('📝 [RTSP_SCREEN] Loaded live duration settings');
    } catch (e) {
      dev.log('⚠️ [RTSP_SCREEN] Error loading live duration settings: $e');
    }
  }

  void _saveLiveDurationSettingsDebounced() {
    _saveLiveDurationTimer?.cancel();
    _saveLiveDurationTimer = Timer(const Duration(milliseconds: 500), () {
      _saveLiveDurationSettings();
    });
  }

  Future<void> _saveLiveDurationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save duration values
      await prefs.setInt(LiveStreamConstants.prefKeyLiveDurationFajr, int.tryParse(_fajrDurationController.text) ?? LiveStreamConstants.defaultDurationFajr);
      await prefs.setInt(LiveStreamConstants.prefKeyLiveDurationDhuhr, int.tryParse(_dhuhrDurationController.text) ?? LiveStreamConstants.defaultDurationDhuhr);
      await prefs.setInt(LiveStreamConstants.prefKeyLiveDurationAsr, int.tryParse(_asrDurationController.text) ?? LiveStreamConstants.defaultDurationAsr);
      await prefs.setInt(LiveStreamConstants.prefKeyLiveDurationMaghrib, int.tryParse(_maghribDurationController.text) ?? LiveStreamConstants.defaultDurationMaghrib);
      await prefs.setInt(LiveStreamConstants.prefKeyLiveDurationIsha, int.tryParse(_ishaDurationController.text) ?? LiveStreamConstants.defaultDurationIsha);
      await prefs.setInt(LiveStreamConstants.prefKeyLiveDurationJumua, int.tryParse(_jumuaDurationController.text) ?? LiveStreamConstants.defaultDurationJumua);
      await prefs.setInt(LiveStreamConstants.prefKeyLiveDurationAid, int.tryParse(_aidDurationController.text) ?? LiveStreamConstants.defaultDurationAid);

      // Save enable switches
      await prefs.setBool(LiveStreamConstants.prefKeyLiveEnableDaily, _liveEnableDaily);
      await prefs.setBool(LiveStreamConstants.prefKeyLiveEnableJumua, _liveEnableJumua);
      await prefs.setBool(LiveStreamConstants.prefKeyLiveEnableAid, _liveEnableAid);

      dev.log('💾 [RTSP_SCREEN] Saved live duration settings');
    } catch (e) {
      dev.log('⚠️ [RTSP_SCREEN] Error saving live duration settings: $e');
    }
  }

  void _saveDebouncedUrl(String url) {
    _saveUrlTimer?.cancel();
    _saveUrlTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(LiveStreamConstants.prefKeyUrl, url);
        dev.log('💾 [RTSP_SCREEN] Auto-saved URL: $url');
      } catch (e) {
        dev.log('⚠️ [RTSP_SCREEN] Error auto-saving URL: $e');
      }
    });
  }

  @override
  void dispose() {
    dev.log('🧹 [RTSP_SCREEN] Disposing RTSP Camera Settings Screen');
    _urlController.dispose();
    _saveButtonFocusNode.dispose();
    _replaceWorkflowWithStreamButtonFocusNode.dispose();
    _saveUrlTimer?.cancel();
    _saveLiveDurationTimer?.cancel();
    keyboardSubscription.cancel();
    // Dispose duration controllers
    _fajrDurationController.dispose();
    _dhuhrDurationController.dispose();
    _asrDurationController.dispose();
    _maghribDurationController.dispose();
    _ishaDurationController.dispose();
    _jumuaDurationController.dispose();
    _aidDurationController.dispose();
    super.dispose();
  }

  void _updateUrlController(LiveStreamViewerState state) {
    // Always update the controller if state has a URL and controller is empty or different
    if (state.streamUrl != null &&
        (state.streamUrl!.isNotEmpty) &&
        (_urlController.text.isEmpty || _urlController.text != state.streamUrl)) {
      dev.log('📝 [RTSP_SCREEN] Updating URL controller with: ${state.streamUrl}');
      _urlController.text = state.streamUrl!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(liveStreamProvider);
    ref.listen(liveStreamProvider, (previous, next) {
      if (next.hasValue) {
        _updateUrlController(next.value!);
      }
      if (previous != next && next.hasValue && next.value!.streamStatus == LiveStreamStatus.error) {
        dev.log('🚨 [RTSP_SCREEN] Stream error detected');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).streamError,
              style: TextStyle(fontSize: 16.sp),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      if (previous != next && !next.isLoading && next.hasValue && !next.hasError && next.value!.isEnabled) {
        final state = next.value!;

        // Only show snackbar when URL validation status changes
        ScaffoldMessenger.of(context).clearSnackBars();

        String message;
        Color backgroundColor;

        if (state.streamUrl != null && !state.isInvalidUrl) {
          dev.log('✅ [RTSP_SCREEN] Valid RTSP URL detected: ${state.streamUrl}');
          message = S.of(context).validRtspUrl;
          backgroundColor = Colors.green;
        } else if (state.isInvalidUrl) {
          dev.log('❌ [RTSP_SCREEN] Invalid RTSP URL detected: ${state.streamUrl}');
          message = S.of(context).invalidRtspUrl;
          backgroundColor = Colors.red;
        } else {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    });

    return asyncState.when(
      data: (state) {
        dev.log('🏗️ [RTSP_SCREEN] Building screen with state: ${state.isEnabled ? "Enabled" : "Disabled"}');
        return Scaffold(
          appBar: state.isEnabled
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                )
              : null,
          body: SafeArea(
            child: Stack(
              children: [
                if (!state.isEnabled)
                  ScreenWithAnimationWidget(
                    animation: "settings",
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildSettingsContent(state),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          margin: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _buildVideoPreview(state),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildSettingsContent(state),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
      loading: () {
        dev.log('⏳ [RTSP_SCREEN] Loading state');
        return Scaffold(
          body: _buildLoadingOverlay(),
        );
      },
      error: (error, stackTrace) {
        dev.log('🚨 [RTSP_SCREEN] Error state: $error');
        if (error is RTSPCameraException) {
          return _buildErrorScreen(error);
        } else {
          return _buildErrorScreen(RTSPStreamUpdateException(error.toString()));
        }
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  S.of(context).validatingStream,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(RTSPCameraException error) {
    String errorMessage = '';

    errorMessage = S.of(context).somethingWentWrong;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Instead of invalidating, just re-initialize the settings
                final notifier = ref.read(liveStreamProvider.notifier);
                await notifier.reinitialize();
              },
              child: Text(S.of(context).tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview(LiveStreamViewerState state) {
    dev.log('🎥 [RTSP_SCREEN] Building video preview for type: ${state.streamType}');
    if (state.streamType == LiveStreamType.youtubeLive && state.youtubeController != null) {
      return SafeYoutubePlayer(
        controller: state.youtubeController!,
        placeholder: Center(
          child: Text(
            'Loading stream...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        onError: (error) {
          dev.log('⚠️ [RTSP_SCREEN] YouTube player error: $error');
        },
      );
    }
    if (state.videoController != null) {
      return Video(controller: state.videoController!);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSettingsContent(LiveStreamViewerState state) {
    dev.log('⚙️ [RTSP_SCREEN] Building settings content');
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          S.of(context).rtspCameraSettings,
          style: Theme.of(context).textTheme.titleMedium?.apply(fontSizeFactor: 2),
          textAlign: TextAlign.center,
        ),
        const Divider(indent: 50, endIndent: 50),
        const SizedBox(height: 10),
        Text(
          S.of(context).rtspCameraSettingScreenDesc,
          style: Theme.of(context).textTheme.bodySmall?.apply(fontSizeFactor: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          title: Text(S.of(context).enableRtspCamera),
          value: state.isEnabled,
          autofocus: true,
          onChanged: (value) {
            dev.log('🔌 [RTSP_SCREEN] Toggling RTSP enabled state: $value');
            ref.read(liveStreamProvider.notifier).toggleEnabled(value);
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          focusNode: _replaceWorkflowWithStreamButtonFocusNode,
          title: Text(S.of(context).replaceWorkflowWithStream),
          subtitle: Text(S.of(context).replaceAppWorkflowWithCameraStream),
          value: state.replaceWorkflow,
          onChanged: state.isEnabled
              ? (value) {
                  dev.log('🔄 [RTSP_SCREEN] Toggling workflow replacement: $value');
                  ref.read(liveStreamProvider.notifier).toggleReplaceWorkflow(value);
                }
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        if (state.isEnabled) ...[
          const SizedBox(height: 20),
          Text(
            S.of(context).addRtspUrl,
            style: Theme.of(context).textTheme.bodyLarge?.apply(fontSizeFactor: 1.2),
            textAlign: TextAlign.center,
          ),
          const Divider(indent: 50, endIndent: 50),
          const SizedBox(height: 20),
          TextField(
            controller: _urlController,
            onChanged: (value) {
              // Save URL as user types (debounced to avoid too many saves)
              _saveDebouncedUrl(value);
            },
            onSubmitted: (_) {
              dev.log('📤 [RTSP_SCREEN] URL submitted: ${_urlController.text}');
              // ref.read(rtspCameraSettingsProvider.notifier).toggleReplaceWorkflow(state.replaceWorkflow);
              ref.read(liveStreamProvider.notifier).updateStream(
                    url: _urlController.text,
                  );
            },
            decoration: InputDecoration(
              labelText: S.of(context).enterRtspUrl,
              hintText: S.of(context).hintTextRtspUrl,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            focusNode: _saveButtonFocusNode,
            onPressed: () async {
              dev.log('💾 [RTSP_SCREEN] Save button pressed with URL: ${_urlController.text}');
              // First, show a loading indicator to prevent interactions
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(S.of(context).processingRequest),
                    ],
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              // Wait a moment to ensure UI updates
              await Future.delayed(const Duration(milliseconds: 100));

              // Always test RTSP connection first when it's an RTSP URL
              if (_urlController.text.isNotEmpty && _urlController.text.startsWith('rtsp://')) {
                final notifier = ref.read(liveStreamProvider.notifier);
                final isAvailable = await notifier.testRtspConnection(_urlController.text);

                if (!isAvailable) {
                  // Clear the loading snackbar
                  scaffoldMessenger.clearSnackBars();

                  // Show error message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'RTSP server is not available. Please check your connection.',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return; // Don't proceed if connection fails
                }
              }

              // Only update the stream if the URL has actually changed OR if we need to reconnect
              if (_urlController.text != state.streamUrl || state.streamStatus != LiveStreamStatus.active) {
                dev.log('🔄 [RTSP_SCREEN] Updating stream (URL changed or reconnecting)');
                await Future.delayed(const Duration(milliseconds: 500));

                ref.read(liveStreamProvider.notifier).updateStream(
                      url: _urlController.text,
                    );
              } else if (state.streamUrl != null && state.streamUrl!.isNotEmpty) {
                dev.log('📝 [RTSP_SCREEN] URL unchanged and stream active, only updating workflow flag');
                // URL hasn't changed and stream is active, just update the workflow flag if needed
                ref.read(liveStreamProvider.notifier).toggleReplaceWorkflow(state.replaceWorkflow);

                // Show success message
                scaffoldMessenger.clearSnackBars();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        Text('Settings saved successfully'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }

              // Always save live duration settings
              await _saveLiveDurationSettings();
            },
            icon: const Icon(Icons.save),
            label: Text(S.of(context).save),
            style: ButtonStyle(
              padding: MaterialStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.focused)) {
                  return Theme.of(context).primaryColor;
                }
                return Colors.white;
              }),
              iconColor: MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.focused)) {
                  return Colors.white;
                }
                return Colors.black;
              }),
              foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.focused)) {
                  return Colors.white;
                }
                return Colors.black;
              }),
            ),
          ),
          const SizedBox(height: 30),
          // Live Duration Settings Section
          _buildLiveDurationSettings(),
        ],
      ],
    );
  }

  Widget _buildLiveDurationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Stream Duration Settings',
          style: Theme.of(context).textTheme.titleMedium?.apply(fontSizeFactor: 1.5),
          textAlign: TextAlign.center,
        ),
        const Divider(indent: 50, endIndent: 50),
        const SizedBox(height: 10),
        Text(
          'Configure the duration (in minutes) for live video streaming during prayers. Set to 0 to trigger on Adhan instead of Iqama.',
          style: Theme.of(context).textTheme.bodySmall?.apply(fontSizeFactor: 1.2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Enable switches
        SwitchListTile(
          title: const Text('Enable Live for Daily Prayers'),
          subtitle: const Text('Show live stream during Fajr, Dhuhr, Asr, Maghrib, Isha'),
          value: _liveEnableDaily,
          onChanged: (value) {
            setState(() {
              _liveEnableDaily = value;
            });
            _saveLiveDurationSettingsDebounced();
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Enable Live for Jumua'),
          subtitle: const Text('Show live stream during Friday prayer'),
          value: _liveEnableJumua,
          onChanged: (value) {
            setState(() {
              _liveEnableJumua = value;
            });
            _saveLiveDurationSettingsDebounced();
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Enable Live for Eid'),
          subtitle: const Text('Show live stream during Eid prayers'),
          value: _liveEnableAid,
          onChanged: (value) {
            setState(() {
              _liveEnableAid = value;
            });
            _saveLiveDurationSettingsDebounced();
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        const SizedBox(height: 20),

        // Daily prayer durations
        if (_liveEnableDaily) ...[
          Text(
            'Daily Prayer Durations (minutes)',
            style: Theme.of(context).textTheme.titleSmall?.apply(fontSizeFactor: 1.2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDurationField('Fajr', _fajrDurationController)),
              const SizedBox(width: 12),
              Expanded(child: _buildDurationField('Dhuhr', _dhuhrDurationController)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDurationField('Asr', _asrDurationController)),
              const SizedBox(width: 12),
              Expanded(child: _buildDurationField('Maghrib', _maghribDurationController)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDurationField('Isha', _ishaDurationController)),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Jumua and Aid durations
        if (_liveEnableJumua || _liveEnableAid) ...[
          Text(
            'Special Prayer Durations (minutes)',
            style: Theme.of(context).textTheme.titleSmall?.apply(fontSizeFactor: 1.2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_liveEnableJumua) Expanded(child: _buildDurationField('Jumua', _jumuaDurationController)),
              if (_liveEnableJumua && _liveEnableAid) const SizedBox(width: 12),
              if (_liveEnableAid) Expanded(child: _buildDurationField('Eid', _aidDurationController)),
              if (!_liveEnableJumua || !_liveEnableAid) const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDurationField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onEditingComplete: () => _saveLiveDurationSettings(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'min',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
