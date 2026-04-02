import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/video_source.dart';

/// Service for detecting and extracting videos from web pages
class VideoDetectorService {
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36';

  /// JavaScript for video detection (injected into WebView)
  static const String videoDetectionJS = '''
(function() {
  var videos = [];

  // 1. Detect video tags
  document.querySelectorAll('video, video source, source').forEach(function(el) {
    var src = el.src || el.currentSrc || el.getAttribute('data-src');
    if (src && src.trim() !== '' && src.indexOf('blob:') !== 0) {
      videos.push({url: src, type: el.tagName === 'VIDEO' ? 'video_tag' : 'source_tag'});
    }
  });

  // 2. Detect in iframes (same origin)
  try {
    document.querySelectorAll('iframe').forEach(function(iframe) {
      try {
        var iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
        iframeDoc.querySelectorAll('video, source').forEach(function(el) {
          var src = el.src || el.currentSrc;
          if (src && src.trim() !== '' && src.indexOf('blob:') !== 0) {
            videos.push({url: src, type: 'iframe_video'});
          }
        });
      } catch(e) {}
    });
  } catch(e) {}

  // 3. Detect in data attributes
  var dataAttrs = ['data-src', 'data-video-url', 'data-stream', 'data-video', 'data-hls'];
  document.querySelectorAll('[data-src], [data-video-url], [data-stream]').forEach(function(el) {
    dataAttrs.forEach(function(attr) {
      var val = el.getAttribute(attr);
      if (val && val.trim() !== '') {
        if (val.indexOf('.m3u8') >= 0 || val.indexOf('.mp4') >= 0 || val.indexOf('.webm') >= 0 || val.indexOf('.mpd') >= 0) {
          videos.push({url: val, type: 'data_attribute'});
        }
      }
    });
  });

  // 4. Detect M3U8 and MPD in scripts
  document.querySelectorAll('script').forEach(function(script) {
    var content = script.textContent || '';
    var m3u8Re = /https?:\\/\\/[^\\s"'<>]+\\.m3u8[^\\s"'<>]*/gi;
    var mpdRe = /https?:\\/\\/[^\\s"'<>]+\\.mpd[^\\s"'<>]*/gi;
    var m;
    while ((m = m3u8Re.exec(content)) !== null) { videos.push({url: m[0], type: 'script_m3u8'}); }
    while ((m = mpdRe.exec(content)) !== null) { videos.push({url: m[0], type: 'script_mpd'}); }
  });

  // 5. Detect in href/src links
  document.querySelectorAll('a[href], source[src]').forEach(function(el) {
    var href = el.href || el.src;
    if (href && (href.indexOf('.m3u8') >= 0 || href.indexOf('.mp4') >= 0 || href.indexOf('.webm') >= 0 || href.indexOf('.mpd') >= 0)) {
      videos.push({url: href, type: 'link_video'});
    }
  });

  // 6. Check player instances
  if (window.jwplayer) {
    try {
      var jw = window.jwplayer();
      if (jw.getPlaylistItem) {
        var item = jw.getPlaylistItem();
        if (item && item.file) {
          videos.push({url: item.file, type: 'jw_player', title: item.title});
        }
      }
    } catch(e) {}
  }

  // 7. Filter duplicates
  var seen = {};
  videos = videos.filter(function(v) {
    if (!v.url || v.url.trim() === '' || v.url.indexOf('blob:') === 0 || v.url === 'null') return false;
    var key = v.url.split('?')[0];
    if (seen[key]) return false;
    seen[key] = true;
    return true;
  });

  // 8. Determine types
  videos = videos.map(function(v) {
    var type = 'mp4';
    if (v.url.indexOf('.m3u8') >= 0) type = 'hls';
    else if (v.url.indexOf('.mpd') >= 0) type = 'dash';
    else if (v.url.indexOf('.webm') >= 0) type = 'webm';
    else if (v.url.indexOf('.mkv') >= 0) type = 'mkv';
    return {url: v.url, type: v.type, videoType: type};
  });

  return {videos: videos, count: videos.length, pageUrl: window.location.href, pageTitle: document.title};
})();
''';

  /// Extract videos from a URL (HTTP fetch + parse)
  Future<List<VideoSource>> extractVideos(String url) async {
    try {
      if (_isYouTube(url)) {
        final video = await _extractYouTube(url);
        return video != null ? [video] : [];
      }

      if (_isVimeo(url)) {
        final video = await _extractVimeo(url);
        return video != null ? [video] : [];
      }

      return await _extractFromPage(url);
    } catch (e) {
      debugPrint('Video extraction error: $e');
      return [];
    }
  }

  /// Parse JS detection results from WebView
  List<VideoSource> parseJsResults(dynamic jsResult) {
    if (jsResult == null) return [];

    try {
      if (jsResult is Map) {
        final videoList = jsResult['videos'] as List? ?? [];
        return videoList.map((v) {
          if (v is Map) {
            final url = v['url']?.toString();
            if (url == null || url.isEmpty) return null;

            final typeStr = v['videoType']?.toString() ?? 'mp4';
            return VideoSource(
              url: url,
              title: v['title']?.toString(),
              thumbnail: v['poster']?.toString(),
              type: _parseType(typeStr),
            );
          }
          return null;
        }).whereType<VideoSource>().toList();
      }
    } catch (e) {
      debugPrint('JS result parsing error: $e');
    }

    return [];
  }

