import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/video_source.dart';
import '../../../casting/presentation/bloc/casting_bloc.dart';
import '../widgets/device_selector_sheet.dart';

class DetectedVideo {
  final String url;
  final String? title;
  final DateTime detectedAt;
  final String? quality;
  final VideoSourceType type;
  final String? thumbnail;
  final int? duration;
  final bool isLive;
  final int score;
  
  DetectedVideo({
    required this.url,
    this.title,
    required this.detectedAt,
    this.quality,
    VideoSourceType? type,
    this.thumbnail,
    this.duration,
    this.isLive = false,
    this.score = 0,
  }) : type = type ?? VideoSourceType.fromUrl(url);
  
  String get qualityLabel {
    if (isLive) return 'LIVE';
    if (quality != null) return quality!;
    switch (type) {
      case VideoSourceType.hls: return 'HLS';
      case VideoSourceType.dash: return 'DASH';
      case VideoSourceType.webm: return 'WebM';
      case VideoSourceType.mp4: return 'MP4';
      case VideoSourceType.mov: return 'MOV';
      case VideoSourceType.youtube: return 'YouTube';
      case VideoSourceType.vimeo: return 'Vimeo';
      case VideoSourceType.other: return 'Video';
    }
  }
  
  String get formattedDuration {
    if (isLive) return 'LIVE';
    if (duration == null || duration == 0) return '';
    final minutes = (duration! / 60).floor();
    final seconds = (duration! % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class BrowserPage extends StatefulWidget {
  final VoidCallback? onBack;
  const BrowserPage({super.key, this.onBack});
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  bool _isLoading = false;
  String _currentUrl = '';
  String _currentTitle = 'Navegador';
  List<DetectedVideo> _detectedVideos = [];
  bool _isSearchingVideos = false;
  double _progress = 0;
  Timer? _periodicSearchTimer;
  String _detectionStatus = '';
  bool _showVideoPanel = false;
  Set<String> _detectedUrls = {};
  
  late TextEditingController _urlController;
  final FocusNode _urlFocusNode = FocusNode();
  Future<void>? _pendingSearch;

  static const String _desktopUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicSearchTimer?.cancel();
    _pendingSearch?.ignore();
    _controller?.dispose();
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPeriodicSearch();
    } else {
      _stopPeriodicSearch();
    }
  }

  void _startPeriodicSearch() {
    _stopPeriodicSearch();
    _periodicSearchTimer = Timer.periodic(const Duration(seconds: 3), (_) => _searchVideos());
  }

  void _stopPeriodicSearch() {
    _periodicSearchTimer?.cancel();
    _periodicSearchTimer = null;
  }

  void _onPageStarted(String url) {
    _urlController.text = url;
    setState(() {
      _currentUrl = url;
      _isLoading = true;
      _detectionStatus = 'Buscando videos...';
      _detectedVideos = [];
      _detectedUrls.clear();
      _showVideoPanel = false;
    });
  }

  void _onPageFinished(String url, String? title) {
    _urlController.text = url;
    setState(() {
      _currentUrl = url;
      _currentTitle = title ?? _extractTitle(url);
      _isLoading = false;
    });
    
    _pendingSearch?.ignore();
    _pendingSearch = Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _searchVideos();
    });
    
