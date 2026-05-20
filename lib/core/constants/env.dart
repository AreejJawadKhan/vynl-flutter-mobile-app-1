import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();
  static String get geminiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get lastfmKey => dotenv.env['LASTFM_API_KEY'] ?? '';
}