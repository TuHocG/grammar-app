/// Nội dung "Hướng Dẫn Cách Học" của Grammar 4.0. Hướng dẫn mô tả giao diện nên đi kèm app,
/// không nằm trong grammar.db (30 bài hướng dẫn nguyên văn của Grammar 3.1 nằm ở repo
/// grammar-legacy, docs/06; không còn trong dữ liệu).
///
/// Cú pháp của [AppHelpTopic.body]: dòng trống tách đoạn; dòng bắt đầu bằng `## ` là tiêu đề
/// nhỏ; dòng bắt đầu bằng `- ` là gạch đầu dòng; `**đậm**` dùng được trong dòng.
library;

import 'package:flutter/material.dart';

class AppHelpTopic {
  /// Định danh trong đường dẫn `/help/<slug>`.
  final String slug;
  final String title;
  final IconData icon;

  /// Một dòng tóm tắt, hiện trên thẻ ở trang danh sách.
  final String summary;

  /// Nhóm trên trang danh sách.
  final String section;
  final String body;
  const AppHelpTopic({required this.slug, required this.title, required this.icon, required this.summary, required this.section, required this.body});
}

/// Tên các nhóm, theo thứ tự hiện trên trang danh sách.
const helpSections = ['Bắt đầu', 'Học', 'Bài tập', 'Cá nhân'];

