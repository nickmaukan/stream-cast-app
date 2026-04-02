import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/video_stream.dart';
import '../../../../core/services/database_service.dart';

// Events
abstract class FavoritesEvent extends Equatable {
  const FavoritesEvent();
  @override
  List<Object?> get props => [];
}

class LoadFavorites extends FavoritesEvent {}

class AddToFavorites extends FavoritesEvent {
  final VideoStream video;
  const AddToFavorites(this.video);
  @override
  List<Object?> get props => [video];
}

class RemoveFromFavorites extends FavoritesEvent {
  final int id;
  const RemoveFromFavorites(this.id);
  @override
  List<Object?> get props => [id];
}

// State
class FavoritesState extends Equatable {
  final List<VideoStream> favorites;
  final bool isLoading;
  final String? error;

  const FavoritesState({
    this.favorites = const [],
    this.isLoading = false,
    this.error,
  });

  FavoritesState copyWith({
    List<VideoStream>? favorites,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [favorites, isLoading, error];
}

// Bloc
class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final DatabaseService _db;

  FavoritesBloc({DatabaseService? db})
      : _db = db ?? DatabaseService(),
        super(const FavoritesState()) {
    on<LoadFavorites>(_onLoadFavorites);
    on<AddToFavorites>(_onAddToFavorites);
    on<RemoveFromFavorites>(_onRemoveFromFavorites);
  }

  Future<void> _onLoadFavorites(LoadFavorites event, Emitter<FavoritesState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final favorites = await _db.getFavorites();
      emit(state.copyWith(favorites: favorites, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to load favorites', isLoading: false));
    }
  }

  Future<void> _onAddToFavorites(AddToFavorites event, Emitter<FavoritesState> emit) async {
    try {
      final video = event.video.copyWith(isFavorite: true);
      await _db.insertVideo(video);
      add(LoadFavorites());
    } catch (e) {
      emit(state.copyWith(error: 'Failed to add to favorites'));
    }
  }

  Future<void> _onRemoveFromFavorites(RemoveFromFavorites event, Emitter<FavoritesState> emit) async {
    try {
      await _db.toggleFavorite(event.id, false);
      add(LoadFavorites());
    } catch (e) {
      emit(state.copyWith(error: 'Failed to remove from favorites'));
    }
  }
}
