# Hướng dẫn cho Claude Code trong repo này

- Đây là **Grammar 4.0**, app Flutter kế thừa Grammar 3.1 (VB6) theo uỷ thác của tác giả. Đọc `README.md`, `docs/07` (kế hoạch), `docs/08` (ma trận truy vết) trước khi làm. Khi hoàn thành hoặc đổi một hành vi, cập nhật cột trạng thái của dòng tương ứng trong `docs/08`; những chỗ cố ý khác app gốc ghi ở cuối docs/08.
- Nội dung bài học nằm trong `content/dataset/` (nguồn chính thức, được commit). `content/grammar.db` sinh bằng `python3 tool/content/pack.py`, không commit, không vá tay. Sửa nội dung: sửa JSON → `python3 tool/content/check.py` (không được mất ID cũ; thêm mục thì `--update`) → tăng `version` trong `content/content.json` + ghi `content/CHANGELOG.md` → pack. Lược đồ ở `docs/09`; đổi lược đồ thì tăng `schema` và `ContentDb.supportedSchema` cùng lúc.
- Audio (`content/dataset/audio/`) và video tải riêng từ Google Drive, gitignore.
- Bản phát hành dữ liệu: `python3 tool/content/bundle.py` → `build/content/grammar4-data-<ver>.zip` (grammar.db với ảnh trang tranh nhúng trong bảng `media` + `grammar-images.zip` chứa ảnh minh hoạ, zip không nén, app đọc thẳng). App đọc cả cấu trúc phát hành (`grammar-images.zip`, `audio/` cạnh grammar.db) lẫn cấu trúc repo (`dataset/`).
- Chạy `flutter analyze` và `flutter test` trước khi kết thúc; test dùng `content/grammar.db` (hoặc `GRAMMAR_DATA_DIR`).
- Windows: TTS là kênh SAPI riêng (`windows/runner/sapi_tts.cpp`), không dùng `flutter_tts` ở đó. Video dùng `media_kit`. `package:sqlite3` build SQLite3MultipleCiphers qua `hooks` trong `pubspec.yaml`.
- Chỉ commit khi được yêu cầu. Commit với `-c user.name="Hieu Nguyen" -c user.email="hieu@newlogic.com"`.
