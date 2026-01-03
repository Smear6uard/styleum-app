/// AI Analysis Providers
/// 
/// Riverpod providers for:
/// - Item analysis state
/// - User style profile
/// - Vibe management
/// - Active learning interactions

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:styleum/models/ai_analysis.dart';
import 'package:styleum/services/ai_analysis_service.dart';

// ============================================
// SERVICE PROVIDERS
// ============================================

final aiAnalysisServiceProvider = Provider<AIAnalysisService>((ref) {
  return AIAnalysisService();
});

final styleLearningServiceProvider = Provider<StyleLearningService>((ref) {
  return StyleLearningService();
});

// ============================================
// ANALYSIS PROVIDERS
// ============================================

/// Provider for analyzing a single item
/// Usage: ref.read(analyzeItemProvider({'itemId': '...', 'imageUrl': '...'}))
final analyzeItemProvider = FutureProvider.family<AnalysisTriggerResult, Map<String, String>>((ref, params) async {
  final service = ref.read(aiAnalysisServiceProvider);
  return service.analyzeItem(
    itemId: params['itemId']!,
    imageUrl: params['imageUrl']!,
    userContext: params['userContext'],
  );
});

/// Provider for getting analysis of an item
final itemAnalysisProvider = FutureProvider.family<AIAnalysisResult?, String>((ref, itemId) async {
  final service = ref.read(aiAnalysisServiceProvider);
  return service.getAnalysis(itemId);
});

/// Provider for analysis status
final analysisStatusProvider = FutureProvider.family<AnalysisStatus, String>((ref, itemId) async {
  final service = ref.read(aiAnalysisServiceProvider);
  return service.getAnalysisStatus(itemId);
});

// ============================================
// VIBE PROVIDERS
// ============================================

/// All available vibes
final availableVibesProvider = FutureProvider<List<VibeAnchor>>((ref) async {
  final service = ref.read(aiAnalysisServiceProvider);
  return service.getAvailableVibes();
});

// ============================================
// STYLE PROFILE PROVIDERS
// ============================================

/// User's style profile (learned preferences)
final userStyleProfileProvider = FutureProvider<UserStyleProfile>((ref) async {
  final service = ref.read(styleLearningServiceProvider);
  return service.getStyleProfile();
});

/// Whether user has enough interactions for personalized recommendations
final hasLearnedPreferencesProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(userStyleProfileProvider).whenData((profile) => profile.hasLearnedPreferences);
});

/// User's top vibes
final userTopVibesProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(userStyleProfileProvider).whenData((profile) => profile.topVibes);
});

// ============================================
// INTERACTION NOTIFIERS
// ============================================

/// Notifier for recording style interactions
class StyleInteractionNotifier extends StateNotifier<AsyncValue<void>> {
  final StyleLearningService _service;
  final Ref _ref;

  StyleInteractionNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  /// Confirm a vibe on an item
  Future<bool> confirmVibe(String itemId, String vibeName) async {
    state = const AsyncValue.loading();
    final success = await _service.confirmVibe(itemId, vibeName);
    state = const AsyncValue.data(null);
    if (success) {
      _ref.invalidate(userStyleProfileProvider);
    }
    return success;
  }

  /// Reject a vibe on an item
  Future<bool> rejectVibe(String itemId, String vibeName) async {
    state = const AsyncValue.loading();
    final success = await _service.rejectVibe(itemId, vibeName);
    state = const AsyncValue.data(null);
    if (success) {
      _ref.invalidate(userStyleProfileProvider);
    }
    return success;
  }

  /// Edit a tag
  Future<bool> editTag({
    required String itemId,
    required String field,
    required String oldValue,
    required String newValue,
  }) async {
    state = const AsyncValue.loading();
    final success = await _service.editTag(
      itemId: itemId,
      field: field,
      oldValue: oldValue,
      newValue: newValue,
    );
    state = const AsyncValue.data(null);
    if (success) {
      _ref.invalidate(userStyleProfileProvider);
      _ref.invalidate(itemAnalysisProvider(itemId));
    }
    return success;
  }

  /// Mark outfit as worn
  Future<bool> markWorn(String outfitId) async {
    state = const AsyncValue.loading();
    final success = await _service.markOutfitWorn(outfitId);
    state = const AsyncValue.data(null);
    if (success) {
      _ref.invalidate(userStyleProfileProvider);
    }
    return success;
  }

  /// Save outfit
  Future<bool> saveOutfit(String outfitId) async {
    state = const AsyncValue.loading();
    final success = await _service.saveOutfit(outfitId);
    state = const AsyncValue.data(null);
    if (success) {
      _ref.invalidate(userStyleProfileProvider);
    }
    return success;
  }

  /// Reject outfit
  Future<bool> rejectOutfit(String outfitId) async {
    state = const AsyncValue.loading();
    final success = await _service.rejectOutfit(outfitId);
    state = const AsyncValue.data(null);
    if (success) {
      _ref.invalidate(userStyleProfileProvider);
    }
    return success;
  }

  /// Skip outfit (swipe past without action)
  Future<bool> skipOutfit(String outfitId) async {
    // Fire and forget for skips - don't show loading
    final success = await _service.skipOutfit(outfitId);
    if (success) {
      _ref.invalidate(userStyleProfileProvider);
    }
    return success;
  }
}

final styleInteractionProvider = StateNotifierProvider<StyleInteractionNotifier, AsyncValue<void>>((ref) {
  final service = ref.read(styleLearningServiceProvider);
  return StyleInteractionNotifier(service, ref);
});

// ============================================
// ANALYSIS STATE NOTIFIER
// ============================================

/// State for an item being analyzed
class ItemAnalysisState {
  final String itemId;
  final AnalysisStatus status;
  final AIAnalysisResult? result;
  final String? error;

  const ItemAnalysisState({
    required this.itemId,
    this.status = AnalysisStatus.pending,
    this.result,
    this.error,
  });

  ItemAnalysisState copyWith({
    AnalysisStatus? status,
    AIAnalysisResult? result,
    String? error,
  }) {
    return ItemAnalysisState(
      itemId: itemId,
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

/// Notifier for managing item analysis
class ItemAnalysisNotifier extends StateNotifier<ItemAnalysisState> {
  final AIAnalysisService _service;
  final Ref _ref;

  ItemAnalysisNotifier(this._service, this._ref, String itemId)
      : super(ItemAnalysisState(itemId: itemId));

  /// Start analysis for the item
  Future<void> analyze(String imageUrl, {String? userContext}) async {
    state = state.copyWith(status: AnalysisStatus.analyzing);

    final result = await _service.analyzeItem(
      itemId: state.itemId,
      imageUrl: imageUrl,
      userContext: userContext,
    );

    if (result.success && result.analysis != null) {
      state = state.copyWith(
        status: AnalysisStatus.completed,
        result: result.analysis,
      );
    } else {
      state = state.copyWith(
        status: AnalysisStatus.failed,
        error: result.error,
      );
    }
  }

  /// Load existing analysis
  Future<void> loadExisting() async {
    final analysis = await _service.getAnalysis(state.itemId);
    if (analysis != null) {
      state = state.copyWith(
        status: AnalysisStatus.completed,
        result: analysis,
      );
    }
  }
}

/// Provider for managing a specific item's analysis
final itemAnalysisNotifierProvider = StateNotifierProvider.family<ItemAnalysisNotifier, ItemAnalysisState, String>((ref, itemId) {
  final service = ref.read(aiAnalysisServiceProvider);
  return ItemAnalysisNotifier(service, ref, itemId);
});
