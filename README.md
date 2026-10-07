# Grammar 4.0

Ứng dụng học tiếng Anh cross-platform (Flutter), kế thừa và tiếp tục phát triển **Grammar 3.1** của TuHocTiengAnh.net theo uỷ thác của tác giả. Giữ toàn bộ chức năng học của bản gốc (từ điển 544 nghìn mục, 4.565 bài đọc song ngữ, 356 bài văn phạm, 49 nghìn bài tập, luyện nói, luyện nghe, video phụ đề, phân tích câu, từ vựng tranh…) với giao diện mới.

*English: a Flutter successor of the Vietnamese English-learning app Grammar 3.1, continued with the original author's blessing. Content data is distributed separately.*

Repo này chứa **mã nguồn app và nội dung bài học** (`content/`). Audio giọng thật và video tải riêng. Việc giải mã dữ liệu của app cũ, tài liệu tính năng gốc và phân tích mã VB6 nằm ở repo riêng (`grammar-legacy`, xem phần Tài liệu).

## Chạy khi phát triển

1. Cài Flutter stable (3.47+) và Python 3.11+ (có sẵn trên macOS). Desktop cần thêm: Windows → Visual Studio 2022 Build Tools (workload C++) và `nuget.exe` trên PATH; macOS → Xcode Command Line Tools; Linux → clang, cmake, ninja, GTK, libmpv. Android → Android SDK + JDK 17. `flutter doctor` phải sạch cho nền tảng muốn chạy.
2. Dựng cơ sở dữ liệu nội dung từ `content/` (khoảng 30 giây):

   ```sh
   python3 tool/content/pack.py      # content/dataset (JSON) -> content/grammar.db (gitignore)
   ```

3. Tuỳ chọn, tải phần nặng từ Google Drive (link ở mục Releases hoặc hỏi người quản lý repo):

   | Gói | Nội dung | Giải nén vào |
   |---|---|---|
   | `grammar4-audio.zip` (≈ 620 MB) | 119 bài đọc giọng thật (MP3/WAV) | `content/` (tạo ra `content/dataset/audio/`) |
   | Thư mục video (≈ 8,6 GB) | 210 tập MP4 có phụ đề (`A 01.mp4` …) | thư mục bất kỳ, chọn trong trang Video của app |

   Không có audio thì các bài đó đọc bằng giọng máy; không có video thì trang Video báo thiếu file. Thư mục audio và thư mục video có thể đặt ở bất kỳ đâu rồi chọn trong **Cài Đặt → Dữ liệu**.
4. Chạy:

   ```sh
   flutter pub get
   flutter run -d windows   # hoặc -d macos, -d linux, -d <android device>
   flutter analyze && flutter test   # test tra từ và chấm bài dùng content/grammar.db
   ```

   App tìm dữ liệu theo thứ tự: thư mục đã lưu trong Cài Đặt → `--dart-define=GRAMMAR_DATA_DIR=...` → `content/` trong thư mục làm việc → hỏi người dùng. Dữ liệu người dùng (từ đã lưu, tiến độ, bài tự nhập) nằm trong `user.db` ở thư mục hỗ trợ của app; Cài Đặt có xuất/khôi phục JSON.

   **Cài Đặt → Dữ liệu** có ba mục, mỗi mục hiện tóm tắt những gì tìm thấy: *Dữ liệu bài học* (chọn file `grammar.db`; ảnh đọc từ `dataset/img` cạnh file; hiện phiên bản, ngày phát hành, số bài), *Âm thanh thực* (chọn thư mục chứa `1.mp3`, `2.wav`…; mặc định `dataset/audio` cạnh `grammar.db`; hiện số bài có file), *Video* (chọn thư mục chứa `A 01.mp4`…; hiện số tập có file).

## Sửa nội dung bài học

Nguồn nội dung là các file trong `content/dataset/` (JSON có cấu trúc, bài văn phạm là Markdown nhẹ, ảnh WebP), mô tả từng trường ở `docs/09` và tài liệu dữ liệu của repo `grammar-legacy`. Quy trình:

1. Sửa hoặc thêm bài trong `content/dataset/`.
2. `python3 tool/content/check.py` — báo lỗi nếu bản sửa làm mất hay đổi nghĩa một ID cũ (tiến độ của người học trỏ vào các ID này). Khi **thêm** mục mới thì chạy `--update` để ghi ID mới vào `content/ids.json`.
3. Tăng `version` trong `content/content.json` (PATCH sửa lỗi, MINOR thêm bài, MAJOR phá tương thích) và ghi vào `content/CHANGELOG.md`.
4. `python3 tool/content/pack.py`, chạy app kiểm tra; commit cả nội dung và `ids.json`.

