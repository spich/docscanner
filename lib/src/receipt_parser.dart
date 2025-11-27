import 'models/scan_result.dart';
import 'models/receipt_item.dart';

/// Parser for extracting structured data from POS receipt OCR text.
///
/// Supports Croatian and English receipt formats.
class ReceiptParser {
  // Croatian patterns
  static final RegExp _croatianTotalPattern = RegExp(
    r'(?:UKUPNO|TOTAL|SVEGA|ZA PLATITI|IZNOS)[:\s]*(\d+[.,]\d{2})',
    caseSensitive: false,
  );

  static final RegExp _croatianVatPattern = RegExp(
    r'(?:PDV|POREZ|VAT)[:\s]*(\d+[.,]\d{2})',
    caseSensitive: false,
  );

  static final RegExp _croatianDatePattern = RegExp(
    r'(\d{1,2})[./](\d{1,2})[./](\d{2,4})\s*(\d{1,2}:\d{2}(?::\d{2})?)?',
  );

  // English patterns
  static final RegExp _englishTotalPattern = RegExp(
    r'(?:TOTAL|GRAND TOTAL|AMOUNT DUE|TO PAY)[:\s]*[\$€£]?(\d+[.,]\d{2})',
    caseSensitive: false,
  );

  static final RegExp _englishVatPattern = RegExp(
    r'(?:VAT|TAX|GST)[:\s]*[\$€£]?(\d+[.,]\d{2})',
    caseSensitive: false,
  );

  static final RegExp _englishDatePattern = RegExp(
    r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\s*(\d{1,2}:\d{2}(?::\d{2})?)?',
  );

  // Item patterns (works for both languages)
  static final RegExp _itemPattern = RegExp(
    r'^(.+?)\s+(\d+[.,]?\d*)\s*(?:x\s*)?(\d+[.,]\d{2})$',
    caseSensitive: false,
  );

  static final RegExp _itemWithQuantityPattern = RegExp(
    r'^(\d+[.,]?\d*)\s*(?:kom|pcs|x)?\s*(.+?)\s+(\d+[.,]\d{2})$',
    caseSensitive: false,
  );

  static final RegExp _simpleItemPattern = RegExp(
    r'^(.+?)\s{2,}(\d+[.,]\d{2})$',
  );

  // Currency patterns
  static final RegExp _currencyPattern = RegExp(
    r'(EUR|HRK|KN|USD|\$|€|£)',
    caseSensitive: false,
  );

  /// Parses OCR text from a receipt into structured data.
  ///
  /// Parameters:
  /// - [ocrText]: The raw OCR text to parse
  /// - [language]: Language code ('hr' for Croatian, 'en' for English)
  ///
  /// Returns a [ParsedReceipt] with extracted information.
  static ParsedReceipt parse(String ocrText, {String language = 'hr'}) {
    final lines = ocrText.split('\n').map((l) => l.trim()).toList();

    final storeName = _extractStoreName(lines);
    final dateTime = _extractDateTime(lines, language);
    final items = _extractItems(lines);
    final total = _extractTotal(ocrText, language);
    final vat = _extractVat(ocrText, language);
    final currency = _extractCurrency(ocrText);

    // Calculate subtotal if we have total and VAT
    double? subtotal;
    if (total != null && vat != null) {
      subtotal = total - vat;
    }

    return ParsedReceipt(
      storeName: storeName,
      dateTime: dateTime,
      items: items,
      subtotal: subtotal,
      vat: vat,
      total: total,
      currency: currency,
    );
  }

  /// Extracts the store name from the receipt.
  ///
  /// Typically the store name is in the first few lines.
  static String? _extractStoreName(List<String> lines) {
    // Skip empty lines and look for the first substantial text
    for (var i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      // Skip lines that look like addresses, dates, or numbers
      if (RegExp(r'^\d+[./\-]').hasMatch(line)) continue;
      if (RegExp(r'^\d{5}').hasMatch(line)) continue; // Postal code
      if (line.toLowerCase().contains('oib')) continue;
      if (line.toLowerCase().contains('mb:')) continue;

      // Return the first meaningful line as store name
      if (line.length > 3) {
        return line;
      }
    }
    return null;
  }

