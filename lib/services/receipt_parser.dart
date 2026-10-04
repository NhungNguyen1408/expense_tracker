class ReceiptData {
  final String merchant;
  final String date;
  final double? total;

  const ReceiptData({
    required this.merchant,
    required this.date,
    required this.total,
  });
}

class ReceiptParser {
  // ============================================================
  // MAIN PARSER
  // ============================================================

  static ReceiptData parse(String rawText) {
    final lines = rawText
        .replaceAll('\r', '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return ReceiptData(
      merchant: parseMerchant(lines),
      date: parseDate(lines),
      total: parseTotal(lines),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  static String parseDate(List<String> lines) {
    final dateRegex = RegExp(
      r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b',
    );

    final isoRegex = RegExp(
      r'\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})\b',
    );

    for (final line in lines) {
      // dd/mm/yyyy hoặc dd-mm-yyyy
      final match = dateRegex.firstMatch(line);

      if (match != null) {
        final day = match.group(1)!.padLeft(2, '0');
        final month = match.group(2)!.padLeft(2, '0');

        var year = match.group(3)!;

        if (year.length == 2) {
          year = '20$year';
        }

        return '$year-$month-$day';
      }

      // yyyy/mm/dd hoặc yyyy-mm-dd
      final isoMatch = isoRegex.firstMatch(line);

      if (isoMatch != null) {
        final year = isoMatch.group(1)!;
        final month = isoMatch.group(2)!.padLeft(2, '0');
        final day = isoMatch.group(3)!.padLeft(2, '0');

        return '$year-$month-$day';
      }
    }

    return '';
  }

  // ============================================================
  // TOTAL
  // ============================================================

  static double? parseTotal(List<String> lines) {
    // Sắp xếp keyword dài trước để nhận diện chính xác hơn.
    const keywords = [
      'GRAND TOTAL',
      'TOTAL DUE',
      'AMOUNT DUE',
      'TOTAL AMOUNT',
      'THÀNH TIỀN',
      'TỔNG TIỀN',
      'TOTAL',
      'AMOUNT',
      'TỔNG',
      'THANH TIEN',
      'TONG TIEN',
      'TONG',
    ];

    // ------------------------------------------------------------
    // BƯỚC 1:
    // Ưu tiên dòng có TOTAL / TỔNG / AMOUNT.
    // Duyệt từ cuối hóa đơn lên vì tổng tiền thường nằm cuối.
    // ------------------------------------------------------------

    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final upper = _normalizeText(line);

      final hasKeyword = keywords.any(
        (keyword) => upper.contains(_normalizeText(keyword)),
      );

      if (!hasKeyword) {
        continue;
      }

      // Ví dụ:
      // TOTAL 125,000
      // TỔNG TIỀN: 125.000
      // GRAND TOTAL 1,250,000
      final values = extractMoney(line);

      if (values.isNotEmpty) {
        // Nếu một dòng có nhiều số, lấy số cuối cùng.
        return values.last;
      }

      // ----------------------------------------------------------
      // Một số hóa đơn OCR tách TOTAL và số tiền thành 2 dòng:
      //
      // TOTAL
      // 125,000
      // ----------------------------------------------------------

      if (i + 1 < lines.length) {
        final nextValues = extractMoney(lines[i + 1]);

        if (nextValues.isNotEmpty) {
          return nextValues.last;
        }
      }

      // Có hóa đơn tách thành:
      //
      // TOTAL
      // VND
      // 125,000
      //
      if (i + 2 < lines.length) {
        final nextNextValues = extractMoney(lines[i + 2]);

        if (nextNextValues.isNotEmpty) {
          return nextNextValues.last;
        }
      }
    }

    // ------------------------------------------------------------
    // BƯỚC 2:
    // Nếu không có TOTAL keyword, tìm các số tiền ở phần cuối
    // hóa đơn.
    // ------------------------------------------------------------

    final candidates = <double>[];

    // Chỉ xét 45% cuối hóa đơn.
    final startIndex = (lines.length * 0.55).floor();

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];

      // Bỏ qua dòng có vẻ là ngày.
      if (_containsDate(line)) {
        continue;
      }

      // Bỏ qua dòng có vẻ là số điện thoại.
      if (_containsPhoneNumber(line)) {
        continue;
      }

      candidates.addAll(extractMoney(line));
    }

    if (candidates.isEmpty) {
      return null;
    }

