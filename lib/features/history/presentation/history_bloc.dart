import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/video_stream.dart';
import '../../../../core/services/database_service.dart';

// Events
abstract class HistoryEvent extends Equatable {
  const HistoryEvent();
  @override
  List<Object?> get props => [];
}

class LoadHistory extends HistoryEvent {}

class AddToHistory extends HistoryEvent {
  final VideoStream video;
  const AddToHistory(this.video);
  @override
  List<Object?> get props => [video];
}

class RemoveFromHistory extends HistoryEvent {
  final int id;
  const RemoveFromHistory(this.id);
  @override
  List<Object?> get props => [id];
}

class ClearHistory extends HistoryEvent {}

class ToggleFavorite extends HistoryEvent {
  final int id;
  final bool isFavorite;
  const ToggleFavorite(this.id, this.isFavorite);
  @override
  List<Object?> get props => [id, isFavorite];
}

class SearchHistory extends HistoryEvent {
  final String query;
  const SearchHistory(this.query);
  @override
  List<Object?> get props => [query];
}

// State
class HistoryState extends Equatable {
  final List<VideoStream> videos;
  final List<VideoStream> searchResults;
  final bool isLoading;
  final String? error;

  const HistoryState({
    this.videos = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.error,
  });

  bool get hasSearchResults => searchResults.isNotEmpty;

  HistoryState copyWith({
    List<VideoStream>? videos,
    List<VideoStream>? searchResults,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HistoryState(
      videos: videos ?? this.videos,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [videos, searchResults, isLoading, error];
}

// Bloc
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final DatabaseService _db;

  HistoryBloc({DatabaseService? db})
      : _db = db ?? DatabaseService(),
        super(const HistoryState()) {
    on<LoadHistory>(_onLoadHistory);
    on<AddToHistory>(_onAddToHistory);
    on<RemoveFromHistory>(_onRemoveFromHistory);
    on<ClearHistory>(_onClearHistory);
    on<ToggleFavorite>(_onToggleFavorite);
    on<SearchHistory>(_onSearchHistory);
  }

  Future<void> _onLoadHistory(LoadHistory event, Emitter<HistoryState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final videos = await _db.getHistory();
      emit(state.copyWith(videos: videos, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to load history', isLoading: false));
    }
  }

  Future<void> _onAddToHistory(AddToHistory event, Emitter<HistoryState> emit) async {
    try {
      // Check if exists
      final existing = await _db.getVideoByUrl(event.video.url);
      if (existing != null) {
        // Update last played
        await _db.incrementPlayCount(existing.id!);
      } else {
        await _db.insertVideo(event.video);
      }
      add(LoadHistory());
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _onRemoveFromHistory(RemoveFromHistory event, Emitter<HistoryState> emit) async {
    try {
      await _db.deleteVideo(event.id);
      add(LoadHistory());
    } catch (e) {
      emit(state.copyWith(error: 'Failed to remove'));
    }
  }

  Future<void> _onClearHistory(ClearHistory event, Emitter<HistoryState> emit) async {
    try {
      await _db.clearHistory();
      emit(state.copyWith(videos: []));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to clear history'));
    }
  }

  Future<void> _onToggleFavorite(ToggleFavorite event, Emitter<HistoryState> emit) async {
    try {
      await _db.toggleFavorite(event.id, event.isFavorite);
      add(LoadHistory());
    } catch (e) {
      emit(state.copyWith(error: 'Failed to toggle favorite'));
    }
  }

  Future<void> _onSearchHistory(SearchHistory event, Emitter<HistoryState> emit) async {
    if (event.query.isEmpty) {
      emit(state.copyWith(searchResults: []));
      return;
    }
    try {
      final results = await _db.searchVideos(event.query);
      emit(state.copyWith(searchResults: results));
    } catch (e) {
      emit(state.copyWith(error: 'Search failed'));
    }
  }
}
