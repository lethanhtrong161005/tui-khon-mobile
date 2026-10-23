import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text used by the quick record mic (OS recognizer, Vietnamese).
abstract class VoiceInput {
  bool get isListening;

  /// Starts listening. [onResult] receives partial text and, at the end,
  /// the final text with `isFinal = true`; [onDone] fires when the recognizer
  /// stops (silence, timeout, error). Returns false when speech recognition is
  /// unavailable or the microphone permission was denied.
  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
    void Function()? onDone,
    void Function(String error)? onError,
  });

  Future<void> stop();
}

class SpeechToTextVoiceInput implements VoiceInput {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  String? _localeId;
  void Function()? _onDone;
  void Function(String error)? _onError;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    _onDone = onDone;
    _onError = onError;
    if (!_initialized) {
      _initialized = await _speech.initialize(
        onError: (e) => _onError?.call(e.errorMsg),
        onStatus: (status) {
          if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) _onDone?.call();
        },
      );
      if (!_initialized) return false;
      _localeId = await _vietnameseLocale();
    }

    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
    return true;
  }

  /// vi_VN (or vi-VN) when the device has it; otherwise the system default.
  Future<String?> _vietnameseLocale() async {
    final locales = await _speech.locales();
    for (final l in locales) {
      if (l.localeId.toLowerCase().startsWith('vi')) return l.localeId;
    }
    return null;
  }

  @override
  Future<void> stop() => _speech.stop();
}

final voiceInputProvider = Provider<VoiceInput>((ref) => SpeechToTextVoiceInput());