    // Trong phần cuối hóa đơn, tổng thường là số lớn nhất.
    candidates.sort();

    return candidates.last;
  }

  // ============================================================
  // EXTRACT MONEY
  // ============================================================

  static List<double> extractMoney(String line) {
    final result = <double>[];

    if (line.trim().isEmpty) {
      return result;
    }

    // Không lấy ngày tháng làm số tiền.
    final withoutDates = line
        .replaceAll(
          RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b'),
          ' ',
        );

    // OCR đôi khi đọc O / o thành 0 bên trong số.
    final cleanedLine = withoutDates.replaceAllMapped(
      RegExp(r'(?<=\d)[Oo](?=\d)'),
      (_) => '0',
    );

    /*
      Hỗ trợ:

      125000
      125,000
      125.000
      1,250,000
      1.250.000
      25000
    */
    final regex = RegExp(
      r'(?<!\d)(\d{1,3}(?:[.,]\d{3})+|\d{4,})(?!\d)',
    );

    for (final match in regex.allMatches(cleanedLine)) {
      var raw = match.group(1)!;

      // Bỏ khoảng trắng.
      raw = raw.replaceAll(' ', '');

      if (raw.isEmpty) {
        continue;
      }

      /*
        Ví dụ:
        125,000   -> 125000
        125.000   -> 125000
        1,250,000 -> 1250000
        1.250.000 -> 1250000
      */
      final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

      if (digits.isEmpty) {
        continue;
      }

      final value = double.tryParse(digits);

      if (value == null || value <= 0) {
        continue;
      }

      // Không nhận số quá lớn như mã đơn hàng bất thường.
      if (value > 999999999) {
        continue;
      }

      result.add(value);
    }

    return result;
  }

  // ============================================================
  // MERCHANT
  // ============================================================

  static String parseMerchant(List<String> lines) {
    const ignoredWords = [
      'TOTAL',
      'GRAND TOTAL',
      'AMOUNT',
      'AMOUNT DUE',
      'TOTAL DUE',
      'DATE',
      'TIME',
      'TEL',
      'PHONE',
      'HOTLINE',
      'VAT',
      'TAX',
      'CASHIER',
      'RECEIPT',
      'INVOICE',
      'ADDRESS',
      'ĐỊA CHỈ',
      'SỐ ĐT',
      'SĐT',
      'THANK',
      'THANK YOU',
      'CẢM ƠN',
      'WWW.',
      'HTTP',
    ];

    // Thường tên cửa hàng nằm trong 5-8 dòng đầu tiên.
    for (final line in lines.take(8)) {
      final upper = _normalizeText(line);

      // Quá ngắn.
      if (line.length < 2) {
        continue;
      }

      // Các dòng không phù hợp.
      if (ignoredWords.any(
        (word) => upper.contains(_normalizeText(word)),
      )) {
        continue;
      }

      // Chỉ có số.
      if (RegExp(r'^\d+$').hasMatch(line)) {
        continue;
      }

      // Ngày.
      if (_containsDate(line)) {
        continue;
      }

      // Số điện thoại.
      if (_containsPhoneNumber(line)) {
        continue;
      }

      // Nếu dòng chứa toàn số tiền và rất ngắn thì bỏ qua.
      if (extractMoney(line).isNotEmpty && line.length < 12) {
        continue;
      }

      return line;
    }

    return 'Unknown Merchant';
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static String _normalizeText(String text) {
    return text
        .toUpperCase()
        .replaceAll('Đ', 'D')
        .replaceAll('Đ', 'D')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _containsDate(String text) {
    final dateRegex = RegExp(
      r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b',
    );

    final isoRegex = RegExp(
      r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b',
    );

    return dateRegex.hasMatch(text) || isoRegex.hasMatch(text);
  }

  static bool _containsPhoneNumber(String text) {
    /*
      Nhận diện các số điện thoại phổ biến:

      09xxxxxxxx
      03xxxxxxxx
      07xxxxxxxx
      08xxxxxxxx
      05xxxxxxxx

      hoặc số dài 9-11 chữ số.
    */

    final cleaned = text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (cleaned.length < 9 || cleaned.length > 11) {
      return false;
    }

    if (cleaned.startsWith('03') ||
        cleaned.startsWith('05') ||
        cleaned.startsWith('07') ||
        cleaned.startsWith('08') ||
        cleaned.startsWith('09')) {
      return true;
    }

    return false;
  }
}