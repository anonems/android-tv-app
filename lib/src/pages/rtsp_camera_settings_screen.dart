// RTSPCameraSettingsScreen - version étendue : ajoute gestion des durées live et switches
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

  // --- NEW : controllers for durations ---
  final Map<String, TextEditingController> _durationControllers = {
    'fajr': TextEditingController(),
    'dhuhr': TextEditingController(),
    'asr': TextEditingController(),
    'maghrib': TextEditingController(),
    'isha': TextEditingController(),
    'jumua': TextEditingController(),
    'aid': TextEditingController(),
  };

  // switches
  bool _enableDaily = false;
  bool _enableJumua = false;
  bool _enableAid = false;

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
    _loadDurationsAndSwitches();
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

  Future<void> _loadDurationsAndSwitches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _durationControllers.forEach((k, c) {
          final v = prefs.getInt('live_duration_$k') ?? _defaultFor(k);
          c.text = v.toString();
        });
        _enableDaily = prefs.getBool('live_enable_daily') ?? false;
        _enableJumua = prefs.getBool('live_enable_jumua') ?? false;
        _enableAid = prefs.getBool('live_enable_aid') ?? false;
      });
    } catch (e) {
      dev.log('⚠️ [RTSP_SCREEN] Error loading durations/switches: $e');
    }
  }

  int _defaultFor(String key) {
    switch (key) {
      case 'fajr':
        return 10;
      case 'dhuhr':
        return 15;
      case 'asr':
        return 10;
      case 'maghrib':
        return 8;
      case 'isha':
        return 12;
      case 'jumua':
        return 30;
      case 'aid':
        return 30;
      default:
        return 10;
    }
  }

  Future<void> _saveDurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in _durationControllers.keys) {
        final txt = _durationControllers[k]!.text;
        final parsed = int.tryParse(txt) ?? _defaultFor(k);
        await prefs.setInt('live_duration_$k', parsed);
      }
      // save switches
      await prefs.setBool('live_enable_daily', _enableDaily);
      await prefs.setBool('live_enable_jumua', _enableJumua);
      await prefs.setBool('live_enable_aid', _enableAid);
      dev.log('💾 [RTSP_SCREEN] Durations and switches saved');
    } catch (e) {
      dev.log('⚠️ [RTSP_SCREEN] Error saving durations: $e');
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
    keyboardSubscription.cancel();
    // dispose duration controllers
    _durationControllers.forEach((_, c) => c.dispose());
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

  Widget _buildDurationSection() {
    Widget row(String key, String label) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _durationControllers[key],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(suffixText: 'min'),
                onSubmitted: (_) => _saveDurations(),
                onEditingComplete: () => _saveDurations(),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(S.of(context).rtspCameraSettingTitle, style: Theme.of(context).textTheme.titleMedium?.apply(fontSizeFactor: 1.2)),
        const SizedBox(height: 8),
        row('fajr', S.of(context).fajr),
        row('dhuhr', S.of(context).dhuhr),
        row('asr', S.of(context).asr),
        row('maghrib', S.of(context).maghrib),
        row('isha', S.of(context).isha),
        const Divider(),
        Text('Jumua / Aïd', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        row('jumua', 'Jumua (durée par occurrence)'),
        row('aid', 'Aïd (durée par occurrence)'),
        const SizedBox(height: 12),
        // switches
        SwitchListTile(
          title: Text('Activer live pour les 5 prières quotidiennes'),
          value: _enableDaily,
          onChanged: (v) async {
            setState(() => _enableDaily = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('live_enable_daily', v);
          },
        ),
        SwitchListTile(
          title: Text('Activer live pour Jumua'),
          value: _enableJumua,
          onChanged: (v) async {
            setState(() => _enableJumua = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('live_enable_jumua', v);
          },
        ),
        SwitchListTile(
          title: Text('Activer live pour Aïd'),
          value: _enableAid,
          onChanged: (v) async {
            setState(() => _enableAid = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('live_enable_aid', v);
          },
        ),
      ],
    );
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
          // --- Insert duration section here ---
          _buildDurationSection(),
          const SizedBox(height: 12),
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

              // Persist durations & switches
              await _saveDurations();

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
              final stateNow = ref.read(liveStreamProvider).value;
              if (_urlController.text != stateNow?.streamUrl || stateNow?.streamStatus != LiveStreamStatus.active) {
                dev.log('🔄 [RTSP_SCREEN] Updating stream (URL changed or reconnecting)');
                await Future.delayed(const Duration(milliseconds: 500));

                ref.read(liveStreamProvider.notifier).updateStream(
                      url: _urlController.text,
                    );
              } else if (stateNow?.streamUrl != null && stateNow!.streamUrl!.isNotEmpty) {
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
        ],
      ],
    );
  }
}