    _startPeriodicSearch();
  }

  Future<void> _searchVideos() async {
    if (_controller == null || _isSearchingVideos) return;

    setState(() {
      _detectionStatus = 'Buscando videos...';
      _isSearchingVideos = true;
    });

    try {
      final result = await _controller!.evaluateJavascript(source: _videoDetectionJS);

      if (result != null && mounted) {
        final newVideos = _parseVideoUrls(result);
        
        if (newVideos.isNotEmpty) {
          setState(() {
            for (final video in newVideos) {
              if (!_detectedUrls.contains(video.url)) {
                _detectedVideos.add(video);
                _detectedUrls.add(video.url);
              }
            }
            _detectedVideos.sort((a, b) => b.score.compareTo(a.score));
            _showVideoPanel = _detectedVideos.isNotEmpty;
            _detectionStatus = '🎬 ${_detectedVideos.length} video(s) listo(s)';
          });

          if (newVideos.length == _detectedVideos.length && _detectedVideos.length == 1) {
            _showVideoFoundSnackBar(_detectedVideos.length);
          }
        } else {
          setState(() => _detectionStatus = '');
        }
      }
    } catch (e) {
      debugPrint('Video search error: $e');
    }

    if (mounted) {
      setState(() => _isSearchingVideos = false);
    }
  }

  List<DetectedVideo> _parseVideoUrls(dynamic result) {
    final videos = <DetectedVideo>[];
    try {
      List<dynamic> items;
      if (result is String) {
        items = json.decode(result) as List<dynamic>;
      } else if (result is List) {
        items = result;
      } else {
        return videos;
      }

      for (final item in items) {
        Map<String, dynamic>? itemMap;
        String? url;
        
        if (item is String) {
          url = item;
        } else if (item is Map) {
          itemMap = Map<String, dynamic>.from(item);
          url = itemMap['url']?.toString();
        }

        if (url != null && url.isNotEmpty && url.startsWith('http') && !_detectedUrls.contains(url)) {
          String? quality;
          int? duration;
          bool isLive = false;
          String? videoTitle;
          
          if (itemMap != null) {
            if (itemMap['quality'] != null) {
              final q = itemMap['quality'];
              if (q is int && q > 0) {
                quality = '${q}p';
              } else if (q is String && q.isNotEmpty) {
                quality = q;
              }
            }
            
            if (itemMap['duration'] != null) {
              final d = itemMap['duration'];
              if (d is num && d > 0) {
                duration = d.toInt();
                if (d.isInfinite || d == 0) isLive = true;
              }
            }
            
            videoTitle = itemMap['title']?.toString();
          }
          
          quality ??= _extractQuality(url);
          
          int score = _calculateScore(
            url: url,
            quality: quality,
            type: VideoSourceType.fromUrl(url),
            isLive: isLive,
            title: videoTitle,
            duration: duration,
          );
          
          videos.add(DetectedVideo(
            url: url,
            title: videoTitle ?? _extractTitleFromUrl(url),
            detectedAt: DateTime.now(),
            quality: quality,
            duration: duration,
            isLive: isLive,
            score: score,
          ));
        }
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
    return videos;
  }

  int _calculateScore({
    required String url,
    String? quality,
    required VideoSourceType type,
    required bool isLive,
    String? title,
    int? duration,
  }) {
    int score = 0;
    
    if (quality != null) {
      if (quality.contains('2160') || quality.contains('4K')) score += 40;
      else if (quality.contains('1080')) score += 30;
      else if (quality.contains('720')) score += 20;
      else if (quality.contains('480')) score += 10;
      else if (quality.contains('360') || quality.contains('240')) score += 5;
    }
    
    switch (type) {
      case VideoSourceType.hls: score += 30; break;
      case VideoSourceType.dash: score += 20; break;
      case VideoSourceType.mp4: score += 15; break;
      case VideoSourceType.webm: score += 10; break;
      case VideoSourceType.youtube: score += 5; break;
      case VideoSourceType.vimeo: score += 5; break;
      case VideoSourceType.mov: score += 5; break;
      case VideoSourceType.other: score += 5; break;
    }
    
    if (isLive) score += 25;
    
    if (title != null && 
        !title.toLowerCase().contains('file') &&
        title.length > 3 &&
        !title.contains('.mp4') &&
        !title.contains('.m3u8')) {
      score += 20;
    }
    
    if (duration != null && duration > 60 && duration < 7200) {
      score += 10;
    }
    
    if (url.contains('/video/') || url.contains('/watch/') || url.contains('/stream/')) {
      score += 15;
    }
    
    return score;
  }

  String _extractTitle(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceAll('www.', '');
    } catch (_) {
      return 'Navegador';
    }
  }

  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (path.isNotEmpty && !path.contains('.')) {
        return path.replaceAll(RegExp(r'[-_]'), ' ');
      }
      return uri.host;
    } catch (_) {
      return 'Video';
    }
  }

  String? _extractQuality(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('2160') || lower.contains('4k')) return '4K';
    if (lower.contains('1080')) return '1080p';
    if (lower.contains('720')) return '720p';
    if (lower.contains('480')) return '480p';
    if (lower.contains('360')) return '360p';
    if (lower.contains('240')) return '240p';
    return null;
  }

  void _showVideoFoundSnackBar(int count) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(count == 1 ? '1 video listo para transmitir' : '$count videos listos'),
          ],
        ),
        backgroundColor: AppTheme.secondary,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'ENVIAR',
          textColor: Colors.white,
          onPressed: _showVideosSheet,
        ),
      ),
    );
  }

  void _loadUrl(String url) {
    String finalUrl = url.trim();
    
    final uri = Uri.tryParse(finalUrl);
    if (uri != null && uri.scheme != 'http' && uri.scheme != 'https') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL no válida - solo http/https'), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      if (finalUrl.contains('.') && !finalUrl.contains(' ')) {
        finalUrl = 'https://$finalUrl';
      } else {
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(finalUrl)}';
      }
    }
    
    final parsedUri = Uri.tryParse(finalUrl);
    if (parsedUri == null || (parsedUri.scheme != 'http' && parsedUri.scheme != 'https')) {
      return;
    }
    
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(finalUrl)));
  }

  void _showVideosSheet() {
    if (_detectedVideos.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VideosDetectedSheet(
        videos: _detectedVideos,
        currentTitle: _currentTitle,
        onVideoSelected: (video) { Navigator.pop(ctx); _castVideo(video); },
      ),
    );
  }

  void _castVideo(DetectedVideo video) {
    final castingBloc = context.read<CastingBloc>();
    
    if (!castingBloc.state.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.warning, color: Colors.white, size: 20), SizedBox(width: 8), Text('Conecta un dispositivo primero')]),
          backgroundColor: AppTheme.warning,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(label: 'CONECTAR', textColor: Colors.white, onPressed: _showDeviceSelectorSheet),
        ),
      );
      return;
    }

    final source = VideoSource(url: video.url, title: video.title ?? _currentTitle, type: video.type);
    castingBloc.add(CastVideo(source));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.cast, color: Colors.white, size: 20), const SizedBox(width: 8), Expanded(child: Text('Enviando a ${castingBloc.state.connectedDevice?.name ?? "TV"}...', maxLines: 1, overflow: TextOverflow.ellipsis))]),
        backgroundColor: AppTheme.secondary,
        duration: const Duration(seconds: 3),
      ),
    );
    _showCastingControls();
  }
  
  void _showDeviceSelectorSheet() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => BlocProvider.value(value: context.read<CastingBloc>(), child: const DeviceSelectorSheet()));
  }
  
  void _showCastingControls() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => BlocProvider.value(value: context.read<CastingBloc>(), child: const _CastingControlsSheet()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildUrlBar(),
            _buildDetectionBar(),
            if (_showVideoPanel && _detectedVideos.isNotEmpty) _buildVideoPanel(),
            Expanded(child: _buildWebView()),
            _buildBottomBar(),
          ],
        ),
      ),
      floatingActionButton: _buildCastFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack ?? () => Navigator.pop(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_currentTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (_currentUrl.isNotEmpty) Text(Uri.tryParse(_currentUrl)?.host ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (_detectedVideos.isNotEmpty) Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.video_library, color: AppTheme.secondary, size: 16), const SizedBox(width: 4), Text('${_detectedVideos.length}', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 13))]),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white54), onPressed: () {
            _controller?.reload();
            setState(() { _detectedVideos = []; _detectedUrls.clear(); _showVideoPanel = false; _detectionStatus = 'Buscando videos...'; });
            Future.delayed(const Duration(seconds: 2), _searchVideos);
          }),
        ],
      ),
    );
  }

  Widget _buildUrlBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Escribe URL o busca...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _currentUrl.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.white38, size: 18), onPressed: () { _urlController.clear(); _controller?.loadUrl(urlRequest: URLRequest(url: WebUri('https://www.google.com'))); }) : null,
              ),
              onSubmitted: _loadUrl,
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))),
        ],
      ),
    );
  }

  Widget _buildDetectionBar() {
    if (_detectionStatus.isEmpty && !_isSearchingVideos) {
      if (_currentUrl.isNotEmpty && !_isLoading) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [Icon(Icons.info_outline, color: AppTheme.textMuted, size: 16), SizedBox(width: 8), Text('No hay videos en esta página', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))]),
        );
      }
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: _detectedVideos.isNotEmpty ? AppTheme.secondary.withOpacity(0.2) : AppTheme.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          if (_isSearchingVideos) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
          else if (_detectedVideos.isNotEmpty) const Icon(Icons.check_circle, color: AppTheme.secondary, size: 16)
          else const SizedBox(width: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_detectionStatus, style: TextStyle(color: _detectedVideos.isNotEmpty ? AppTheme.secondary : AppTheme.textSecondary, fontSize: 12, fontWeight: _detectedVideos.isNotEmpty ? FontWeight.w600 : FontWeight.normal))),
          if (_detectedVideos.isNotEmpty) TextButton(
            onPressed: _showVideosSheet,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('ENVIAR', style: TextStyle(color: AppTheme.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPanel() {
    return Container(
      height: 130,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _detectedVideos.length,
        itemBuilder: (context, index) => _VideoCard(video: _detectedVideos[index], rank: index + 1, onTap: _showVideosSheet),
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri('https://www.google.com')),
          initialSettings: InAppWebViewSettings(javaScriptEnabled: true, mediaPlaybackRequiresUserGesture: false, allowsInlineMediaPlayback: true, supportZoom: true, cacheEnabled: true, clearCache: false, userAgent: _desktopUserAgent, databaseEnabled: true, domStorageEnabled: true),
          onWebViewCreated: (controller) => _controller = controller,
          onLoadStart: (_, url) => _onPageStarted(url.toString()),
          onLoadStop: (_, url) => _onPageFinished(url.toString(), null),
          onProgressChanged: (_, progress) => setState(() => _progress = progress / 100),
          onTitleChanged: (_, title) { if (mounted) setState(() => _currentTitle = title ?? 'Navegador'); },
        ),
        if (_isLoading) LinearProgressIndicator(value: _progress > 0 ? _progress : null, backgroundColor: Colors.transparent, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary)),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sitios populares', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: VideoSites.popular.length,
              itemBuilder: (context, index) {
                final site = VideoSites.popular[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(avatar: Text(site['icon']!), label: Text(site['name']!), labelStyle: const TextStyle(color: Colors.white, fontSize: 12), backgroundColor: AppTheme.surface, onPressed: () => _loadUrl(site['url']!)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildCastFab() {
    if (_detectedVideos.isEmpty) return null;
    return BlocBuilder<CastingBloc, CastingBlocState>(
      builder: (context, state) {
        final isConnected = state.isConnected;
        final isCasting = state.isCasting;
        
        Color fabColor = AppTheme.secondary;
        IconData fabIcon = Icons.cast;
        String fabLabel = 'ENVIAR';
        VoidCallback onPressed;
        
        if (isCasting) {
          fabColor = Colors.green;
          fabIcon = Icons.cast_connected;
          fabLabel = 'STOP';
          onPressed = () => context.read<CastingBloc>().add(StopMedia());
        } else if (!isConnected) {
          fabColor = AppTheme.warning;
          fabIcon = Icons.cast_outlined;
          fabLabel = 'CONECTAR';
          onPressed = _showDeviceSelectorSheet;
        } else {
          onPressed = _showVideosSheet;
        }
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isCasting ? Colors.green : AppTheme.secondary, borderRadius: BorderRadius.circular(12)), child: Text('${_detectedVideos.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            FloatingActionButton.extended(heroTag: 'castFab', onPressed: onPressed, backgroundColor: fabColor, icon: Icon(fabIcon), label: Text(fabLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  final DetectedVideo video;
  final int rank;
  final VoidCallback onTap;

  const _VideoCard({required this.video, required this.rank, required this.onTap});

  Color _getBorderColor() {
    if (video.isLive) return Colors.red;
    if (video.quality?.contains('1080') == true || video.quality?.contains('4K') == true) return Colors.green;
    if (video.quality?.contains('720') == true) return Colors.blue;
    if (video.type == VideoSourceType.hls) return Colors.orange;
    return AppTheme.primary;
  }

  Color _getQualityColor() {
    if (video.quality?.contains('4K') == true) return Colors.purple;
    if (video.quality?.contains('1080') == true) return Colors.green;
    if (video.quality?.contains('720') == true) return Colors.blue;
    if (video.quality?.contains('480') == true) return Colors.orange;
    return AppTheme.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _getBorderColor().withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: _getBorderColor().withOpacity(0.2), borderRadius: const BorderRadius.vertical(top: Radius.circular(11))),
              child: Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: video.isLive ? Colors.red : _getQualityColor(), borderRadius: BorderRadius.circular(4)), child: Text(video.isLive ? 'LIVE' : (video.qualityLabel), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                const Spacer(),
                Text('#$rank', style: TextStyle(color: _getBorderColor(), fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(video.title ?? 'Video', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)), child: Text(video.type == VideoSourceType.hls ? 'HLS' : (video.type == VideoSourceType.dash ? 'DASH' : (video.type == VideoSourceType.webm ? 'WebM' : 'MP4')), style: const TextStyle(color: AppTheme.textMuted, fontSize: 9))),
                      if (video.formattedDuration.isNotEmpty) ...[const SizedBox(width: 6), Icon(Icons.schedule, color: Colors.white54, size: 12), const SizedBox(width: 2), Text(video.formattedDuration, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))],
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideosDetectedSheet extends StatelessWidget {
  final List<DetectedVideo> videos;
  final String currentTitle;
  final Function(DetectedVideo) onVideoSelected;

  const _VideosDetectedSheet({required this.videos, required this.currentTitle, required this.onVideoSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.video_library, color: AppTheme.secondary, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${videos.length} video(s) detectados', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Ordenados por relevancia', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ])),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: videos.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
              itemBuilder: (context, index) => _VideoListTile(video: videos[index], rank: index + 1, onTap: () => onVideoSelected(videos[index])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: BlocBuilder<CastingBloc, CastingBlocState>(
              builder: (context, state) => SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: state.isConnected && videos.isNotEmpty ? () => onVideoSelected(videos.first) : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, disabledBackgroundColor: AppTheme.surfaceAlt, padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: Icon(state.isConnected ? Icons.cast : Icons.cast_outlined),
                  label: Text(state.isConnected ? 'Enviar a ${state.connectedDevice?.name}' : 'Conecta un dispositivo', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoListTile extends StatelessWidget {
  final DetectedVideo video;
  final int rank;
  final VoidCallback onTap;

  const _VideoListTile({required this.video, required this.rank, required this.onTap});

  Color _getColor() {
    if (video.isLive) return Colors.red;
    if (video.quality?.contains('1080') == true || video.quality?.contains('4K') == true) return Colors.green;
    if (video.quality?.contains('720') == true) return Colors.blue;
    if (video.type == VideoSourceType.hls) return Colors.orange;
    return AppTheme.primary;
  }

  IconData _getIcon() {
    if (video.isLive) return Icons.live_tv;
    if (video.type == VideoSourceType.hls) return Icons.hls;
    if (video.type == VideoSourceType.dash) return Icons.speed;
    if (video.type == VideoSourceType.webm) return Icons.movie;
    return Icons.video_file;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: _getColor().withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
        child: Stack(alignment: Alignment.center, children: [
          Icon(_getIcon(), color: _getColor(), size: 24),
          Positioned(bottom: 2, right: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: _getColor(), borderRadius: BorderRadius.circular(4)), child: Text('#$rank', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
        ]),
      ),
      title: Text(video.title ?? 'Video', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Wrap(spacing: 6, runSpacing: 4, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: video.isLive ? Colors.red.withOpacity(0.2) : _getColor().withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: video.isLive ? Colors.red.withOpacity(0.5) : _getColor().withOpacity(0.5))), child: Text(video.isLive ? 'LIVE' : video.qualityLabel, style: TextStyle(color: video.isLive ? Colors.red : _getColor(), fontSize: 10, fontWeight: FontWeight.bold))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)), child: Text(video.type == VideoSourceType.hls ? 'HLS' : (video.type == VideoSourceType.dash ? 'DASH' : (video.type == VideoSourceType.webm ? 'WebM' : 'MP4')), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))),
        if (video.formattedDuration.isNotEmpty) ...[Icon(Icons.schedule, color: Colors.white54, size: 12), const SizedBox(width: 2), Text(video.formattedDuration, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))],
      ])),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        BlocBuilder<CastingBloc, CastingBlocState>(builder: (context, state) => Icon(state.isConnected ? Icons.cast : Icons.cast_outlined, color: state.isConnected ? AppTheme.secondary : AppTheme.textMuted)),
      ]),
      onTap: onTap,
    );
  }
}

