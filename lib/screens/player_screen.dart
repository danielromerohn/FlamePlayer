// lib/screens/player_screen.dart
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:convert' show latin1, utf8;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

// IMPORTS CONDICIONALES
import '../utils/fullscreen_mobile.dart'
if (dart.library.html) '../utils/fullscreen_web.dart';

// ------------------------------------------------------------
// MODELO SUBTÍTULOS
// ------------------------------------------------------------
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });
}

// ------------------------------------------------------------
// VIDEO PLAYER
// ------------------------------------------------------------
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? subtitleUrl;
  final String title;
  final Duration? initialPosition;
  final bool hasExtraAudioTracks;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.subtitleUrl,
    this.initialPosition,
    this.hasExtraAudioTracks = false,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

// ------------------------------------------------------------
class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  bool controlsVisible = true;
  bool isFullscreen = false;
  bool fillMode = false; // 🔥 NUEVO: modo rellenar pantalla

  Timer? _hideTimer;
  double currentVolume = 1.0;
  bool subtitlesEnabled = true;
  bool subtitlesAvailable = false;
  bool initialized = false;
  bool _isBuffering = false;

  String? subtitleStatusMessage;
  Timer? _subtitleStatusTimer;

  String? fillMessage; // 🔥 NUEVO: mensaje "Rellenar Pantalla" / "Original"

  List<SubtitleCue> cues = [];
  StreamSubscription? _positionSub;

  // ------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    // 🔥 SOLO móviles → orientación horizontal y modo inmersivo
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      });
    }

    subtitlesAvailable = widget.subtitleUrl != null;
    _initAll();
  }

  Future<void> _initAll() async {
    await _initVideo();
    await _loadSubtitles();

    _positionSub = Stream.periodic(const Duration(milliseconds: 250)).listen((_) {
      if (mounted) setState(() {});
    });

    startHideTimer();
  }

  // ------------------------------------------------------------
  Future<void> _initVideo() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    _controller.addListener(() {
      if (!mounted) return;

      final v = _controller.value;

      if (v.isBuffering != _isBuffering) {
        setState(() => _isBuffering = v.isBuffering);
      }

      if (v.isInitialized &&
          !v.isPlaying &&
          v.position >= v.duration &&
          !v.isBuffering) {
        Navigator.pop(context);
      }
    });

    await _controller.initialize();
    _controller.setVolume(currentVolume);

    if (widget.initialPosition != null &&
        widget.initialPosition! > Duration.zero &&
        widget.initialPosition! < _controller.value.duration) {
      _isBuffering = true;
      await _controller.seekTo(widget.initialPosition!);
    }

    _controller.play();
    setState(() => initialized = true);
  }

  // ------------------------------------------------------------
  Future<void> _loadSubtitles() async {
    if (!subtitlesEnabled || widget.subtitleUrl == null) {
      subtitlesEnabled = false;
      subtitlesAvailable = false;
      return;
    }

    try {
      final res = await http.get(Uri.parse(widget.subtitleUrl!));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final decoded = decodeSrt(res.bodyBytes);
        cues = _parseSrt(decoded);
        subtitlesAvailable = cues.isNotEmpty;
      } else {
        subtitlesEnabled = false;
        subtitlesAvailable = false;
      }
    } catch (_) {
      subtitlesEnabled = false;
      subtitlesAvailable = false;
    }

    setState(() {});
  }

  // DECODIFICACIÓN SRT
  String decodeSrt(Uint8List bytes) {
    try {
      if (bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        return utf8.decode(bytes.sublist(3));
      }
    } catch (_) {}

    try {
      return utf8.decode(bytes);
    } catch (_) {}

    try {
      return latin1.decode(bytes);
    } catch (_) {}

    return String.fromCharCodes(bytes);
  }

  List<SubtitleCue> _parseSrt(String srt) {
    final lines = const LineSplitter().convert(srt);
    final parsed = <SubtitleCue>[];
    int i = 0;

    while (i < lines.length) {
      if (lines[i].trim().isEmpty) {
        i++;
        continue;
      }

      if (RegExp(r"^\d+$").hasMatch(lines[i].trim())) i++;

      if (i >= lines.length) break;

      final tline = lines[i].trim();
      final match = RegExp(
          r'(\d{2}:\d{2}:\d{2},\d{3})\s*--?>\s*(\d{2}:\d{2}:\d{2},\d{3})')
          .firstMatch(tline);

      if (match != null) {
        final start = _parseSrtTime(match.group(1)!);
        final end = _parseSrtTime(match.group(2)!);
        i++;
        final buffer = StringBuffer();

        while (i < lines.length && lines[i].trim().isNotEmpty) {
          buffer.writeln(lines[i]);
          i++;
        }

        parsed.add(SubtitleCue(start: start, end: end, text: buffer.toString()));
      } else {
        i++;
      }
    }

    return parsed;
  }

  Duration _parseSrtTime(String txt) {
    final p = txt.split(',');
    final t = p[0].split(':');

    return Duration(
      hours: int.parse(t[0]),
      minutes: int.parse(t[1]),
      seconds: int.parse(t[2]),
      milliseconds: int.parse(p[1]),
    );
  }

  SubtitleCue? _currentCue() {
    if (!subtitlesEnabled ||
        cues.isEmpty ||
        !_controller.value.isInitialized) return null;

    final pos = _controller.value.position;

    try {
      return cues.firstWhere((c) => pos >= c.start && pos <= c.end);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------
  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    _controller.dispose();
    _hideTimer?.cancel();
    _positionSub?.cancel();
    _subtitleStatusTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------
  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return "${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
    }
    return "${two(d.inMinutes)}:${two(d.inSeconds % 60)}";
  }

  String _timeText() {
    if (!_controller.value.isInitialized) return "00:00 / 00:00";
    final pos = _controller.value.position;
    final total = _controller.value.duration;
    final remain = total - pos;
    return "${_formatTime(pos)} / ${_formatTime(remain)}";
  }

  void startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => controlsVisible = false);
    });
  }

  void toggleControls() {
    setState(() => controlsVisible = !controlsVisible);
    if (controlsVisible) startHideTimer();
  }

  void enterFullscreen() {
    if (kIsWeb) enterFullscreenWeb();
    setState(() => isFullscreen = true);
  }

  void exitFullscreen() {
    if (kIsWeb) exitFullscreenWeb();
    setState(() => isFullscreen = false);
  }

  // 🔥 NUEVO: cambiar modo de visualización
  void toggleFillMode() {
    setState(() {
      fillMode = !fillMode;
      fillMessage = fillMode ? "Rellenar Pantalla" : "Original";
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => fillMessage = null);
    });
  }

  void _toggleSubtitles() {
    if (!subtitlesAvailable) return;

    setState(() {
      subtitlesEnabled = !subtitlesEnabled;
      subtitleStatusMessage = subtitlesEnabled
          ? "Subtitulos activados"
          : "Subtitulos desactivados";
    });

    _subtitleStatusTimer?.cancel();
    _subtitleStatusTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => subtitleStatusMessage = null);
    });
  }

  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggleControls,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ======================================================
            // VIDEO
            // ======================================================
            Center(
              child: initialized && _controller.value.isInitialized
                  ? (fillMode
                  ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
                  : AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ))
                  : const CircularProgressIndicator(color: Colors.white),
            ),

            // SUBTÍTULOS
            _buildSubtitleWidget(),

            // BUFFERING
            if (_isBuffering)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),

            // ======================================================
            // CONTROLES (con soporte de mouse)
            // ======================================================
            MouseRegion(
              onHover: (_) {
                if (!controlsVisible) {
                  setState(() => controlsVisible = true);
                  startHideTimer();
                }
              },
              child: IgnorePointer(                         // 👈 BLOQUEA TOQUES
                ignoring: !controlsVisible,                 // 👈 SOLO ACTIVOS CUANDO SE VEN
                child: AnimatedOpacity(
                  opacity: controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: _controlsOverlay(),
                ),
              ),
            ),

            // ======================================================
            // MENSAJE FLOTANTE RELLENAR / ORIGINAL
            // ======================================================
            if (fillMessage != null)
              Positioned.fill(
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    fillMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            if (subtitleStatusMessage != null)
              Positioned.fill(
                child: Center(
                  child: Text(
                    subtitleStatusMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _controlsOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        child: Column(
          children: [
            // TOP BAR
            Padding(
              padding: const EdgeInsets.only(top: 32, left: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 26),
                    onPressed: () {
                      exitFullscreen();
                      Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style:
                      const TextStyle(color: Colors.white, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // SLIDER
            if (initialized)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Slider(
                  value: _controller.value.position.inMilliseconds
                      .clamp(0, _controller.value.duration.inMilliseconds)
                      .toDouble(),
                  min: 0,
                  max: _controller.value.duration.inMilliseconds.toDouble(),
                  activeColor: Colors.redAccent,
                  onChanged: (v) async {
                    setState(() => _isBuffering = true);
                    await _controller
                        .seekTo(Duration(milliseconds: v.toInt()));
                  },
                ),
              ),

            // BOTTOM BAR
            Padding(
              padding:
              const EdgeInsets.only(bottom: 20, left: 12, right: 12),
              child: Row(
                children: [
                  // PLAY / PAUSE
                  IconButton(
                    iconSize: 40,
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                      setState(() {});
                    },
                  ),

                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                    onPressed: () async {
                      final current = _controller.value.position;
                      final target = current - const Duration(seconds: 10);
                      await _controller.seekTo(
                        target.isNegative ? Duration.zero : target,
                      );
                    },
                  ),

                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                    onPressed: () async {
                      final current = _controller.value.position;
                      final duration = _controller.value.duration;
                      final target = current + const Duration(seconds: 10);
                      await _controller.seekTo(
                        target > duration ? duration : target,
                      );
                    },
                  ),

                  const SizedBox(width: 10),

                  Text(
                    _timeText(),
                    style:
                    const TextStyle(color: Colors.white, fontSize: 14),
                  ),

                  const Spacer(),

                  // 🔥 VOLUMEN
                  IconButton(
                    iconSize: 28,
                    icon: Icon(
                      currentVolume == 0
                          ? Icons.volume_off
                          : Icons.volume_up,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        currentVolume = currentVolume == 0 ? 1.0 : 0.0;
                        _controller.setVolume(currentVolume);
                      });
                    },
                  ),

                  // SUBTÍTULOS ON/OFF
                  TextButton(
                    onPressed: subtitlesAvailable ? _toggleSubtitles : null,
                    child: Text(
                      subtitlesEnabled
                          ? "Subtítulos activados"
                          : "Subtítulos desactivados",
                      style: TextStyle(
                        color:
                            subtitlesAvailable ? Colors.white : Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // 🔥 BOTÓN RELLENAR PANTALLA / ORIGINAL
                  TextButton(
                    onPressed: toggleFillMode,
                    child: const Text(
                      "Modo Pantalla",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // FULLSCREEN WEB
                  if (kIsWeb)
                    IconButton(
                      iconSize: 28,
                      icon: Icon(
                        isFullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                      ),
                      onPressed: () => isFullscreen
                          ? exitFullscreen()
                          : enterFullscreen(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _buildSubtitleWidget() {
    final cue = _currentCue();
    if (cue == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: Center(
        child: Text(
          cue.text.replaceAll('\n', ' '),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(-1, -1)),
            ],
          ),
        ),
      ),
    );
  }

}
