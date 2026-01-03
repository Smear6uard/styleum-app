/// Claude Haiku Scoring Service
/// 
/// Uses OpenRouter → Claude 3 Haiku for fashion judgment + explanations
/// Implements BAML-style structured outputs for reliable JSON parsing
/// Cost: ~$0.002 per generation (well under budget)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:styleum/models/wardrobe_item.dart';
import 'package:styleum/models/outfit.dart';

/// Response from Claude Haiku
class HaikuScoringResponse {
  final List<ScoredOutfitData> outfits;
  final int tokensUsed;
  final Duration latency;

  const HaikuScoringResponse({
    required this.outfits,
    required this.tokensUsed,
    required this.latency,
  });
}

/// Scored outfit data from AI
class ScoredOutfitData {
  final int index;           // Which candidate (0-based)
  final int vibeScore;       // -5 to +5 adjustment
  final String whyItWorks;
  final String? stylingTip;
  final List<String> vibes;

  const ScoredOutfitData({
    required this.index,
    required this.vibeScore,
    required this.whyItWorks,
    this.stylingTip,
    this.vibes = const [],
  });

  factory ScoredOutfitData.fromJson(Map<String, dynamic> json) {
    return ScoredOutfitData(
      index: json['index'] as int? ?? 0,
      vibeScore: (json['vibe_score'] as int?)?.clamp(-5, 5) ?? 0,
      whyItWorks: json['why_it_works'] as String? ?? 'A well-coordinated outfit.',
      stylingTip: json['styling_tip'] as String?,
      vibes: (json['vibes'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Configuration for Haiku scoring
class HaikuConfig {
  final String apiKey;
  final String model;
  final int maxTokens;
  final double temperature;
  final Duration timeout;

  const HaikuConfig({
    required this.apiKey,
    this.model = 'anthropic/claude-3-haiku-20240307',
    this.maxTokens = 1500,
    this.temperature = 0.7,
    this.timeout = const Duration(seconds: 30),
  });
}

/// Claude Haiku scoring service
class HaikuScoringService {
  final HaikuConfig config;
  final http.Client _client;

  static const _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';

  HaikuScoringService({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Score candidates and select top outfits with explanations
  Future<HaikuScoringResponse> scoreOutfits({
    required List<OutfitCandidate> candidates,
    required WeatherContext? weather,
    required StylePreferences? preferences,
    int topN = 6,
  }) async {
    if (candidates.isEmpty) {
      return HaikuScoringResponse(
        outfits: [],
        tokensUsed: 0,
        latency: Duration.zero,
      );
    }

    final stopwatch = Stopwatch()..start();

    // Limit candidates sent to AI (cost optimization)
    final candidatesToScore = candidates.take(20).toList();

    // Build prompt
    final systemPrompt = _buildSystemPrompt(preferences);
    final userPrompt = _buildUserPrompt(
      candidates: candidatesToScore,
      weather: weather,
      preferences: preferences,
      topN: topN,
    );

    try {
      final response = await _callOpenRouter(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      stopwatch.stop();

      final parsed = _parseResponse(response['content'], candidatesToScore.length);
      final tokensUsed = response['tokens'] as int? ?? 0;

      return HaikuScoringResponse(
        outfits: parsed,
        tokensUsed: tokensUsed,
        latency: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      // Fallback: return rule-scored order
      return HaikuScoringResponse(
        outfits: candidatesToScore.take(topN).indexed.map((entry) {
          return ScoredOutfitData(
            index: entry.$1,
            vibeScore: 0,
            whyItWorks: 'A solid outfit choice.',
          );
        }).toList(),
        tokensUsed: 0,
        latency: stopwatch.elapsed,
      );
    }
  }

  /// Build system prompt with persona
  String _buildSystemPrompt(StylePreferences? preferences) {
    return '''You are a sharp, friendly personal stylist with editorial taste. Your job is to evaluate outfit combinations and explain why they work in a warm, confident tone.

Style Guidelines:
- Be specific about WHY pieces work together (colors, textures, silhouettes)
- Keep explanations under 25 words - punchy, not preachy
- Use fashion-forward but accessible language
- Sound like a stylish friend, not a robot
- Highlight unexpected combinations that work
- Reference trends when relevant (oversized silhouettes, quiet luxury, etc.)

${preferences?.styleGoal != null ? "User's style goal: ${preferences!.styleGoal}" : ""}

Output Format (CRITICAL - respond ONLY with valid JSON array):
[
  {
    "index": 0,
    "vibe_score": 3,
    "why_it_works": "The structured blazer balances the relaxed denim perfectly.",
    "styling_tip": "Roll the sleeves for extra polish.",
    "vibes": ["effortless", "polished"]
  }
]

Rules:
- vibe_score: -5 (avoid) to +5 (chef's kiss)
- why_it_works: 15-25 words max
- styling_tip: optional, 10 words max
- vibes: 1-3 single-word descriptors''';
  }

  /// Build user prompt with candidates
  String _buildUserPrompt({
    required List<OutfitCandidate> candidates,
    required WeatherContext? weather,
    required StylePreferences? preferences,
    required int topN,
  }) {
    final buffer = StringBuffer();

    // Context
    if (weather != null) {
      buffer.writeln('CONTEXT: ${weather.toPromptDescription()}');
    }
    if (preferences?.occasion != null) {
      buffer.writeln('OCCASION: ${preferences!.occasion}');
    }
    if (preferences?.boldnessLevel != null) {
      final boldness = ['very conservative', 'conservative', 'balanced', 'bold', 'very bold'][preferences!.boldnessLevel - 1];
      buffer.writeln('STYLE PREFERENCE: $boldness');
    }
    buffer.writeln();

    // Candidates
    buffer.writeln('OUTFIT OPTIONS:');
    for (var i = 0; i < candidates.length; i++) {
      buffer.writeln('[$i] ${candidates[i].toPromptDescription()}');
      buffer.writeln('---');
    }

    buffer.writeln();
    buffer.writeln('Select the TOP $topN outfits. Return ONLY a JSON array, no other text.');

    return buffer.toString();
  }

  /// Call OpenRouter API
  Future<Map<String, dynamic>> _callOpenRouter({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final response = await _client.post(
      Uri.parse(_openRouterUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
        'HTTP-Referer': 'https://styleum.app',
        'X-Title': 'Styleum',
      },
      body: jsonEncode({
        'model': config.model,
        'max_tokens': config.maxTokens,
        'temperature': config.temperature,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    ).timeout(config.timeout);

    if (response.statusCode != 200) {
      throw Exception('OpenRouter error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    final usage = data['usage'] as Map<String, dynamic>?;
    final totalTokens = (usage?['total_tokens'] as int?) ?? 0;

    return {
      'content': content ?? '[]',
      'tokens': totalTokens,
    };
  }

  /// Parse response with fuzzy JSON handling (BAML-style)
  List<ScoredOutfitData> _parseResponse(String content, int maxIndex) {
    // Step 1: Extract JSON array from response
    var jsonStr = content.trim();
    
    // Handle markdown code blocks
    if (jsonStr.contains('```')) {
      final match = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(jsonStr);
      if (match != null) {
        jsonStr = match.group(1) ?? jsonStr;
      }
    }

    // Find JSON array bounds
    final startIndex = jsonStr.indexOf('[');
    final endIndex = jsonStr.lastIndexOf(']');
    if (startIndex != -1 && endIndex > startIndex) {
      jsonStr = jsonStr.substring(startIndex, endIndex + 1);
    }

    // Step 2: Fuzzy parse (handle common LLM JSON errors)
    jsonStr = _fixCommonJsonErrors(jsonStr);

    try {
      final parsed = jsonDecode(jsonStr) as List<dynamic>;
      return parsed
          .map((item) => ScoredOutfitData.fromJson(item as Map<String, dynamic>))
          .where((outfit) => outfit.index >= 0 && outfit.index < maxIndex)
          .toList();
    } catch (e) {
      // Fallback: try to extract individual objects
      return _extractObjectsFallback(jsonStr, maxIndex);
    }
  }

  /// Fix common JSON errors from LLMs
  String _fixCommonJsonErrors(String json) {
    var fixed = json;

    // Remove trailing commas before ] or }
    fixed = fixed.replaceAll(RegExp(r',(\s*[}\]])'), r'\1');

    // Fix unquoted keys
    fixed = fixed.replaceAllMapped(
      RegExp(r'(\{|\,)\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:'),
      (m) => '${m.group(1)}"${m.group(2)}":',
    );

    // Fix single quotes to double quotes
    fixed = fixed.replaceAll("'", '"');

    // Fix missing quotes around string values
    fixed = fixed.replaceAllMapped(
      RegExp(r':\s*([a-zA-Z][a-zA-Z0-9\s]*[a-zA-Z0-9])\s*(,|}|])'),
      (m) {
        final value = m.group(1)!;
        // Skip if it's a number, boolean, or null
        if (RegExp(r'^(true|false|null|\d+)$').hasMatch(value)) {
          return ':$value${m.group(2)}';
        }
        return ':"$value"${m.group(2)}';
      },
    );

    return fixed;
  }

  /// Fallback extraction for badly malformed JSON
  List<ScoredOutfitData> _extractObjectsFallback(String content, int maxIndex) {
    final results = <ScoredOutfitData>[];
    
    // Try to find individual object patterns
    final objectPattern = RegExp(
      r'\{\s*"?index"?\s*:\s*(\d+)[^}]*"?why_it_works"?\s*:\s*"([^"]+)"[^}]*\}',
      multiLine: true,
    );

    for (final match in objectPattern.allMatches(content)) {
      final index = int.tryParse(match.group(1) ?? '') ?? 0;
      final why = match.group(2) ?? 'A well-coordinated outfit.';

      if (index >= 0 && index < maxIndex) {
        results.add(ScoredOutfitData(
          index: index,
          vibeScore: 0,
          whyItWorks: why,
        ));
      }
    }

    return results;
  }

  void dispose() {
    _client.close();
  }
}