  VideoSourceType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'hls': return VideoSourceType.hls;
      case 'dash': case 'mpd': return VideoSourceType.dash;
      case 'webm': return VideoSourceType.webm;
      case 'mov': return VideoSourceType.mov;
      case 'mp4': default: return VideoSourceType.mp4;
    }
  }

  bool _isYouTube(String url) =>
      url.contains('youtube.com') || url.contains('youtu.be');

  bool _isVimeo(String url) => url.contains('vimeo.com');

  Future<VideoSource?> _extractYouTube(String url) async {
    try {
      final videoId = _extractYouTubeId(url);
      if (videoId == null) return null;

      final response = await http.get(
        Uri.parse('https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return VideoSource(
          url: url,
          title: data['title'] as String?,
          thumbnail: data['thumbnail_url'] as String?,
          type: VideoSourceType.youtube,
        );
      }
    } catch (e) {
      debugPrint('YouTube extraction error: $e');
    }
    return null;
  }

  Future<VideoSource?> _extractVimeo(String url) async {
    try {
      final videoId = _extractVimeoId(url);
      if (videoId == null) return null;

      final response = await http.get(
        Uri.parse('https://vimeo.com/api/oembed.json?url=https://vimeo.com/$videoId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return VideoSource(
          url: url,
          title: data['title'] as String?,
          thumbnail: data['thumbnail_url'] as String?,
          type: VideoSourceType.vimeo,
        );
      }
    } catch (e) {
      debugPrint('Vimeo extraction error: $e');
    }
    return null;
  }

  Future<List<VideoSource>> _extractFromPage(String url) async {
    final videos = <VideoSource>[];

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode != 200) return videos;

      final html = response.body;
      final document = html_parser.parse(html);

      videos.addAll(_extractHtml5Videos(document, url));
      videos.addAll(_extractIframeVideos(document, url));
      videos.addAll(_extractM3U8Links(html, url));
      videos.addAll(_extractMpdLinks(html, url));
    } catch (e) {
      debugPrint('Page extraction error: $e');
    }

    return videos;
  }

  List<VideoSource> _extractHtml5Videos(dynamic document, String pageUrl) {
    final videos = <VideoSource>[];
    final videoElements = document.getElementsByTagName('video');

    for (final video in videoElements) {
      final src = video.attributes['src'];
      final poster = video.attributes['poster'];

      if (src != null && src.isNotEmpty && !src.startsWith('blob:')) {
        final fullUrl = _resolveUrl(src, pageUrl);
        if (_isVideoUrl(fullUrl)) {
          videos.add(VideoSource(
            url: fullUrl,
            thumbnail: poster != null ? _resolveUrl(poster, pageUrl) : null,
            type: VideoSourceType.fromUrl(fullUrl),
          ));
        }
      }

      final sources = video.getElementsByTagName('source');
      for (final source in sources) {
        final src = source.attributes['src'];
        if (src != null && _isVideoUrl(src)) {
          videos.add(VideoSource(
            url: _resolveUrl(src, pageUrl),
            thumbnail: poster != null ? _resolveUrl(poster, pageUrl) : null,
            type: VideoSourceType.fromUrl(src),
          ));
        }
      }
    }

    return videos;
  }

  List<VideoSource> _extractIframeVideos(dynamic document, String pageUrl) {
    final videos = <VideoSource>[];
    final iframes = document.getElementsByTagName('iframe');

    for (final iframe in iframes) {
      final src = iframe.attributes['src'];
      if (src == null) continue;

      final ytMatch = RegExp(r'youtube\.com/embed/([\w-]+)').firstMatch(src);
      if (ytMatch != null) {
        videos.add(VideoSource(
          url: 'https://www.youtube.com/watch?v=${ytMatch.group(1)}',
          type: VideoSourceType.youtube,
        ));
      }

      final vimeoMatch = RegExp(r'player\.vimeo\.com/video/(\d+)').firstMatch(src);
      if (vimeoMatch != null) {
        videos.add(VideoSource(
          url: 'https://vimeo.com/${vimeoMatch.group(1)}',
          type: VideoSourceType.vimeo,
        ));
      }
    }

    return videos;
  }

  static final _m3u8Re = RegExp("https?://[^\\s\"'<>]+\\.m3u8[^\\s\"'<>]*");
  static final _mpdRe = RegExp("https?://[^\\s\"'<>]+\\.mpd[^\\s\"'<>]*");

  List<VideoSource> _extractM3U8Links(String html, String pageUrl) {
    return _m3u8Re.allMatches(html)
        .map((m) => m.group(0))
        .where((url) => url != null)
        .map((url) => VideoSource(url: url!, type: VideoSourceType.hls))
        .toList();
  }

  List<VideoSource> _extractMpdLinks(String html, String pageUrl) {
    return _mpdRe.allMatches(html)
        .map((m) => m.group(0))
        .where((url) => url != null)
        .map((url) => VideoSource(url: url!, type: VideoSourceType.dash))
        .toList();
  }

  String _resolveUrl(String url, String pageUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) {
      final uri = Uri.parse(pageUrl);
      return '${uri.scheme}://${uri.host}$url';
    }
    return url;
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.m3u8') ||
        lower.contains('.mpd') ||
        lower.contains('.webm') ||
        lower.contains('.mov') ||
        lower.contains('.mkv') ||
        lower.contains('manifest') ||
        lower.contains('playlist');
  }

  String? _extractYouTubeId(String url) {
    final patterns = [
      RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([^&\s]+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _extractVimeoId(String url) {
    return RegExp(r'vimeo\.com/(\d+)').firstMatch(url)?.group(1);
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print('[VideoDetector] $message');
}
