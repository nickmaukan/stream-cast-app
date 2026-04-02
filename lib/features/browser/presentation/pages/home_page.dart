import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/video_stream.dart';
import '../../../casting/presentation/bloc/casting_bloc.dart';
import '../../../history/presentation/history_bloc.dart';
import '../../../favorites/presentation/favorites_bloc.dart';
import '../widgets/video_list_tile.dart';
import '../widgets/device_selector_sheet.dart';
import 'browser_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<HistoryBloc>().add(LoadHistory());
    context.read<FavoritesBloc>().add(LoadFavorites());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _playUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Add to history
    final video = VideoStream(
      title: 'Stream',
      url: url.startsWith('http') ? url : 'https://$url',
      addedAt: DateTime.now(),
    );
    context.read<HistoryBloc>().add(AddToHistory(video));

    _urlController.clear();
    _urlFocusNode.unfocus();

    // Show play options
    _showPlayOptions(video);
  }

  void _showPlayOptions(VideoStream video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlayOptionsSheet(video: video),
    );
  }

  void _openBrowser() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BrowserPage()),
    );
  }

  void _showDeviceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<CastingBloc>(),
        child: const DeviceSelectorSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeTab(),
          _HistoryTab(),
          _FavoritesTab(),
          _SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildUrlInput(context),
            const SizedBox(height: 16),
            _buildBrowserButton(context),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            _buildRecentSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.cast_connected, color: AppTheme.primary, size: 28),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Maukan Cast', style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold,
              )),
              Text('Navega y transmite a tu TV', style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 14,
              )),
            ],
          ),
        ),
        BlocBuilder<CastingBloc, CastingBlocState>(
          builder: (context, state) {
            if (!state.isConnected) return const SizedBox.shrink();
            return _CastStatusChip(deviceName: state.connectedDevice?.name ?? 'TV');
          },
        ),
      ],
    );
  }

  Widget _buildUrlInput(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: TextField(
              controller: context.findAncestorStateOfType<_HomePageState>()?._urlController,
              focusNode: context.findAncestorStateOfType<_HomePageState>()?._urlFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Pega la URL del video...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.link, color: AppTheme.primary),
              ),
              onSubmitted: (_) => context.findAncestorStateOfType<_HomePageState>()?._playUrl(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => context.findAncestorStateOfType<_HomePageState>()?._playUrl(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Reproducir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.findAncestorStateOfType<_HomePageState>()?._openBrowser(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.language, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🌐 Navegador Web', style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                  )),
                  SizedBox(height: 4),
                  Text('Busca videos y transmítelos a tu TV', style: TextStyle(
                    color: Colors.white70, fontSize: 13,
                  )),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BlocBuilder<CastingBloc, CastingBlocState>(
            builder: (context, state) => _QuickActionCard(
              icon: state.isConnected ? Icons.cast_connected : Icons.cast,
              label: state.isConnected ? state.connectedDevice?.name ?? 'TV' : 'Conectar',
              color: state.isConnected ? AppTheme.secondary : null,
              subtitle: state.isConnected ? 'Conectado' : 'Sin conectar',
              onTap: () => context.findAncestorStateOfType<_HomePageState>()?._showDeviceSelector(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.language,
            label: 'Navegador',
            subtitle: 'Buscar videos',
            color: AppTheme.primary,
            onTap: () => context.findAncestorStateOfType<_HomePageState>()?._openBrowser(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sample Videos Section
        _buildSampleVideosSection(context),
        const SizedBox(height: 24),
        // Recent Videos Section
        BlocBuilder<HistoryBloc, HistoryState>(
          builder: (context, state) {
            if (state.videos.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recientes', style: TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                    )),
                    if (state.videos.isNotEmpty)
                      TextButton(
                        onPressed: () => context.read<HistoryBloc>().add(ClearHistory()),
                        child: const Text('Limpiar', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ...state.videos.take(5).map((video) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: VideoListTile(
                    video: video,
                    onTap: () => context.findAncestorStateOfType<_HomePageState>()?._showPlayOptions(video),
                    onFavorite: () => context.read<HistoryBloc>().add(
                      ToggleFavorite(video.id!, !video.isFavorite),
                    ),
                    isFavorite: video.isFavorite,
                  ),
                )),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSampleVideosSection(BuildContext context) {
    final samples = [
      {'name': 'Big Buck Bunny', 'url': 'https://www.youtube.com/watch?v=aqz-KE-bpKQ'},
      {'name': 'Sintel Trailer', 'url': 'https://www.youtube.com/watch?v=e7X0sImLhPI'},
      {'name': 'Tears of Steel', 'url': 'https://www.youtube.com/watch?v=R6MlUcmOul8'},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.play_circle_outline, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Videos de prueba', style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold,
            )),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Prueba el casting con estos videos', style: TextStyle(
          color: AppTheme.textMuted, fontSize: 12,
        )),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: samples.length,
            itemBuilder: (context, index) {
              final sample = samples[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    final homeState = context.findAncestorStateOfType<_HomePageState>();
                    homeState?._urlController.text = sample['url']!;
                    homeState?._playUrl();
                  },
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.play_arrow, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sample['name']!,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Historial', style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold,
            )),
          ),
          Expanded(
            child: BlocBuilder<HistoryBloc, HistoryState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.videos.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, color: AppTheme.textMuted, size: 64),
                        SizedBox(height: 16),
                        Text('Sin historial', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: state.videos.length,
                  itemBuilder: (context, index) {
                    final video = state.videos[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VideoListTile(
                        video: video,
                        onTap: () {},
                        onFavorite: () => context.read<HistoryBloc>().add(
                          ToggleFavorite(video.id!, !video.isFavorite),
                        ),
                        isFavorite: video.isFavorite,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Favoritos', style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold,
            )),
          ),
          Expanded(
            child: BlocBuilder<FavoritesBloc, FavoritesState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.favorites.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_outline, color: AppTheme.textMuted, size: 64),
                        SizedBox(height: 16),
                        Text('Sin favoritos', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: state.favorites.length,
                  itemBuilder: (context, index) {
                    final video = state.favorites[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VideoListTile(
                        video: video,
                        onTap: () {},
                        onFavorite: () => context.read<FavoritesBloc>().add(
                          RemoveFromFavorites(video.id!),
                        ),
                        isFavorite: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajustes', style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 24),
            _SettingsTile(
              icon: Icons.cast,
              title: 'Dispositivos',
              subtitle: 'Administrar dispositivos de casting',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.notifications,
              title: 'Notificaciones',
              subtitle: 'Notificación durante casting',
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
            _SettingsTile(
              icon: Icons.history,
              title: 'Limpiar historial',
              subtitle: 'Borrar todo el historial',
              onTap: () => context.read<HistoryBloc>().add(ClearHistory()),
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'Acerca de',
              subtitle: 'Maukan Cast v2.0.0',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    this.subtitle,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (color ?? AppTheme.primary).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color ?? AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500,
                  )),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11,
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CastStatusChip extends StatelessWidget {
  final String deviceName;

  const _CastStatusChip({required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cast_connected, color: AppTheme.secondary, size: 16),
          const SizedBox(width: 6),
          Text(deviceName, style: const TextStyle(
            color: AppTheme.secondary, fontSize: 12, fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }
}

class _PlayOptionsSheet extends StatelessWidget {
  final VideoStream video;

  const _PlayOptionsSheet({required this.video});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(
            video.title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _OptionButton(
                  icon: Icons.play_circle_filled,
                  label: 'Reproducir',
                  color: AppTheme.primary,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BlocBuilder<CastingBloc, CastingBlocState>(
                  builder: (context, state) => _OptionButton(
                    icon: Icons.cast,
                    label: state.isConnected ? 'Enviar' : 'Conectar',
                    color: state.isConnected ? AppTheme.secondary : AppTheme.warning,
                    onTap: () {
                      Navigator.pop(context);
                      if (!state.isConnected) {
                        context.findAncestorStateOfType<_HomePageState>()?._showDeviceSelector();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: AppTheme.textMuted),
        onTap: onTap,
      ),
    );
  }
}
