#ifndef RUNNER_SAPI_TTS_H_
#define RUNNER_SAPI_TTS_H_

#include <flutter/flutter_engine.h>

// Registers the "grammar/tts" method channel backed by Microsoft SAPI (ISpVoice),
// the same engine the original VB6 app used. Methods:
//   speak(text) -> true          starts speaking asynchronously
//   stop()                       purges the queue
//   isSpeaking() -> bool
//   setRate(int -10..10)         SAPI rate (old app: speed 1..7 -> -10/-6/-3/0/2/4/8)
//   getVoices() -> [{id, name}]
//   setVoice(id)                 id from getVoices, or "" for the default voice
void RegisterSapiTts(flutter::FlutterEngine* engine);

#endif  // RUNNER_SAPI_TTS_H_
