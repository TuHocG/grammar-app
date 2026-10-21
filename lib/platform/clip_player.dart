/// Plays stretches of one recording for [SentencePlayer]: open it once, then seek, play, pause.
/// The desktop and mobile apps use audioplayers (`clip_player_io.dart`); the web app drives an
/// `<audio>` element itself (`clip_player_web.dart`), because audioplayers_web routes the element
/// through Web Audio, where Safari on iOS seems to play a moment of the old position after a seek
/// (Luyện Nghe on an iPhone: about a second of another passage before each sentence).
library;

export 'clip_player_io.dart' if (dart.library.js_interop) 'clip_player_web.dart';
