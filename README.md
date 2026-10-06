# Grammar 4.0

Ứng dụng học tiếng Anh cross-platform (Flutter), kế thừa và tiếp tục phát triển **Grammar 3.1** của TuHocTiengAnh.net theo uỷ thác của tác giả. Giữ toàn bộ chức năng học của bản gốc (từ điển 544 nghìn mục, 4.565 bài đọc song ngữ, 356 bài văn phạm, 49 nghìn bài tập, luyện nói, luyện nghe, video phụ đề, phân tích câu, từ vựng tranh…) với giao diện mới.

*English: a Flutter successor of the Vietnamese English-learning app Grammar 3.1, continued with the original author's blessing. Content data is distributed separately.*

Repo này chỉ chứa **mã nguồn app**. Việc giải mã dữ liệu của app cũ, tài liệu tính năng gốc và phân tích mã VB6 nằm ở repo riêng (`grammar-legacy`, xem phần Tài liệu).

## Chạy khi phát triển

1. Cài Flutter stable (3.47+). Desktop cần thêm: Windows → Visual Studio 2022 Build Tools (workload C++) và `nuget.exe` trên PATH; macOS → Xcode Command Line Tools; Linux → clang, cmake, ninja, GTK, libmpv. Android → Android SDK + JDK 17. `flutter doctor` phải sạch cho nền tảng muốn chạy.
2. Tải gói dữ liệu và giải nén thành thư mục `data/` ở gốc repo (gitignore):

   | Gói | Nội dung | Dung lượng |
   |---|---|---|
   | `grammar4-data.zip` | `grammar.db` (SQLite, nội dung + FTS5) và `dataset/img` (ảnh WebP) | ≈ 320 MB |
   | `grammar4-audio.zip` | `dataset/audio` – 119 bài đọc giọng thật (MP3/WAV) | ≈ 620 MB, tuỳ chọn |
   | `grammar4-video.zip` | 210 tập video MP4 có phụ đề (`A 01.mp4` …) | ≈ 8,6 GB, tuỳ chọn; giải nén vào thư mục bất kỳ rồi chọn trong trang Video |

   Link tải: Google Drive (xem mục Releases hoặc hỏi người quản lý repo). Sau khi giải nén: `data/grammar.db`, `data/dataset/img/...`, `data/dataset/audio/...`.
3. Chạy:

   ```sh
   flutter pub get
   flutter run -d windows   # hoặc -d macos, -d linux, -d <android device>
   flutter analyze && flutter test   # test tra từ và chấm bài dùng data/grammar.db nếu có
   ```

   App tìm dữ liệu theo thứ tự: thư mục đã lưu trong Cài Đặt → `--dart-define=GRAMMAR_DATA_DIR=...` → `data/` trong thư mục làm việc → hỏi người dùng. Dữ liệu người dùng (từ đã lưu, tiến độ, bài tự nhập) nằm trong `user.db` ở thư mục hỗ trợ của app; Cài Đặt có xuất/khôi phục JSON.

## Cấu trúc

```
lib/
  main.dart            bootstrap: user.db → thư mục dữ liệu → grammar.db → TTS → ProviderScope
  app/                 providers (Riverpod), router (go_router), theme
  data/                content_db*.dart (grammar.db, chỉ đọc), user_db*.dart, user_readings, models, search_key, backup
  domain/              lookup (tra từ như app gốc), sentence_player (TTS hoặc ghi âm theo mốc câu)
  platform/            tts.dart (Windows: SAPI qua kênh riêng; nền tảng khác: flutter_tts)
  ui/                  home, dictionary, readings, grammar, exercises, dialogs, listening, video, analysis, pictures, vocab, user_readings, settings, help
  ui/widgets/          WordTapText (chạm từ, từ đã lưu đỏ), MarkText (Markdown nhẹ của bài văn phạm), shell
windows/runner/sapi_tts.cpp   TTS SAPI cho Windows
tool/encrypt_db.dart          mã hoá grammar.db cho bản phát hành
docs/                         kế hoạch port (07), ma trận truy vết hành vi app gốc (08), lược đồ SQLite (09)
DESIGN.md                     tham chiếu phong cách giao diện
```

## Ghi chú nền tảng

- **Windows**: `flutter_tts` sập trên một số máy nên TTS dùng SAPI qua kênh `grammar/tts` (`windows/runner/sapi_tts.cpp`), đúng engine Grammar 3.1 dùng (tốc độ 1–7 → Rate −10…8). Nếu `flutter build windows` báo `nuget.exe not found`, tải nuget.exe và thêm vào PATH. Nếu CMake đòi ghi vào `C:\Program Files\grammar`, xoá `build/windows` rồi build lại.
- **macOS**: App Sandbox đã tắt trong `macos/Runner/*.entitlements` để đọc thư mục dữ liệu và video do người dùng chọn. TTS dùng giọng hệ thống (System Settings → Accessibility → Spoken Content).
- **Android**: `android/gradle.properties` tắt Kotlin incremental và Gradle daemon vì lỗi cache kẹt trên Windows; bật lại nếu máy bạn không gặp.
- **Video** phát bằng `media_kit` (libmpv); phụ đề đồng bộ theo mốc kết thúc dòng như app gốc.
- **DB mã hoá** (phát hành): `package:sqlite3` build biến thể SQLite3MultipleCiphers (`hooks` trong `pubspec.yaml`). Tạo DB: `dart run tool/encrypt_db.dart data/grammar.db out/grammar.db <khoá>`; build với `--dart-define=GRAMMAR_DB_KEY=<khoá> --obfuscate --split-debug-info=build/symbols`. Bản phát triển dùng DB thường, không cần khoá.
- **Chụp màn hình tự động**: biến môi trường `GRAMMAR_INITIAL_ROUTE=/dict/word/ball` mở thẳng một màn hình.

## Tài liệu

- [docs/07-ke-hoach-port.md](docs/07-ke-hoach-port.md) — kế hoạch, kiến trúc, mốc M1–M6, quyết định và cách bảo vệ nội dung.
- [docs/08-ma-tran-truy-vet.md](docs/08-ma-tran-truy-vet.md) — 105 hành vi của app gốc → thủ tục VB6 → dữ liệu → quyết định port → trạng thái. Cập nhật cột cuối khi làm xong một hành vi.
- [docs/09-luoc-do-sqlite.md](docs/09-luoc-do-sqlite.md) — lược đồ `grammar.db` và các bảng người dùng.
- Repo `grammar-legacy`: bộ công cụ ETL sinh `grammar.db` từ dữ liệu Grammar 3.1, mô tả định dạng gốc, 72 ảnh chụp app gốc, 28 bài hướng dẫn nguyên văn và năm báo cáo phân tích mã VB6. Các tham chiếu `docs/02`, `docs/05`, `docs/06`, `docs/source/*` trong docs/08 trỏ sang repo đó.

## Bản quyền

Mã nguồn: giấy phép sẽ ghi trong `LICENSE`. Nội dung học (từ điển, bài đọc, bài tập, âm thanh, video) thuộc tác giả Grammar 3.1 và các bên liên quan, được phân phối miễn phí cho việc học; không được bán hay phân phối lại dữ liệu dưới dạng khác.