class _CastingControlsSheet extends StatelessWidget {
  const _CastingControlsSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CastingBloc, CastingBlocState>(
      builder: (context, state) {
        final castState = state.castState;
        
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.cast, color: AppTheme.secondary, size: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(state.connectedDevice?.name ?? 'Casting', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(castState.currentMediaTitle ?? 'Reproduciendo...', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                _buildPlayerStateBadge(castState.playerState.name),
              ]),
              const SizedBox(height: 24),
              if (castState.duration.inSeconds > 0) ...[_buildProgressBar(castState.position, castState.duration), const SizedBox(height: 16)],
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(onPressed: () => context.read<CastingBloc>().add(ToggleMute()), icon: Icon(castState.isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 28)),
                IconButton(onPressed: () { final p = castState.position - const Duration(seconds: 10); context.read<CastingBloc>().add(SeekMedia(p.isNegative ? Duration.zero : p)); }, icon: const Icon(Icons.replay_10, color: Colors.white, size: 32)),
                Container(decoration: BoxDecoration(color: AppTheme.secondary, borderRadius: BorderRadius.circular(30)), child: IconButton(onPressed: () { if (castState.isPlaying) { context.read<CastingBloc>().add(PauseMedia()); } else { context.read<CastingBloc>().add(PlayMedia()); } }, icon: Icon(castState.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36), padding: const EdgeInsets.all(12))),
                IconButton(onPressed: () { context.read<CastingBloc>().add(SeekMedia(castState.position + const Duration(seconds: 10))); }, icon: const Icon(Icons.forward_10, color: Colors.white, size: 32)),
                IconButton(onPressed: () { context.read<CastingBloc>().add(StopMedia()); Navigator.pop(context); }, icon: const Icon(Icons.stop, color: Colors.white, size: 28)),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerStateBadge(String state) {
    Color color = AppTheme.textMuted;
    switch (state.toLowerCase()) { case 'playing': color = Colors.green; break; case 'paused': color = AppTheme.warning; break; case 'buffering': color = AppTheme.primary; break; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(state.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _buildProgressBar(Duration position, Duration duration) {
    final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;
    return Column(children: [
      LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondary), minHeight: 4, borderRadius: BorderRadius.circular(2)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_formatDuration(position), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)), Text(_formatDuration(duration), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))]),
    ]);
  }

  String _formatDuration(Duration d) => '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

