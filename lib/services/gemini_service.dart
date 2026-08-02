import 'package:firebase_ai/firebase_ai.dart';

import '../models/pantun_theme.dart';

/// Mirrors data/remote/GeminiApiService.kt.
///
/// NOTE: the original Kotlin app tried a backend proxy (Retrofit `PantunApiService`) before
/// falling back to the Firebase Vertex AI SDK. That backend (`BASE_URL =
/// https://api.pantunconnect.com/`) was a placeholder that was never actually deployed - every
/// call to it failed, so in practice the app always ended up on the Vertex AI SDK path anyway
/// (after paying for a doomed network round-trip first, which is exactly the bug that was fixed
/// on the Kotlin side too). This Flutter port goes straight to Vertex AI in Firebase, which is
/// the only path that's actually configured/working, and skips reintroducing the dead backend.
class GeminiService {
  // Firebase AI Logic's Gemini Developer API backend - works on the free Spark plan.
  // To use the Vertex AI backend instead (what the Kotlin app uses, requires Blaze plan),
  // swap `googleAI()` for `vertexAI()`.
  //
  // NOTE: gemini-2.0-flash and gemini-2.5-flash have both been retired for new API users
  // (quota "limit: 0" / "no longer available" errors) - gemini-3.5-flash is the current
  // replacement as of July 2026, with the lite variant as an overload fallback: the newest
  // free-tier model regularly returns transient 503 "high demand" errors, so each request
  // retries with backoff and then falls back to the next model before giving up.
  static const _modelNames = ['gemini-3.5-flash', 'gemini-3.5-flash-lite'];

  final Map<String, GenerativeModel> _models = {};

  GenerativeModel _modelFor(String name) =>
      _models.putIfAbsent(name, () => FirebaseAI.googleAI().generativeModel(model: name));

  /// Transient server-side conditions worth retrying/falling back on (overload, quota spikes).
  static bool _isTransient(Object e) {
    final message = e.toString().toLowerCase();
    return message.contains('high demand') ||
        message.contains('overloaded') ||
        message.contains('try again later') ||
        message.contains('unavailable') ||
        message.contains('503') ||
        message.contains('resource_exhausted') ||
        message.contains('quota');
  }

