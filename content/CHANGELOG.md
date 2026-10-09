# Lịch sử nội dung

Phiên bản nội dung `MAJOR.MINOR.PATCH` nằm trong `content/content.json`, được ghi vào `grammar.db` (bảng `meta`, khoá `content_version`) và hiện trong Cài Đặt của app.

- **PATCH**: sửa chính tả, bản dịch, đáp án, lời giảng; không thêm bớt mục nào.
- **MINOR**: thêm bài, câu, bài tập, mục từ điển; ID cũ giữ nguyên, ID mới cấp tiếp.
- **MAJOR**: thay đổi phá vỡ tương thích. Nếu lược đồ DB đổi thì tăng cả `schema`, và app phải được cập nhật cùng lúc (app từ chối DB có `schema` lớn hơn bản nó hỗ trợ).

Trước khi tăng phiên bản: `python3 tool/content/check.py` phải qua (không mất ID cũ).

## 1.0.0 — 2026-10-07

- Bản đầu tiên, chuyển nguyên vẹn từ Grammar 3.1 bằng ETL của repo `grammar-legacy` (giải mã 100 %, đối chiếu mã nguồn VB6).
- 544.266 mục từ điển, 4.565 bài đọc, 2.641 bài luyện nói, 356 bài văn phạm, 49.557 bài tập, 3.901 từ gốc Word Forms, 1.142 câu luyện nghe, 12 bài phân tích câu, 155 chủ đề từ vựng tranh, 210 tập phụ đề, 30 bài hướng dẫn, 3.315 ảnh. Audio (119 bài) và video (210 tập) phân phối riêng.
- `grammar.db` chứa luôn 155 trang Từ Vựng Tranh (bảng `media`) vì tiêu điểm vẽ trên các trang này; ảnh minh hoạ và ghi âm vẫn là file, được `tool/content/bundle.py` đặt trong `img/` và `audio/` cạnh `grammar.db`.
- Audio phát hành toàn bộ dạng MP3: 8 file WAV gốc (bài 2–5 MS ADPCM, 6–9 PCM 8 bit) được chuyển sang MP3 CBR bằng `tools/audio/transcode.py` của repo `grammar-legacy`, vì Windows và Android không phát được MS ADPCM; `reading.audio` của bài 2–9 là `audio/<n>.mp3`. Mốc câu (`times`) của bài 2–5 nhân với 11179 / 11155,73 = 1,0020858: header của bốn file ADPCM gốc ghi tốc độ dữ liệu 11179 B/s trong khi thực tế là 11155,73 B/s (block 512 byte = 1012 mẫu ở 22 050 Hz), Windows Media Player tính vị trí theo header nên mốc gốc chậm dần so với thời gian thật (lệch ≈ 0,8 s ở cuối bài 2). Bài 6–9 (PCM) giữ nguyên mốc.
- Phụ đề video: câu đầu của 68 tập có mốc bắt đầu `s` (trước đây 0, tức tính cả đoạn mở đầu, vì app gốc chỉ lưu mốc kết thúc). Mốc tìm bằng script `tools/video/first_line_start.py` của repo grammar-legacy: 55 tập nhận dạng giọng nói (faster-whisper) tìm đúng các từ của câu 1, lùi 0,5 s; 3 tập theo Silero VAD và 7 tập ước lượng theo số từ khi lời bị nhạc lấn hoặc không được đọc; 3 tập (A 47, B 24, B 46) chỉnh tay sau khi nghe kiểm tra. Câu không có chữ ("...") và đoạn mở đầu dưới 3 s giữ `s = 0`. Các câu khác không đổi (câu i vẫn bắt đầu ở mốc kết thúc câu i−1).
