import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/video_source.dart';
import '../../../../core/services/video_detector_service.dart';

// Events
abstract class BrowserEvent extends Equatable {
  const BrowserEvent();

  @override
  List<Object?> get props => [];
}

class PageStartedLoading extends BrowserEvent {
  final String url;
  const PageStartedLoading(this.url);

  @override
  List<Object?> get props => [url];
}

class PageFinishedLoading extends BrowserEvent {
  final String url;
  final String? title;
  const PageFinishedLoading(this.url, {this.title});

  @override
  List<Object?> get props => [url, title];
}

class VideosDetected extends BrowserEvent {
  final List<VideoSource> videos;
  const VideosDetected(this.videos);

  @override
  List<Object?> get props => [videos];
}

class SearchVideos extends BrowserEvent {}

class ClearVideos extends BrowserEvent {}

class UpdateProgress extends BrowserEvent {
  final double progress;
  const UpdateProgress(this.progress);

  @override
  List<Object?> get props => [progress];
}

class NavigateTo extends BrowserEvent {
  final String url;
  const NavigateTo(this.url);

  @override
  List<Object?> get props => [url];
}

class GoBack extends BrowserEvent {}

class GoForward extends BrowserEvent {}

class Reload extends BrowserEvent {}

class UpdateTitle extends BrowserEvent {
  final String title;
  const UpdateTitle(this.title);

  @override
  List<Object?> get props => [title];
}

// State
class BrowserState extends Equatable {
  final String currentUrl;
  final String currentTitle;
  final List<VideoSource> detectedVideos;
  final bool hasVideos;
  final bool isLoading;
  final double loadProgress;
  final bool canGoBack;
  final bool canGoForward;
  final String? error;

  const BrowserState({
    this.currentUrl = '',
    this.currentTitle = 'Navegador',
    this.detectedVideos = const [],
    this.hasVideos = false,
    this.isLoading = false,
    this.loadProgress = 0,
    this.canGoBack = false,
    this.canGoForward = false,
    this.error,
  });

  BrowserState copyWith({
    String? currentUrl,
    String? currentTitle,
    List<VideoSource>? detectedVideos,
    bool? hasVideos,
    bool? isLoading,
    double? loadProgress,
    bool? canGoBack,
    bool? canGoForward,
    String? error,
    bool clearError = false,
  }) {
    return BrowserState(
      currentUrl: currentUrl ?? this.currentUrl,
      currentTitle: currentTitle ?? this.currentTitle,
      detectedVideos: detectedVideos ?? this.detectedVideos,
      hasVideos: hasVideos ?? this.hasVideos,
      isLoading: isLoading ?? this.isLoading,
      loadProgress: loadProgress ?? this.loadProgress,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    currentUrl,
    currentTitle,
    detectedVideos,
    hasVideos,
    isLoading,
    loadProgress,
    canGoBack,
    canGoForward,
    error,
  ];
}

// Bloc
class BrowserBloc extends Bloc<BrowserEvent, BrowserState> {
  final VideoDetectorService _detectorService;
  Timer? _searchDebounce;

  BrowserBloc({VideoDetectorService? detectorService})
      : _detectorService = detectorService ?? VideoDetectorService(),
        super(const BrowserState()) {
    on<PageStartedLoading>(_onPageStartedLoading);
    on<PageFinishedLoading>(_onPageFinishedLoading);
    on<VideosDetected>(_onVideosDetected);
    on<ClearVideos>(_onClearVideos);
    on<UpdateProgress>(_onUpdateProgress);
    on<UpdateTitle>(_onUpdateTitle);
  }

  void _onPageStartedLoading(PageStartedLoading event, Emitter<BrowserState> emit) {
    emit(state.copyWith(
      currentUrl: event.url,
      isLoading: true,
      hasVideos: false,
      detectedVideos: [],
    ));
  }

  void _onPageFinishedLoading(PageFinishedLoading event, Emitter<BrowserState> emit) {
    emit(state.copyWith(
      currentUrl: event.url,
      currentTitle: event.title ?? state.currentTitle,
      isLoading: false,
    ));

    // Debounce video search
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(seconds: 2), () {
      add(SearchVideos());
    });
  }

  void _onVideosDetected(VideosDetected event, Emitter<BrowserState> emit) {
    emit(state.copyWith(
      detectedVideos: event.videos,
      hasVideos: event.videos.isNotEmpty,
    ));
  }

  void _onClearVideos(ClearVideos event, Emitter<BrowserState> emit) {
    emit(state.copyWith(
      detectedVideos: [],
      hasVideos: false,
    ));
  }

  void _onUpdateProgress(UpdateProgress event, Emitter<BrowserState> emit) {
    emit(state.copyWith(loadProgress: event.progress));
  }

  void _onUpdateTitle(UpdateTitle event, Emitter<BrowserState> emit) {
    emit(state.copyWith(currentTitle: event.title));
  }

  Future<List<VideoSource>> searchVideosInPage(dynamic webViewController) async {
    try {
      final result = await webViewController.evaluateJavascript(
        source: VideoDetectorService.videoDetectionJS,
      );

      if (result != null) {
        final videos = _detectorService.parseJsResults(result);
        add(VideosDetected(videos));
        return videos;
      }
    } catch (e) {
      // Ignore errors during video search
    }
    return [];
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }
}
