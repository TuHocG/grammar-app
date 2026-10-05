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

Thư mục dữ liệu chứa `grammar.db` và `dataset/` (ảnh, audio); lần đầu app hỏi nếu không có `--dart-define`. Dữ liệu người dùng ở `user.db` trong thư mục hỗ trợ của ứng dụng.