const String _videoDetectionJS = '''
(function() {
  var videos = []; var seen = {};
  function isValidUrl(url) { return url && (url.startsWith('http://') || url.startsWith('https://')) && !url.includes('blob:') && !url.includes('null'); }
  function getVideoTitle(v) {
    if (v.getAttribute('data-title')) return v.getAttribute('data-title');
    if (v.getAttribute('title') && v.getAttribute('title').length > 3) return v.getAttribute('title');
    var parent = v.parentElement;
    while (parent && parent.tagName !== 'BODY') {
      if (parent.getAttribute('data-title')) return parent.getAttribute('data-title');
      if (parent.getAttribute('title') && parent.getAttribute('title').length > 3) return parent.getAttribute('title');
      if (parent.className && parent.className.includes('video')) { var h = parent.querySelector('h1,h2,h3,h4,.title'); if (h) return h.textContent.trim().substring(0, 100); }
      parent = parent.parentElement;
    }
    if (document.querySelectorAll('video').length === 1 && document.title) return document.title.substring(0, 100);
    var og = document.querySelector('meta[property="og:title"]'); if (og) return og.getAttribute('content');
    return null;
  }
  document.querySelectorAll('video').forEach(function(v) {
    var title = getVideoTitle(v);
    if (isValidUrl(v.src)) { seen[v.src] = true; videos.push({url: v.src, type: 'video', quality: v.videoHeight > 0 ? String(v.videoHeight) : '', duration: v.duration > 0 && isFinite(v.duration) ? Math.floor(v.duration) : 0, title: title}); }
    if (isValidUrl(v.currentSrc)) { seen[v.currentSrc] = true; videos.push({url: v.currentSrc, type: 'video', quality: v.videoHeight > 0 ? String(v.videoHeight) : '', duration: v.duration > 0 && isFinite(v.duration) ? Math.floor(v.duration) : 0, title: title}); }
    v.querySelectorAll('source').forEach(function(s) { if (isValidUrl(s.src)) { seen[s.src] = true; videos.push({url: s.src, type: 'video', quality: s.getAttribute('data-res') || s.label || '', duration: v.duration > 0 && isFinite(v.duration) ? Math.floor(v.duration) : 0, title: title}); } });
  });
  document.querySelectorAll('source[type*="video"]').forEach(function(s) { if (isValidUrl(s.src)) { seen[s.src] = true; videos.push({url: s.src, type: 'video'}); } });
  ['data-src','data-video-url','data-video','data-stream-url','data-hls','data-mpd'].forEach(function(attr) { document.querySelectorAll('[' + attr + ']').forEach(function(el) { var val = el.getAttribute(attr); if (isValidUrl(val)) { var type = 'video'; if (val.includes('.m3u8')) type = 'hls'; else if (val.includes('.mpd')) type = 'dash'; else if (val.includes('.webm')) type = 'webm'; seen[val] = true; videos.push({url: val, type: type}); } }); });
  document.querySelectorAll('script').forEach(function(script) { try { var text = script.textContent || ''; [/https?:\\/\\/[^"'\\s<>]+\\.m3u8[^"'\\s<>]*/gi,/https?:\\/\\/[^"'\\s<>]+\\.mpd[^"'\\s<>]*/gi,/https?:\\/\\/[^"'\\s<>]+\\.mp4[^"'\\s<>]*/gi,/https?:\\/\\/[^"'\\s<>]+\\.webm[^"'\\s<>]*/gi,/"file"\\s*:\\s*"(https?:[^"]+\\.mp4[^"]*)"/gi,/"stream_url"\\s*:\\s*"(https?:[^"]+)"/gi].forEach(function(pattern) { var match; while ((match = pattern.exec(text)) !== null) { var url = match[1] || match[0]; if (isValidUrl(url)) { var type = 'video'; if (url.includes('.m3u8')) type = 'hls'; else if (url.includes('.mpd')) type = 'dash'; seen[url] = true; videos.push({url: url, type: type}); } } }); } catch(e) {} });
  if (window.jwplayer) { try { var jw = window.jwplayer(); if (jw.getPlaylistItem) { var item = jw.getPlaylistItem(); if (item && isValidUrl(item.file)) { seen[item.file] = true; videos.push({url: item.file, type: 'video', quality: item.height || '', title: item.title || '', duration: item.duration || 0}); } } } catch(e) {} }
  if (window.videojs) { try { document.querySelectorAll('video-js').forEach(function(v) { var src = v.getAttribute('src'); if (isValidUrl(src)) { seen[src] = true; videos.push({url: src, type: 'video'}); } }); } catch(e) {} }
  document.querySelectorAll('embed').forEach(function(e) { var src = e.getAttribute('src') || ''; if (isValidUrl(src) && (src.includes('.mp4') || src.includes('.webm') || src.includes('.m3u8'))) { seen[src] = true; videos.push({url: src, type: 'video'}); } });
  document.querySelectorAll('object').forEach(function(o) { var data = o.getAttribute('data') || ''; if (isValidUrl(data) && (data.includes('.mp4') || data.includes('.flv'))) { seen[data] = true; videos.push({url: data, type: 'video'}); } });
  return JSON.stringify(videos);
})();
''';
