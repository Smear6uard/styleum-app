/// Outfit Generation Providers
/// 
/// Riverpod 2.x providers for outfit state management
/// Handles loading states, caching, and real-time updates

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:styleum/models/outfit.dart';
import 'package:styleum/repositories/outfit_repository.dart';

/// Repository provider
final outfitRepositoryProvider = FutureProvider<OutfitRepository>((ref) async {
  return OutfitRepository.create();
});

/// Today's outfits state
final todaysOutfitsProvider = StateNotifierProvider<TodaysOutfitsNotifier, AsyncValue<List<ScoredOutfit>>>((ref) {
  final repoAsync = ref.watch(outfitRepositoryProvider);
  return TodaysOutfitsNotifier(ref, repoAsync);
});

/// Selected outfit index
final selectedOutfitIndexProvider = StateProvider<int>((ref) => 0);

/// Current weather context
final weatherContextProvider = StateProvider<WeatherContext?>((ref) => null);

/// User style preferences
final stylePreferencesProvider = StateProvider<StylePreferences?>((ref) => null);

/// Notifier for today's outfits
class TodaysOutfitsNotifier extends StateNotifier<AsyncValue<List<ScoredOutfit>>> {
  final Ref _ref;
  final AsyncValue<OutfitRepository> _repoAsync;

  TodaysOutfitsNotifier(this._ref, this._repoAsync) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _repoAsync.whenData((repo) => _loadOutfits(repo));
  }

  Future<void> _loadOutfits(OutfitRepository repo) async {
    state = const AsyncValue.loading();
    
    final weather = _ref.read(weatherContextProvider);
    final preferences = _ref.read(stylePreferencesProvider);

    final result = await repo.getTodaysOutfits(
      weather: weather,
      preferences: preferences,
    );

    if (result.isSuccess) {
      state = AsyncValue.data(result.outfits!);
    } else {
      state = AsyncValue.error(result.error!, StackTrace.current);
    }
  }

  /// Refresh outfits (force regeneration)
  Future<void> refresh() async {
    final repoResult = _repoAsync;
    if (!repoResult.hasValue) return;

    state = const AsyncValue.loading();
    
    final weather = _ref.read(weatherContextProvider);
    final preferences = _ref.read(stylePreferencesProvider);

    final result = await repoResult.value!.getTodaysOutfits(
      weather: weather,
      preferences: preferences,
      forceRefresh: true,
    );

    if (result.isSuccess) {
      state = AsyncValue.data(result.outfits!);
      _ref.read(selectedOutfitIndexProvider.notifier).state = 0;
    } else {
      state = AsyncValue.error(result.error!, StackTrace.current);
    }
  }

  /// Generate with new preferences (e.g., from Style Me screen)
  Future<void> generateWithPreferences(StylePreferences preferences) async {
    final repoResult = _repoAsync;
    if (!repoResult.hasValue) return;

    // Update preferences
    _ref.read(stylePreferencesProvider.notifier).state = preferences;

    state = const AsyncValue.loading();
    
    final weather = _ref.read(weatherContextProvider);

    final result = await repoResult.value!.getTodaysOutfits(
      weather: weather,
      preferences: preferences,
      forceRefresh: true,
    );

    if (result.isSuccess) {
      state = AsyncValue.data(result.outfits!);
      _ref.read(selectedOutfitIndexProvider.notifier).state = 0;
    } else {
      state = AsyncValue.error(result.error!, StackTrace.current);
    }
  }

  /// Mark selected outfit as worn
  Future<bool> markSelectedAsWorn() async {
    final repoResult = _repoAsync;
    if (!repoResult.hasValue) return false;

    final outfits = state.valueOrNull;
    if (outfits == null || outfits.isEmpty) return false;

    final selectedIndex = _ref.read(selectedOutfitIndexProvider);
    if (selectedIndex >= outfits.length) return false;

    final outfit = outfits[selectedIndex];
    return repoResult.value!.markAsWorn(outfit);
  }

  /// Save outfit to favorites
  Future<SaveResult> saveOutfit(int index) async {
    final repoResult = _repoAsync;
    if (!repoResult.hasValue) {
      return SaveResult.error('Repository not ready');
    }

    final outfits = state.valueOrNull;
    if (outfits == null || index >= outfits.length) {
      return SaveResult.error('Outfit not found');
    }

    // Check save limit (paywall trigger)
    final savedCount = await repoResult.value!.getSavedOutfitCount();
    if (savedCount >= 25) {
      return SaveResult.paywallTriggered(savedCount);
    }

    final success = await repoResult.value!.saveOutfit(outfits[index]);
    if (success) {
      return SaveResult.success(savedCount + 1);
    }
    return SaveResult.error('Failed to save outfit');
  }
}

/// Result of save operation
class SaveResult {
  final bool success;
  final int? savedCount;
  final bool paywallTriggered;
  final String? error;

  const SaveResult._({
    required this.success,
    this.savedCount,
    this.paywallTriggered = false,
    this.error,
  });

  factory SaveResult.success(int count) {
    return SaveResult._(success: true, savedCount: count);
  }

  factory SaveResult.paywallTriggered(int count) {
    return SaveResult._(
      success: false, 
      savedCount: count, 
      paywallTriggered: true,
    );
  }

  factory SaveResult.error(String message) {
    return SaveResult._(success: false, error: message);
  }
}

/// Selected outfit convenience provider
final selectedOutfitProvider = Provider<ScoredOutfit?>((ref) {
  final outfits = ref.watch(todaysOutfitsProvider).valueOrNull;
  final index = ref.watch(selectedOutfitIndexProvider);
  
  if (outfits == null || outfits.isEmpty || index >= outfits.length) {
    return null;
  }
  
  return outfits[index];
});

/// Loading state helper
final isGeneratingProvider = Provider<bool>((ref) {
  return ref.watch(todaysOutfitsProvider).isLoading;
});

/// Error state helper
final generationErrorProvider = Provider<String?>((ref) {
  final state = ref.watch(todaysOutfitsProvider);
  if (state.hasError) {
    return state.error.toString();
  }
  return null;
});