  /// Extracts the date and time from the receipt.
  static DateTime? _extractDateTime(List<String> lines, String language) {
    final pattern =
        language == 'hr' ? _croatianDatePattern : _englishDatePattern;

    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        try {
          var day = int.parse(match.group(1)!);
          var month = int.parse(match.group(2)!);
          var year = int.parse(match.group(3)!);

          // Handle 2-digit year
          if (year < 100) {
            year += 2000;
          }

          // For English format, swap day and month if month > 12
          if (language == 'en' && month > 12 && day <= 12) {
            final temp = day;
            day = month;
            month = temp;
          }

          var hour = 0;
          var minute = 0;

          // Parse time if available
          final timeStr = match.group(4);
          if (timeStr != null) {
            final timeParts = timeStr.split(':');
            hour = int.parse(timeParts[0]);
            minute = int.parse(timeParts[1]);
          }

          return DateTime(year, month, day, hour, minute);
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  /// Extracts items from the receipt.
  static List<ReceiptItem> _extractItems(List<String> lines) {
    final items = <ReceiptItem>[];

    // Keywords that indicate non-item lines
    final skipKeywords = [
      'ukupno',
      'total',
      'svega',
      'pdv',
      'porez',
      'vat',
      'tax',
      'gotovina',
      'cash',
      'kartica',
      'card',
      'povrat',
      'change',
      'datum',
      'date',
      'vrijeme',
      'time',
      'oib',
      'jir',
      'zki',
      'račun',
      'receipt',
      'hvala',
      'thank',
      'doviđenja',
      'goodbye',
    ];

    for (final line in lines) {
      if (line.isEmpty) continue;

      // Skip lines with keywords
      final lowerLine = line.toLowerCase();
      if (skipKeywords.any((keyword) => lowerLine.contains(keyword))) {
        continue;
      }

      // Try different item patterns
      var match = _itemWithQuantityPattern.firstMatch(line);
      if (match != null) {
        final quantity = _parseNumber(match.group(1)!);
        final name = match.group(2)!.trim();
        final price = _parseNumber(match.group(3)!);

        if (name.isNotEmpty && price > 0) {
          items.add(ReceiptItem(
            name: name,
            quantity: quantity,
            totalPrice: price,
            unitPrice: quantity > 0 ? price / quantity : null,
          ));
          continue;
        }
      }

      match = _itemPattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!.trim();
        final quantity = _parseNumber(match.group(2)!);
        final price = _parseNumber(match.group(3)!);

        if (name.isNotEmpty && price > 0) {
          items.add(ReceiptItem(
            name: name,
            quantity: quantity,
            totalPrice: price,
            unitPrice: quantity > 0 ? price / quantity : null,
          ));
          continue;
        }
      }

      match = _simpleItemPattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!.trim();
        final price = _parseNumber(match.group(2)!);

        if (name.isNotEmpty && price > 0 && name.length > 2) {
          items.add(ReceiptItem(
            name: name,
            quantity: 1,
            totalPrice: price,
          ));
        }
      }
    }

    return items;
  }

  /// Extracts the total amount from the receipt.
  static double? _extractTotal(String text, String language) {
    final pattern =
        language == 'hr' ? _croatianTotalPattern : _englishTotalPattern;

    final match = pattern.firstMatch(text);
    if (match != null) {
      return _parseNumber(match.group(1)!);
    }
    return null;
  }

  /// Extracts the VAT amount from the receipt.
  static double? _extractVat(String text, String language) {
    final pattern =
        language == 'hr' ? _croatianVatPattern : _englishVatPattern;

    final match = pattern.firstMatch(text);
    if (match != null) {
      return _parseNumber(match.group(1)!);
    }
    return null;
  }

  /// Extracts the currency from the receipt.
  static String? _extractCurrency(String text) {
    final match = _currencyPattern.firstMatch(text);
    if (match != null) {
      final currency = match.group(1)!.toUpperCase();
      // Normalize currency symbols
      switch (currency) {
        case '\$':
          return 'USD';
        case '€':
          return 'EUR';
        case '£':
          return 'GBP';
        case 'KN':
          return 'HRK';
        default:
          return currency;
      }
    }
    return null;
  }

  /// Parses a number string with either comma or dot as decimal separator.
  static double _parseNumber(String text) {
    // Replace comma with dot for parsing
    final normalized = text.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }
}
