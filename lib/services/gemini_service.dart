import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/env.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl:
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Parses a voice transcript into structured intent using Gemini.
  Future<GeminiIntent?> parseVoiceCommand(
      String transcript, List<String> availableGenres) async {
    final prompt = '''
You are a music player voice assistant. Parse this command into structured JSON.

User said: "$transcript"

Available genres in their library: ${availableGenres.join(', ')}

Return ONLY valid JSON (no markdown, no explanation):
{
  "intent": "play_genre" | "play_mood" | "play_random" | "control" | "whats_playing" | "like_song",
  "genre": "genre name if applicable or null",
  "mood": "happy | sad | energetic | calm | focus or null",
  "control_action": "pause | resume | next | previous or null",
  "confidence": 0.0-1.0,
  "explanation": "brief reason"
}

If genre mentioned, match closest from available genres. If mood, map to genre intelligently.
''';

    try {
      final response = await _dio.post(
        '',
        queryParameters: {'key': Env.geminiKey},
        data: {
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 200,
          },
        },
      );

      final text = response.data['candidates']?[0]?['content']?['parts']?[0]
      ?['text'] as String?;
      if (text == null) return null;

      // Clean up and parse JSON
      final clean = text.trim()
          .replaceAll('```json', '').replaceAll('```', '').trim();
      final json = jsonDecode(clean) as Map<String, dynamic>;

      return GeminiIntent.fromJson(json);
    } catch (e) {
      debugPrint('[Gemini] Parse error: $e');
      return null;
    }
  }

  /// Gets song recommendations by genre/mood.
  Future<List<String>> getSongRecommendations({
    required String genre,
    int count = 5,
  }) async {
    final prompt = '''
List $count popular ${genre} songs that someone might have on their phone. 
Return ONLY a JSON array of strings in format "Artist - Title". No explanation.
Example: ["Artist1 - Song1", "Artist2 - Song2"]
''';
    try {
      final response = await _dio.post(
        '',
        queryParameters: {'key': Env.geminiKey},
        data: {
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 300},
        },
      );

      final text = response.data['candidates']?[0]?['content']?['parts']?[0]
      ?['text'] as String? ?? '[]';
      final clean = text.trim()
          .replaceAll('```json', '').replaceAll('```', '').trim();
      final list = jsonDecode(clean) as List;
      return list.cast<String>();
    } catch (e) {
      debugPrint('[Gemini] Recommendations error: $e');
      return [];
    }
  }
}

class GeminiIntent {
  final String intent;
  final String? genre;
  final String? mood;
  final String? controlAction;
  final double confidence;
  final String explanation;

  const GeminiIntent({
    required this.intent,
    this.genre,
    this.mood,
    this.controlAction,
    required this.confidence,
    required this.explanation,
  });

  factory GeminiIntent.fromJson(Map<String, dynamic> json) {
    return GeminiIntent(
      intent: json['intent'] ?? 'play_random',
      genre: json['genre'],
      mood: json['mood'],
      controlAction: json['control_action'],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      explanation: json['explanation'] ?? '',
    );
  }
}