# Hướng dẫn cho Claude Code trong repo này

- Đây là **Grammar 4.0**, app Flutter kế thừa Grammar 3.1 (VB6) theo uỷ thác của tác giả. Đọc `README.md`, `docs/07` (kế hoạch), `docs/08` (ma trận truy vết) trước khi làm. Khi hoàn thành hoặc đổi một hành vi, cập nhật cột trạng thái của dòng tương ứng trong `docs/08`; những chỗ cố ý khác app gốc ghi ở cuối docs/08.
- Dữ liệu nội dung (`data/grammar.db`, `data/dataset/`) tải riêng, bị gitignore; không commit, không đưa lên dịch vụ công khai. Lược đồ ở `docs/09`. Muốn sửa dữ liệu thì sửa ETL ở repo `grammar-legacy` rồi sinh lại `grammar.db`, không vá tay DB.
- Chạy `flutter analyze` và `flutter test` trước khi kết thúc; test dùng `data/grammar.db` (hoặc `GRAMMAR_DATA_DIR`).
- Windows: TTS là kênh SAPI riêng (`windows/runner/sapi_tts.cpp`), không dùng `flutter_tts` ở đó. Video dùng `media_kit`. `package:sqlite3` build SQLite3MultipleCiphers qua `hooks` trong `pubspec.yaml`.
- Chỉ commit khi được yêu cầu. Commit với `-c user.name="Hieu Nguyen" -c user.email="hieu@newlogic.com"`.
