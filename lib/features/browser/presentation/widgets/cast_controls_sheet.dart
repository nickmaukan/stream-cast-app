import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/cast_state.dart';
import '../../../casting/presentation/bloc/casting_bloc.dart';

class CastControlsSheet extends StatelessWidget {
  final VoidCallback? onDismiss;

  const CastControlsSheet({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CastingBloc, CastingBlocState>(
      builder: (context, state) {
        if (!state.isCasting) return const SizedBox.shrink();

        final castState = state.castState;
        final device = state.connectedDevice;
        final bloc = context.read<CastingBloc>();

        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              _buildHeader(context, device?.name ?? 'TV', castState),
              _buildProgress(castState, bloc),
              _buildControls(context, castState),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String deviceName, CastState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Thumbnail or icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: state.currentMediaThumbnail != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      state.currentMediaThumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.smart_display,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.smart_display,
                    color: AppTheme.primary,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.currentMediaTitle ?? 'Reproduciendo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(state.playerState),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.playerState.displayName,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.cast, color: AppTheme.secondary, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        deviceName,
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () {
              context.read<CastingBloc>().add(StopMedia());
              onDismiss?.call();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(CastState state, CastingBloc bloc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              thumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: Colors.white24,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: state.progress.clamp(0.0, 1.0),
              onChanged: (value) {
                final position = Duration(
                  milliseconds: (value * state.duration.inMilliseconds).round(),
                );
                bloc.add(SeekMedia(position));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(state.position),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                Text(
                  _formatDuration(state.duration),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, CastState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Volume
          IconButton(
            icon: Icon(
              state.isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white70,
            ),
            onPressed: () => context.read<CastingBloc>().add(ToggleMute()),
          ),
          const SizedBox(width: 8),
          // Seek backward
          IconButton(
            icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
            onPressed: () {
              final newPos = state.position - const Duration(seconds: 10);
              context.read<CastingBloc>().add(SeekMedia(newPos));
            },
          ),
          const SizedBox(width: 16),
          // Play/Pause
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(50),
            ),
            child: IconButton(
              icon: Icon(
                state.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
              onPressed: () {
                if (state.isPlaying) {
                  context.read<CastingBloc>().add(PauseMedia());
                } else {
                  context.read<CastingBloc>().add(PlayMedia());
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          // Seek forward
          IconButton(
            icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
            onPressed: () {
              final newPos = state.position + const Duration(seconds: 10);
              context.read<CastingBloc>().add(SeekMedia(newPos));
            },
          ),
          const SizedBox(width: 8),
          // Stop
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.white70),
            onPressed: () {
              context.read<CastingBloc>().add(StopMedia());
              onDismiss?.call();
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(CastPlayerState state) {
    switch (state) {
      case CastPlayerState.playing:
        return AppTheme.secondary;
      case CastPlayerState.buffering:
        return AppTheme.warning;
      case CastPlayerState.paused:
        return AppTheme.textMuted;
      default:
        return AppTheme.error;
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