  /// Streams the model's response text as it arrives, chunk by chunk. Retries transient
  /// overload errors (2 attempts per model, short backoff) and falls back through
  /// [_modelNames] before surfacing an error message.
  Stream<String> generateContent(String prompt) async* {
    Object? lastError;
    for (final name in _modelNames) {
      for (var attempt = 0; attempt < 2; attempt++) {
        var yieldedAnything = false;
        try {
          final stream = _modelFor(name).generateContentStream([Content.text(prompt)]);
          await for (final response in stream) {
            final text = response.text;
            if (text != null) {
              yieldedAnything = true;
              yield text;
            }
          }
          return; // success
        } catch (e) {
          lastError = e;
          // If we already streamed partial text, or this isn't a transient overload (e.g. AI
          // Logic not enabled, no internet), don't silently retry - surface it.
          if (yieldedAnything || !_isTransient(e)) {
            yield '\nRalat AI: ${e.toString()}. Sila pastikan Firebase AI Logic telah diaktifkan untuk projek ini dan internet stabil.';
            return;
          }
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }
    yield 'Ralat AI: model AI sedang sibuk sekarang (permintaan terlalu tinggi di pihak Google). Sila cuba semula sebentar lagi. [$lastError]';
  }

  Future<String> _generateFull(String prompt) async {
    final buffer = StringBuffer();
    await for (final chunk in generateContent(prompt)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Stream<String> generatePantunFromKeywords(String keywords) {
    final prompt =
        'Generate a traditional Malay pantun based on these keywords: $keywords. Ensure it follows the 4-line structure with A-B-A-B rhyme scheme.';
    return generateContent(prompt);
  }

  Stream<String> continuePantun(String incompletePantun) {
    final prompt = 'Complete this Malay pantun: $incompletePantun. Maintain the rhyme and rhythm.';
    return generateContent(prompt);
  }

  Stream<String> improvePantun(String pantun) {
    final prompt = 'Improve the rhyme and structure of this Malay pantun while keeping its meaning: $pantun';
    return generateContent(prompt);
  }

  Stream<String> convertToPantun(String sentence) {
    final prompt = 'Convert this sentence into a beautiful 4-line Malay pantun: $sentence';
    return generateContent(prompt);
  }

  Stream<String> explainPantun(String pantun) {
    final prompt = 'Explain the meaning and moral values behind this Malay pantun: $pantun';
    return generateContent(prompt);
  }

  /// "Smart Post Creator" - automatically classifies a pantun's theme using the Gemini API,
  /// per the CSC575 Business Case functional requirement (section 3.1). Uses few-shot examples
  /// pulled directly from the real "Klasifikasi Pantun 6 Tema Baharu" research dataset so Gemini
  /// classifies into the same 6 themes the dataset was labelled with.
  Future<String> classifyTheme(String pantunText) async {
    final raw = await _generateFull(_buildClassificationPrompt(pantunText));
    return _normalizeThemeLabel(raw);
  }

  String _buildClassificationPrompt(String pantunText) {
    return '''
Classify the following Malay pantun into EXACTLY ONE of these 6 themes:
${PantunTheme.all.join(', ')}

Examples (real classified pantun):
"Jebak kambing tidur di kandang, Jebaknya luruh sampai ke tanah; Sedaplah kelih adik di jalan, Ambo nak turut sampai ke rumah." -> Nasihat & Moral
"Apa kena baju kebaya, Tapihlah batik buatlah lena; Apa guna macam saya, Rupa ada pandailah tiada." -> Nasihat & Moral
"Pulau tinggi Terendak Cina, Nampak dari Pulau Sialu; Abang pergi jangan lama, Adik duduk menanggung rindu." -> Cinta & Kasih Sayang
"Burung pucung terbang melintang, Hinggap mari Gunung Daik; Putih kuning sanggul melintang, Itulah tanda hati tak baik." -> Cinta & Kasih Sayang
"Kain berlipat dalam istana, Pakaian puteri raja kayangan; Sepatah nasihat ilmu yang berguna, Secubit budi jadi kenangan." -> Budi & Adab
"Duduk bermain di tepi kolam, Ada juga memasang lukah; Kita bertunang selama enam bulan, Lepas itu bolehlah menikah." -> Budi & Adab
"Dari Makasar pergi Palembang, Lalu di Embun Majahapahit; Sungguh kasar kain jarang, Kalau ditenun jadi baik." -> Agama & Spiritual
"Hilir rakit bawa berenang, Hanyut dari tanah seberang; Bagaimana penyakit mahu hilang, Sakit ditanggung makan tak pantang." -> Agama & Spiritual
"Kampung Seniawan bermuka batu, Tempat Kak Bedah mandi di perigi; Hati kami berdua terlalu rindu, Rasa nak ikut awak pergi." -> Peribahasa & Kiasan
"Tenanglah belayar ke Kuala Kudu, Pukul angin haluan melintang; Kalau dapat kasih setuju, Umpama paku lekat di papan." -> Peribahasa & Kiasan
"Tengah mengatih bertenun jangan, Kalau bertenun secara kembang; Kalau berkasih bersenyum jangan, Kalau bersenyum ketawa dek orang." -> Jenaka
"Sayang-sayang buah kepayang, Dimakan mabuk dibuang sayang; Tuan laksana kayu gerenang, Di sini tempat bergurau sayang." -> Jenaka

Reply with ONLY the theme name from the list above, nothing else - no punctuation, no explanation.

Pantun: "$pantunText"
Theme:
''';
  }

  String _normalizeThemeLabel(String raw) {
    final cleaned = raw.trim();
    for (final theme in PantunTheme.all) {
      if (cleaned.toLowerCase().contains(theme.toLowerCase())) return theme;
    }
    return PantunTheme.all.first;
  }
}
