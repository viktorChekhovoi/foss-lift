import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/clip_label.dart';

class ClipPlayerScreen extends ConsumerStatefulWidget {
  const ClipPlayerScreen({
    super.key,
    required this.relativePath,
    this.caption,
    this.setId,
  });

  final String relativePath;

  final String? caption;

  final int? setId;

  @override
  ConsumerState<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends ConsumerState<ClipPlayerScreen> {
  VideoPlayerController? _controller;
  bool _missing = false;
  double _speed = 1.0;
  bool _looping = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = ref.read(setVideoStoreProvider);
    final file = await store.fileFor(widget.relativePath);
    if (!await file.exists()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    final controller = VideoPlayerController.file(File(file.path));
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    await controller.setLooping(_looping);
    await controller.play();
    setState(() => _controller = controller);
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? await c.pause() : await c.play();
    setState(() {});
  }

  Future<void> _cycleSpeed() async {
    final c = _controller;
    if (c == null) return;
    final next = nextPlaybackSpeed(_speed);
    await c.setPlaybackSpeed(next);
    setState(() => _speed = next);
  }

  Future<void> _toggleLoop() async {
    final c = _controller;
    if (c == null) return;
    final next = !_looping;
    await c.setLooping(next);
    setState(() => _looping = next);
  }

  Future<void> _confirmDelete(AppLocalizations l10n) async {
    final setId = widget.setId;
    if (setId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.clipPlayerDeleteTitle),
        content: Text(l10n.clipPlayerDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(databaseProvider).clearSetVideo(setId);
    await ref.read(setVideoStoreProvider).delete(widget.relativePath);
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.caption ?? l10n.clipPlayerTitle,
            style: const TextStyle(fontSize: 15)),
        actions: [
          if (widget.setId != null)
            IconButton(
              onPressed: () => _confirmDelete(l10n),
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.commonDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: _missing
            ? _gone(l10n)
            : controller == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: controller.value.aspectRatio,
                            child: GestureDetector(
                              onTap: _togglePlay,
                              child: VideoPlayer(controller),
                            ),
                          ),
                        ),
                      ),
                      _scrubber(controller),
                      _controls(controller),
                    ],
                  ),
      ),
    );
  }

  Widget _scrubber(VideoPlayerController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: VideoProgressIndicator(
        controller,
        allowScrubbing: true,
        padding: const EdgeInsets.symmetric(vertical: 18),
        colors: VideoProgressColors(
          playedColor: AppColors.accent,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
      ),
    );
  }

  Widget _controls(VideoPlayerController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _pill(
            label: fmtPlaybackSpeed(_speed),
            active: _speed != 1.0,
            onTap: _cycleSpeed,
          ),
          IconButton(
            iconSize: 46,
            onPressed: _togglePlay,
            color: Colors.white,
            icon: Icon(controller.value.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded),
          ),
          _pill(
            icon: Icons.repeat_rounded,
            active: _looping,
            onTap: _toggleLoop,
          ),
        ],
      ),
    );
  }

  Widget _pill({
    String? label,
    IconData? icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.accent : Colors.white30, width: 1.5),
          color: active
              ? AppColors.accent.withValues(alpha: 0.16)
              : Colors.transparent,
        ),
        child: icon != null
            ? Icon(icon,
                size: 20, color: active ? AppColors.accent : Colors.white70)
            : Text(
                label!,
                style: kMono.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.accent : Colors.white70,
                ),
              ),
      ),
    );
  }

  Widget _gone(AppLocalizations l10n) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  size: 40, color: Colors.white70),
              const SizedBox(height: 14),
              Text(l10n.clipPlayerMissing,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.5)),
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.commonBack),
              ),
            ],
          ),
        ),
      );
}