Phiên bản nội dung được ghi vào `grammar.db` (bảng `meta`: `content_version`, `content_date`, `schema_version`) và hiện ở Cài Đặt → Dữ liệu. Nếu đổi lược đồ DB thì tăng `schema` trong `content.json` và `ContentDb.supportedSchema` trong app cùng lúc; app từ chối DB có lược đồ mới hơn nó.

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
content/dataset/              nguồn nội dung (JSON, Markdown nhẹ, ảnh); content.json phiên bản; ids.json ID ổn định; CHANGELOG.md
tool/content/pack.py          dựng content/grammar.db từ content/dataset
tool/content/check.py         kiểm tra ID ổn định trước khi phát hành nội dung
tool/encrypt_db.dart          mã hoá grammar.db cho bản phát hành
docs/                         kế hoạch port (07), ma trận truy vết hành vi app gốc (08), lược đồ SQLite (09)
DESIGN.md                     tham chiếu phong cách giao diện
```

## Ghi chú nền tảng

- **Windows**: `flutter_tts` sập trên một số máy nên TTS dùng SAPI qua kênh `grammar/tts` (`windows/runner/sapi_tts.cpp`), đúng engine Grammar 3.1 dùng (tốc độ 1–7 → Rate −10…8). Nếu `flutter build windows` báo `nuget.exe not found`, tải nuget.exe và thêm vào PATH. Nếu CMake đòi ghi vào `C:\Program Files\grammar`, xoá `build/windows` rồi build lại.
- **macOS**: App Sandbox đã tắt trong `macos/Runner/*.entitlements` để đọc thư mục dữ liệu và video do người dùng chọn. TTS dùng giọng hệ thống (System Settings → Accessibility → Spoken Content).
- **Android**: `android/gradle.properties` tắt Kotlin incremental và Gradle daemon vì lỗi cache kẹt trên Windows; bật lại nếu máy bạn không gặp.
- **Video** phát bằng `media_kit` (libmpv); phụ đề đồng bộ theo mốc kết thúc dòng như app gốc.
- **DB mã hoá** (phát hành): `package:sqlite3` build biến thể SQLite3MultipleCiphers (`hooks` trong `pubspec.yaml`). Tạo DB: `dart run tool/encrypt_db.dart content/grammar.db out/grammar.db <khoá>`; build với `--dart-define=GRAMMAR_DB_KEY=<khoá> --obfuscate --split-debug-info=build/symbols`. Bản phát triển dùng DB thường, không cần khoá.
- **Chụp màn hình tự động**: biến môi trường `GRAMMAR_INITIAL_ROUTE=/dict/word/ball` mở thẳng một màn hình.

## Tài liệu

- [docs/07-ke-hoach-port.md](docs/07-ke-hoach-port.md) — kế hoạch, kiến trúc, mốc M1–M6, quyết định và cách bảo vệ nội dung.
- [docs/08-ma-tran-truy-vet.md](docs/08-ma-tran-truy-vet.md) — 105 hành vi của app gốc → thủ tục VB6 → dữ liệu → quyết định port → trạng thái. Cập nhật cột cuối khi làm xong một hành vi.
- [docs/09-luoc-do-sqlite.md](docs/09-luoc-do-sqlite.md) — lược đồ `grammar.db` và các bảng người dùng.
- Repo `grammar-legacy`: bộ công cụ ETL đã chuyển dữ liệu Grammar 3.1 thành `content/dataset` (chỉ dùng cho lần nhập đầu; từ nay sửa nội dung ở repo này), mô tả định dạng gốc, 72 ảnh chụp app gốc, 28 bài hướng dẫn nguyên văn và năm báo cáo phân tích mã VB6. Các tham chiếu `docs/02`, `docs/05`, `docs/06`, `docs/source/*` trong docs/08 trỏ sang repo đó.

## Bản quyền

Mã nguồn: giấy phép sẽ ghi trong `LICENSE`. Nội dung học trong `content/` cùng âm thanh và video thuộc tác giả Grammar 3.1 và các bên liên quan, được phân phối miễn phí cho việc học theo uỷ thác của tác giả; không được bán hay đóng gói lại để thu lợi.
