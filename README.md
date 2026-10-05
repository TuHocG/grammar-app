# app — Grammar (Flutter)

Bản port cross-platform của Grammar 3.1. Kiến trúc và mốc: `docs/07`; từng hành vi phải giữ: `docs/08`.

```
lib/
  main.dart            bootstrap: user.db (thư mục hỗ trợ của app) → thư mục dữ liệu → grammar.db → TTS → ProviderScope
  app/                 providers (Riverpod), router (go_router), theme
  data/                content_db.dart (grammar.db, chỉ đọc), user_db.dart (user.db), models, search_key
  domain/              lookup.dart: tra từ như app gốc (nghĩa nhanh → mục đầy đủ → Xem#x# → dạng gốc → họ từ)
  platform/            tts.dart (flutter_tts, tốc độ 1–7 theo bảng SAPI)
  ui/                  home, dictionary (DictionaryPage, EntryPage, QuickDefSheet, EntryView), vocab, settings, help, setup
  ui/widgets/          WordTapText: văn bản chạm từng từ, từ đã lưu đỏ, họ từ gạch chân
```

Chạy khi phát triển (Windows cần Developer Mode để Flutter tạo symlink plugin):

```sh
cd app
flutter run -d windows --dart-define=GRAMMAR_DATA_DIR=D:/code/personal/grammar/dist
flutter analyze && flutter test
```

Thư mục dữ liệu chứa `grammar.db` và `dataset/` (ảnh, audio); lần đầu app hỏi nếu không có `--dart-define`. Dữ liệu người dùng ở `user.db` trong thư mục hỗ trợ của ứng dụng (`%APPDATA%\dev.hieu\grammar` trên Windows); Cài Đặt có xuất/khôi phục JSON.

Ghi chú nền tảng:

- **Windows TTS** dùng SAPI qua kênh `grammar/tts` trong `windows/runner/sapi_tts.cpp` (plugin `flutter_tts` sập trên Windows); các nền tảng khác dùng `flutter_tts`.
- **Video** phát bằng `media_kit`; thư mục video chọn trong trang Video (`A 01.mp4` … do `tools/video/transcode.py` sinh, hoặc AVI gốc).
- **DB mã hoá** (phát hành): `package:sqlite3` build biến thể SQLite3MultipleCiphers (`hooks` trong `pubspec.yaml`). Tạo DB mã hoá: `dart run tool/encrypt_db.dart ../dist/grammar.db out/grammar.db <khoá>`; build app với `--dart-define=GRAMMAR_DB_KEY=<khoá> --obfuscate --split-debug-info=build/symbols`. Bản phát triển dùng DB thường, không cần khoá.
- **Chụp màn hình tự động**: biến môi trường `GRAMMAR_INITIAL_ROUTE=/dict/word/ball` mở thẳng một màn hình.
- **Android**: `flutter build apk` (SDK ở `D:\sdk\android`, JDK 17).

Test: `flutter test` (tra từ và chấm bài chạy trên `dist/grammar.db` thật nếu có).