const helpTopics = <AppHelpTopic>[
  // ---- Bắt đầu ------------------------------------------------------------------------
  AppHelpTopic(
    slug: 'bat-dau',
    title: 'Cài dữ liệu',
    icon: Icons.storage_outlined,
    summary: 'Chọn grammar.db, thêm giọng đọc thật và video',
    section: 'Bắt đầu',
    body: r'''
App không kèm sẵn bài học. Bạn cần hai file dữ liệu: **grammar.db** và **grammar.images**. Âm thanh thực (giọng đọc thật) và video là phần thêm, tải riêng.

## Lần mở đầu tiên
- Tải **grammar.db** và **grammar.images** vào cùng một thư mục bất kỳ.
- Ở màn hình **Thư mục dữ liệu**, bấm **Chọn thư mục dữ liệu…** và chọn thư mục đó, hoặc gõ đường dẫn thư mục rồi bấm **Mở**. App tự tìm hai file trong đó: **grammar.db** (bài học) và **grammar.images** (ảnh minh hoạ; không có thì bài đọc không có ảnh). Ảnh Từ Vựng Tranh có sẵn trong grammar.db.
- Android hỏi quyền truy cập tệp ở lần chọn đầu tiên: hãy cho phép để app đọc được thư mục này.

## Đổi hoặc thêm dữ liệu
Vào **Cài Đặt → Dữ liệu** (nút bánh răng trên trang chính). Mỗi mục cho biết app tìm thấy gì:
- **Dữ liệu bài học**: bấm **Chọn thư mục dữ liệu…** để đổi sang thư mục dữ liệu khác, ví dụ khi có phiên bản nội dung mới. App mở lại trang chính với dữ liệu đó.
- **Âm thanh thực (giọng đọc thật)**: mặc định app tìm thư mục **audio/** cạnh grammar.db. Để ở chỗ khác thì bấm **Chọn thư mục…** và chọn thư mục chứa 1.mp3, 2.mp3…
- **Video (Luyện Nghe)**: mặc định app tìm thư mục **video/** cạnh grammar.db. Để ở chỗ khác thì bấm **Chọn thư mục…** và chọn thư mục chứa A 01.mp4…

Thiếu âm thanh thực thì bài đó đọc bằng giọng máy. Thiếu video thì trang Video báo không tìm thấy file; các phần khác vẫn dùng bình thường.
''',
  ),
  AppHelpTopic(
    slug: 'cach-hoc',
    title: 'Cách học hiệu quả',
    icon: Icons.school_outlined,
    summary: 'Học theo thứ tự nào, ôn bao lâu một lần',
    section: 'Bắt đầu',
    body: r'''
Grammar dạy theo bậc thang, từ thấp lên cao, bằng tiếng Việt. Đừng cố học thuộc lý thuyết: kiến thức sẽ vào trí nhớ qua việc làm bài tập và đọc đi đọc lại.

## Thứ tự gợi ý
- **1. Bài Đọc**, từ bài đầu tiên. Chạm từ chưa biết để tra và **Lưu từ**; chạm số câu để nghe và xem dịch. Nên học các bài giọng máy trước vì chỉnh được tốc độ đọc.
- **2. Ôn từ vựng** trong **Từ Vựng Của Bạn** và **Quay Từ**, mỗi ngày ít nhất 2 lần. Quay Từ chỉ hỗ trợ ghi nhớ; cách học từ tốt nhất vẫn là đọc hiểu bài đọc nhiều lần.
- **3. Văn Phạm**, khi đã có khoảng 1.000 từ. Học theo thứ tự, làm bài tập của từng bài, rồi trộn bài tập của các bài đã học để nhớ lâu.
- **4. Tập dịch**: mở lại bài đọc cũ, tự dịch từng câu rồi chạm số câu để so. Đọc và dịch đến khi thuần thục.
- **5. Đọc tiếp** các bài còn lại để tăng vốn từ.
- **6. Video** để nghe và hiểu từ vựng trong thực tế.
- **7. Phân Tích Câu** để nắm vai trò của từng từ trong câu, nhờ đó tự viết câu chính xác.
- **8. Xếp từ** để tập lập câu trước khi nói hoặc viết.
- **9. Luyện nghe**: **Nghe toàn bài** khi nhìn bài, rồi không nhìn bài; sau đó làm **Luyện Nghe**. Tập đọc hiểu nhanh gấp đôi tốc độ máy đọc.
- **10. Nghe viết** để nhớ mặt chữ.
- **11. Các bộ Bài tập** khi đã có khoảng 3.000 từ, để chuẩn bị thi.
- **12. Luyện Nói** để tạo phản xạ đàm thoại.

## Luyện nói
Muốn đàm thoại được cần ba điều: thuộc nhiều câu nói theo lối Mỹ, bật ra câu tiếng Anh mà không dịch từ tiếng Việt, và nghe hiểu người đối diện.
- Chỉ chọn những chủ đề hợp với nhu cầu của bạn.
- Với mỗi bài: tra và lưu từ mới trước, rồi **Xếp từ**, rồi **Đàm thoại**.
- Mức 1–6 là mức tập chậm; từ mức 7 tốc độ gần với đàm thoại thật. Có thể bắt đầu ngay ở mức 7, nhưng sẽ khó với câu dài.
- Tập thật nhuần nhuyễn một bài rồi mới sang bài mới.
''',
  ),
  AppHelpTopic(
    slug: 'thao-tac',
    title: 'Thao tác chung',
    icon: Icons.touch_app_outlined,
    summary: 'Chuột, bàn phím và cảm ứng: dùng được ở mọi trang',
    section: 'Bắt đầu',
    body: r'''
## Ở mọi trang
- Chạm (hoặc nhấp chuột) vào một từ tiếng Anh để xem nghĩa và nghe đọc.
- Từ bạn đã lưu hiện **màu đỏ** trong mọi bài; các dạng khác của nó (kicked của kick, các từ cùng họ) được **gạch chân**.
- Nút mũi tên ở góc trên trái để quay lại; chữ **G** để về trang chính.
- Trang chính có thẻ **Đang học** mở lại mục bạn xem gần nhất (bài đọc, văn phạm, luyện nghe, luyện nói, phân tích câu, từ vựng tranh hoặc video) và thẻ **Bài tập đang luyện** khi còn bài tập làm dở.
- Nút **?** ở góc trên phải mở hướng dẫn của trang đang xem.
- Cỡ chữ và giao diện sáng/tối chỉnh trong **Cài Đặt**.

## Trên máy tính
- Gõ một chữ cái ở bất kỳ đâu (khi không ở trong ô nhập) để mở **Từ điển** với chữ đó.
- **Esc**: đóng bảng đang mở, hoặc quay lại trang trước.
- Ở các trang làm bài (Bài Tập, Luyện Nghe, Xếp từ, Nghe viết, Đàm thoại): **Alt+←** / **Alt+→** (trên Mac là **Option**) chuyển câu trước / câu kế, kể cả khi đang gõ trong ô trả lời. **Tab** / **Shift+Tab** đi qua các ô trống, nút và đáp án; **Enter** / **Space** bấm mục đang chọn.
- **F2**: thêm từ vào Từ Vựng Của Bạn với nghĩa riêng. Từ được điền sẵn: cụm từ đang bôi đen, hoặc từ đang tra, hoặc từ dưới con trỏ chuột.
- Kéo chuột để bôi đen một cụm từ trong bài đọc rồi tra cả cụm.
- Màn hình rộng hiện danh sách bên trái, nội dung bên phải; dòng đường dẫn trên cùng bấm được để về trang cấp trên.

## Trên điện thoại
- Trong bài đọc, nhấn giữ một từ để bắt đầu chọn cụm từ, kéo hai đầu để mở rộng, rồi bấm nút **Tra “…”** hiện ở góc dưới.
- Bảng nghĩa từ trượt lên từ dưới: kéo lên để xem thêm, vuốt xuống để đóng.
- Nút kính lúp ở góc trên các trang mở ô **Tra từ** ngay trên trang đang xem (xem **Từ điển & tra từ**); trang nào có nút **?** cạnh đó thì bấm để mở hướng dẫn của trang.
''',
  ),

  // ---- Học ----------------------------------------------------------------------------
  AppHelpTopic(
    slug: 'bai-doc',
    title: 'Bài Đọc',
    icon: Icons.menu_book_outlined,
    summary: 'Tra từ, nghe và dịch từng câu, tra cụm từ',
    section: 'Học',
    body: r'''
Bài đọc song ngữ chia theo nhóm. Ở trang **Bài Đọc**, gõ vào ô **Tìm bài theo tên** để tìm nhanh, hoặc bấm **Tiếp tục** để mở bài đang đọc dở. Biểu tượng sóng âm cạnh tên bài cho biết bài có giọng đọc thật.

## Trong một bài
- **Chạm một từ**: hiện nghĩa nhanh và máy đọc từ đó. Bấm **Lưu từ** để đưa vào Từ Vựng Của Bạn.
- **Chạm số nhỏ trước câu**: máy đọc câu và hiện câu dịch ngay dưới đoạn. Chạm lần nữa để đóng và dừng đọc.
- **Bản dịch** (công tắc trên máy tính, nút dịch trên điện thoại): hiện bản dịch dưới mọi đoạn.
- **Cỡ chữ**: mỗi lần bấm tăng một cỡ; quá cỡ lớn nhất thì quay về nhỏ nhất.
- **Tra cụm từ**: bôi đen cụm từ (kéo chuột, hoặc nhấn giữ trên điện thoại) rồi bấm nút **Tra “…”** ở góc dưới, hoặc chọn **Tra từ điển** trong menu hiện ra.
- Thanh dưới cùng: **Bài trước** / **Bài kế**. Trên máy tính, các bài cùng nhóm nằm ở cột trái.

## Luyện với bài
Các nút đầu bài: **Nghe toàn bài**, **Xếp từ**, **Đàm thoại**, **Nghe viết**. Xem bài hướng dẫn **Nghe, Xếp từ, Đàm thoại, Nghe viết**.
''',
  ),
  AppHelpTopic(
    slug: 'luyen-bai-doc',
    title: 'Nghe, Xếp từ, Đàm thoại, Nghe viết',
    icon: Icons.headset_mic_outlined,
    summary: 'Bốn chế độ luyện của mỗi bài đọc và bài Luyện Nói',
    section: 'Học',
    body: r'''
## Nghe toàn bài
Máy đọc lần lượt từng câu và tô sáng câu đang đọc.
- Chạm một câu để nghe từ câu đó.
- Các nút dưới cùng: câu trước, nghe lại câu này, phát/dừng, câu kế. Nút cuối chuyển giữa **đọc liên tục** và **chỉ đọc một câu**.
- Nút dịch ở góc trên ẩn/hiện câu dịch của câu đang đọc.
- Bàn phím: **←** nghe lại, **↑** câu trước, **→** hoặc **↓** câu kế, **Space** phát/dừng.

## Xếp từ
Các từ của câu tiếng Anh bị đảo lộn; câu tiếng Việt ở trên làm gợi ý.
- Chạm các từ theo đúng thứ tự, đúng cả chữ hoa, chữ thường ("The" đầu câu khác "the" giữa câu). Chạm sai thì từ đó nháy đỏ và đứng yên.
- **Đáp án** xếp nốt phần còn lại; nút loa đọc cả câu.
- **Câu trước** / **Câu kế** (hoặc **Alt+←** / **Alt+→**). Câu dưới 4 từ được bỏ qua.

## Đàm thoại
Nhìn câu tiếng Việt, nói câu tiếng Anh trước khi máy gợi ý xong.
- **Mức độ khó** 1–10 (nút − / +), được nhớ cho lần sau. Mức 1–5: hiện sẵn từ đầu rồi lần lượt từng từ, máy đọc từng từ. Mức 6: chỉ hiện dần từng từ. Mức 7–10: chỉ chấm nhịp, rồi máy đọc nguyên câu.
- **Xem câu**: hiện cả câu tiếng Anh. Nút loa: nghe câu trả lời.
- **Bỏ câu này**: không hỏi lại câu đó nữa. **Back** / **Next** (hoặc **Alt+←** / **Alt+→**): câu trước / câu kế. Trên điện thoại, các nút giữa thu thành biểu tượng.
- Sau 5 vòng, các câu được hỏi theo thứ tự ngẫu nhiên.

## Nghe viết
Máy đọc một câu, câu tiếng Việt hiện phía trên; gõ lại câu tiếng Anh.
- Không cần gõ dấu câu, không phân biệt chữ hoa, chữ thường.
- Gõ sai thì ô chuyển đỏ và máy đọc lại câu. Đúng hết thì hiện **Đúng rồi!**; nhấn **Enter** để sang câu kế.
- **Nghe lại**, **Gợi ý 1 ký tự**, **Hiện trọn từ**, **Câu trước** / **Câu kế** (hoặc **Alt+←** / **Alt+→**).

## Ở Luyện Nói
Bốn nút này cũng có trong mỗi bài Luyện Nói. Riêng **Đàm thoại** ở đó: máy đọc câu A, bạn đáp câu B. Từ mức 7, câu A không hiện chữ; bấm loa để nghe lại câu hỏi.
''',
  ),
  AppHelpTopic(
    slug: 'phien-am',
    title: 'Phiên Âm Quốc Tế',
    icon: Icons.spellcheck,
    summary: 'Ký hiệu IPA và cách đọc bằng tiếng Việt',
    section: 'Học',
    body: r'''
Bài này giúp bạn tự đọc được phiên âm trong từ điển.
- Chạm một ký hiệu để xem ký hiệu đó **đọc là** gì; chạm lần nữa để đóng.
- Chạm một từ ví dụ: nghe từ đó và xem cách đọc bằng tiếng Việt.
- Bật **Hiện tất cả** để xem cách đọc của mọi từ ví dụ cùng lúc.

Trong từ điển, cách đọc tiếng Việt hiện trong ô tròn màu tím cạnh phiên âm, ví dụ rubber [ˈrʌbə] (ráp bờ).
''',
  ),
  AppHelpTopic(
    slug: 'phan-tich-cau',
    title: 'Phân Tích Câu',
    icon: Icons.manage_search,
    summary: 'Từ loại, chức năng và lý do có mặt của từng từ',
    section: 'Học',
    body: r'''
Các bài của "Những Mẩu Chuyện Tiếng Anh Tập 1" được phân tích từng từ. Mục đích: nắm vững vai trò của mỗi từ trong câu để tự viết câu chính xác.

Bài mở ra giống một bài đọc (chạm số câu để nghe và dịch; **Nghe toàn bài**, **Xếp từ**, **Đàm thoại**, **Nghe viết** đều dùng được), chỉ khác khi chạm từ:
- Chạm một từ hoặc cụm từ: máy đọc, hiện nghĩa nhanh và bảng **Phân tích** gồm **Từ loại**, **Vị trí**, **Chức năng**, **Ý cần viết**, **Phải có từ này vì**.
- **Văn phạm liên quan**: chạm để xem bài văn phạm ngay tại chỗ; nút mũi tên chéo mở trang bài.
- **Lưu từ** và **Tra từ điển** như ở bài đọc.
''',
  ),
  AppHelpTopic(
    slug: 'van-pham',
    title: 'Văn Phạm',
    icon: Icons.account_tree_outlined,
    summary: 'Bài lý thuyết theo chương, bài tập từng bài và bài tập trộn',
    section: 'Học',
    body: r'''
Nên học theo thứ tự. Làm bài tập của từng bài trước, rồi trộn bài tập của các bài đã học để nhớ lâu.

## Đọc bài
- Chạm tên chương để mở danh sách bài; **Giới thiệu chương** là phần mở đầu. Ô **Tìm bài văn phạm** lọc theo tên.
- Trên máy tính, danh sách ở bên trái và bài hiện bên phải; trên điện thoại, chạm bài để mở trang riêng.
- Trong bài, chạm từ tiếng Anh để tra. Số bài được gạch chân mở bài đó ngay trên trang; bấm **Mở trang bài** để mở hẳn.
- Hai nút cuối bài chuyển sang bài trước / bài kế.

## Bài tập
- Bài có nhãn **BT** có bài tập đi kèm: mở bài rồi bấm **Làm Bài Tập**.
- **Bài tập trộn**: bấm **Chọn nhiều bài**, đánh dấu các bài có BT, rồi bấm **Làm bài tập trộn**. Câu hỏi của các bài đó được trộn chung. **Thoát chọn** để trở lại.

## Ngữ Pháp Của Bạn
- Bấm **Lưu bài** ở đầu bài (hoặc trong bảng bài mở nhanh) để lưu bài vào **Ngữ Pháp Của Bạn**; bấm lại (**Đã lưu**) để bỏ. Bài đã lưu có dấu 🔖 trong danh sách.
- Mục **Ngữ Pháp Của Bạn** ở phần Cá nhân trên trang chính chỉ hiện các bài đã lưu, theo chương, với đủ chức năng như trang Văn Phạm: tìm, bài tập, bài tập trộn. Bài trước / bài kế chỉ đi qua các bài đã lưu.
''',
  ),
  AppHelpTopic(
    slug: 'luyen-nghe',
    title: 'Luyện Nghe',
    icon: Icons.headphones_outlined,
    summary: 'Unit 1–20: nghe câu tiếng Anh, chọn câu dịch đúng',
    section: 'Học',
    body: r'''
- Chọn một Unit. Máy đọc câu tiếng Anh: giọng thật nếu có âm thanh thực (nhãn **Giọng thật**), không có thì giọng máy.
- Chọn câu tiếng Việt đúng trong 4 câu. Chọn sai lần đầu thì câu đó không được điểm; vẫn chọn tiếp được đến khi đúng.
- Câu tiếng Anh hiện ra sau khi bạn chọn đúng; lúc đó chạm từ để tra.
- **Nghe lại** (hoặc **Space**) để nghe lần nữa. **Back** / **Next** (hoặc **Alt+←** / **Alt+→**, **Enter** sau khi đã trả lời) để chuyển câu; câu cuối có **Kết thúc** để xem điểm.
- Trên máy tính, bản đồ câu nằm bên phải; chạm số để nhảy tới câu đó.

Dòng đầu trang Luyện Nghe mở **Video có phụ đề song ngữ**.
''',
  ),
  AppHelpTopic(
    slug: 'video',
    title: 'Video',
    icon: Icons.movie_outlined,
    summary: 'Phụ đề Anh–Việt từng câu, lặp câu, tra từ',
    section: 'Học',
    body: r'''
Trước hết đặt các file video vào thư mục **video/** cạnh grammar.db, hoặc chọn thư mục khác trong **Cài Đặt → Dữ liệu** (xem **Cài dữ liệu**). Trang Video chia bốn nhóm: **A**, **B**, **C** (video bài học) và **Phim**.

## Khi xem
- Phụ đề tiếng Anh và tiếng Việt hiện dưới video theo từng câu. Chạm từ trong phụ đề tiếng Anh để tra và lưu.
- Hai nút góc trên phải bật/tắt phụ đề Anh và phụ đề Việt.
- Các nút dưới: câu trước, nghe lại câu, phát/tạm dừng, câu kế.
- **Số câu lặp** (− / +): lặp lại liên tục n câu, bắt đầu từ câu đang xem; 0 là tắt.
- Bàn phím: **←** nghe lại câu, **↑** câu trước, **→** hoặc **↓** câu kế, **Space** phát/tạm dừng.
''',
  ),
  AppHelpTopic(
    slug: 'tu-vung-tranh',
    title: 'Từ Vựng Tranh',
    icon: Icons.image_outlined,
    summary: 'Học từ qua tranh: Xem, Luyện 1, Luyện 2',
    section: 'Học',
    body: r'''
Mỗi trang tranh có các số tròn đánh dấu đồ vật. Chọn chế độ ở góc trên: **Xem**, **Luyện 1**, **Luyện 2**. Phóng to tranh bằng hai ngón tay (điện thoại) hoặc con lăn chuột (máy tính).

## Xem
- Chạm một số: hiện "từ = nghĩa" và máy đọc từ.
- Nút loa đọc lại; nút kính lúp tra từ điển; nút đánh dấu **Chọn tiêu điểm để luyện** (số chuyển đỏ).

## Luyện 1
Một số được tô sáng: gõ từ tiếng Anh rồi bấm **Kiểm tra** (hoặc Enter), sau đó **Tiếp**.

## Luyện 2
Máy đọc một từ: chạm đúng số trên tranh. **Nghe lại**, **Đáp án**, **Tiếp**.

Khi đã đánh dấu tiêu điểm, hai chế độ luyện chỉ hỏi các tiêu điểm đó; chưa đánh dấu thì hỏi tất cả. Thanh dưới cùng: **Tranh trước** / **Tranh kế**.
''',
  ),
  AppHelpTopic(
    slug: 'luyen-noi',
    title: 'Luyện Nói',
    icon: Icons.record_voice_over_outlined,
    summary: 'Đàm thoại A–B theo chủ đề, chọn câu để ôn tập',
    section: 'Học',
    body: r'''
Chọn chủ đề, rồi chọn một bài; mỗi bài gồm vài cặp câu A–B. Xem phương pháp học ở **Cách học hiệu quả**.

Thẻ **Đang học** đầu trang mở lại bài bạn luyện gần nhất.

## Trong một bài
- Chạm một dòng để nghe và xem câu dịch; chạm từ để tra.
- **Bản dịch** / nút dịch: hiện dịch của mọi dòng. **Cỡ chữ** như ở Bài Đọc.
- **Nghe toàn bài**, **Xếp từ**, **Đàm thoại**, **Nghe viết**: như ở Bài Đọc; riêng Đàm thoại thì máy đọc câu A, bạn đáp câu B.
- **Đổi ảnh**: đổi ảnh minh hoạ.

## Chọn câu để ôn tập
- Bấm biểu tượng đánh dấu bên phải một cặp câu để chọn nó. Danh sách bài hiện số cặp đã chọn.
- **Ôn tập**: máy đọc câu A, bạn đáp câu B. Từ 4 cặp đã chọn trở lên thì chỉ ôn các cặp đó (**Ôn tập n cặp đã chọn**); chưa đủ thì **Ôn tập cả chủ đề**.
''',
  ),
  AppHelpTopic(
    slug: 'tu-dien',
    title: 'Từ điển & tra từ',
    icon: Icons.search,
    summary: 'Chạm từ để tra, gõ để tìm, lưu và sửa nghĩa riêng',
    section: 'Học',
    body: r'''
## Tra từ trong bài
Chạm một từ tiếng Anh ở bất kỳ đâu (bài đọc, văn phạm, bài tập, phụ đề…). Máy đọc từ và một bảng hiện ra với phiên âm, cách đọc tiếng Việt, nghĩa nhanh và các dạng liên quan.
- **Lưu từ** / **Đã lưu**: lưu vào Từ Vựng Của Bạn hoặc bỏ lưu. Từ đã lưu hiện màu đỏ trong mọi bài.
- **Mục đầy đủ**: xem toàn bộ mục từ.
- **Thêm với nghĩa riêng (F2)** / **Sửa từ (F2)**: tự ghi nghĩa của bạn. Trong ô nghĩa, dấu _ là xuống dòng.
- **Mở trang từ điển**: mở mục từ thành trang riêng.

## Tra nhanh ở mọi trang
Bấm nút kính lúp ở góc trên bên phải (có ở mọi trang trừ trang Từ điển; trên máy tính, trang chính dùng ô **Tra từ nhanh…** thay cho nút). Một ô tra trượt lên từ dưới, trang đang xem vẫn giữ nguyên.
- Gõ vài chữ cái đầu: danh sách gợi ý hiện từ, phiên âm và nghĩa ngắn.
- Chạm một từ (hoặc **Enter**) để xem bảng nghĩa; đóng bảng nghĩa là quay lại ô tra để tra từ khác.
- **Mở Từ điển**: chuyển sang trang Từ điển đầy đủ với chữ đang gõ.

## Trang Từ điển
- Gõ vào ô **Gõ từ cần tra…**: danh sách cuộn tới đúng chữ bạn gõ. **Enter** mở mục đầu tiên khớp.
- Máy tính: mục từ hiện bên phải danh sách. Điện thoại: chạm từ để mở trang mục từ.
- Trên máy tính, gõ một chữ cái ở bất kỳ màn hình nào cũng mở Từ điển; **F2** ở bất kỳ đâu mở bảng thêm từ.
''',
  ),

  // ---- Bài tập ------------------------------------------------------------------------
  AppHelpTopic(
    slug: 'bai-tap',
    title: 'Bài tập',
    icon: Icons.edit_outlined,
    summary: 'Trắc nghiệm, điền từ, tìm chỗ sai, xếp từ; điểm được lưu',
    section: 'Bài tập',
    body: r'''
Mục **Bài tập** trên trang chính có các bộ đề: ARTICLES, CONDITIONAL, TENSE, PREPOSITION / IDIOMS, PRELIMINARY TEST A và B, TOEFL TEST, B+C VOCABULARY, WORD FORMS. Mỗi bộ chia thành các **Bài Tập** 25 câu. Điểm từng bài được lưu; bài làm dở hiện ở thẻ **Bài tập đang luyện** trên trang chính. Nên làm các bộ đề này khi đã có khoảng 3.000 từ.

## Các dạng câu hỏi
- **Trắc nghiệm a–d**: chạm vòng chữ cái (hoặc chỗ trống trên dòng) để chọn; chạm vào một từ là tra từ đó. Chọn sai lần đầu thì câu không được điểm; vẫn chọn tiếp được đến khi đúng.
- **Điền từ**: gõ vào chỗ trống rồi bấm **Chấm (Enter)**. Sau khi chấm, **Điền đáp án** điền câu đúng vào các ô.
- **Tìm chỗ sai**: chạm phần gạch chân bị sai.
- **Xếp từ** (trong bài tập văn phạm): chạm các từ theo đúng thứ tự; dùng **Đáp án** thì câu không được điểm.

## Sau khi trả lời
- Lời giảng hiện ngay dưới câu. Ở trắc nghiệm, biểu tượng **Vì sao?** cạnh các phương án khác giải thích từng phương án.
- **Xem bài:** mở bài văn phạm liên quan ngay tại chỗ.
- **Dịch**: hiện câu dịch. Chạm từ tiếng Anh để tra.

## Di chuyển
- **Back** / **Next**, hoặc **Alt+←** / **Alt+→**, hoặc **Enter** sau khi đã trả lời. Câu cuối có **Kết thúc** để xem điểm.
- Bản đồ câu (bên phải trên màn hình rộng, dưới câu hỏi trên điện thoại) cho biết câu đúng, sai, chưa làm; chạm số để nhảy tới câu đó.
- Trang kết quả: **Làm lại**, **Xem lại**, **Bài Tập kế**, **Đóng**.
''',
  ),
  AppHelpTopic(
    slug: 'word-forms',
    title: 'Word Forms',
    icon: Icons.text_fields,
    summary: 'Luyện dạng từ: danh, động, tính, trạng từ của một từ gốc',
    section: 'Bài tập',
    body: r'''
Phần luyện nhận biết danh từ, tính từ, động từ, trạng từ… của một từ gốc, dạng bài thường gặp trong các kỳ thi.
- Trang Word Forms liệt kê các từ gốc; dấu sao là từ thông dụng, số bên phải là số câu.
- Chạm một từ gốc: lần 1 đánh dấu **học** (xanh), lần 2 chuyển sang **dự trữ** (đỏ), lần 3 bỏ đánh dấu.
- Nút góc dưới: **Làm bài (n từ)** làm các từ xanh; không có từ xanh thì **Ôn từ dự trữ**; không đánh dấu gì thì **Làm từ thông dụng**.
- **Tìm từ gốc** để lọc; **Xoá đánh dấu** để bỏ hết.
- Mỗi câu: gõ dạng đúng của từ gốc vào chỗ trống rồi **Chấm (Enter)**, như bài điền từ.
''',
  ),

  // ---- Cá nhân ------------------------------------------------------------------------
  AppHelpTopic(
    slug: 'tu-vung-cua-ban',
    title: 'Từ Vựng Của Bạn & Quay Từ',
    icon: Icons.bookmark_outline,
    summary: 'Danh sách từ đã lưu, đánh dấu để ôn bằng thẻ ghi nhớ',
    section: 'Cá nhân',
    body: r'''
## Từ Vựng Của Bạn
Mọi từ bạn bấm **Lưu từ** khi học, kèm câu chứa từ đó, theo thứ tự lưu.
- Chạm một từ để mở trang từ điển; chạm từ trong câu ví dụ để tra.
- Nút loa đọc từ; nút ngôi sao đánh dấu từ để ôn trong **Quay Từ**.
- Nhấn giữ một từ để sửa (từ, phiên âm, nghĩa riêng).
- Vuốt một dòng sang trái để xoá. Menu ⋮ có **Xoá cả danh sách**.
- **Từ mới**: tự thêm từ. **Lọc** để tìm trong danh sách; nút ngôi sao ở góc trên chỉ hiện các từ đã đánh dấu.

## Quay Từ
Các từ đã đánh dấu sao lần lượt hiện như thẻ ghi nhớ: từ hiện trước (máy đọc), nghĩa hiện sau. Chưa đánh dấu từ nào thì ôn tất cả từ đã lưu.
- **Tốc độ** 1–10; từ 8 trở lên máy không đọc.
- Nút tạm dừng/chạy, **Đọc**, **Nghĩa**, **Tiếp**. Chạm thẻ để tra từ.
- **Đã thuộc**: bỏ dấu sao, từ không hiện trong Quay Từ nữa (chỉ có khi đang ôn từ đánh dấu sao).

Nên ôn ít nhất 2 lần mỗi ngày.
''',
  ),
  AppHelpTopic(
    slug: 'bai-nhap',
    title: 'Bài Nhập Của Bạn',
    icon: Icons.edit_note_outlined,
    summary: 'Tự soạn bài đọc song ngữ, dùng đủ tính năng Bài Đọc',
    section: 'Cá nhân',
    body: r'''
Bài bạn tự nhập mở như một bài đọc thường: tra từ, nghe, dịch, Xếp từ, Đàm thoại, Nghe viết.

## Tạo bài
- Bấm **Tạo bài đọc**, chọn **Gói (nhóm)** có sẵn trong danh sách hoặc gõ tên mới để tạo nhóm, rồi điền **Tựa đề**.
- **Tiếng Anh**: mỗi đoạn cách nhau một dòng trống; câu tự tách theo dấu chấm, hoặc dùng dấu _ để tách câu.
- **Tiếng Việt**: câu dịch tương ứng, tách cùng cách. Dòng đếm bên dưới báo khi số câu Anh và Việt chưa khớp.
- **Ảnh đầu bài** (tuỳ chọn): bấm **Chọn ảnh…** để chọn một file ảnh trên máy, hoặc dán đường dẫn.
- Bấm **Lưu**.

Menu ⋮ cạnh mỗi bài có **Sửa bài** và **Xoá bài**. Bài nhập được lưu trong file sao lưu (xem **Cài Đặt & sao lưu**).
''',
  ),
  AppHelpTopic(
    slug: 'cai-dat',
    title: 'Cài Đặt & sao lưu',
    icon: Icons.settings_outlined,
    summary: 'Giọng đọc, cỡ chữ, giao diện, sao lưu và khôi phục',
    section: 'Cá nhân',
    body: r'''
Mở bằng nút bánh răng trên trang chính.

## Giọng đọc
- **Giọng**: chọn giọng tiếng Anh của máy, hoặc **Mặc định của hệ thống**.
- **Tốc độ đọc** 1–7; nút loa để nghe thử. Tốc độ chỉ áp dụng cho giọng máy, không áp dụng cho giọng đọc thật.

## Hiển thị
- **Cỡ chữ** chung của app. Trong Bài Đọc và Luyện Nói còn có nút **Cỡ chữ** để đổi nhanh.
- **Giao diện**: **Hệ thống**, **Sáng** hoặc **Tối**.

## Sao lưu
- **Xuất dữ liệu học tập ra file**: từ đã lưu, đánh dấu, tiến độ, câu đã chọn, bài tự nhập và cài đặt được ghi vào một file JSON. Nên xuất định kỳ, và trước khi cài lại máy hay đổi máy.
- **Khôi phục từ file sao lưu**: chọn file JSON đã xuất; dữ liệu hiện tại sẽ bị thay thế.

## Dữ liệu
Chọn grammar.db, thư mục âm thanh thực và thư mục video. Xem **Cài dữ liệu**.
''',
  ),
];
