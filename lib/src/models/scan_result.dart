import 'receipt_item.dart';

/// Represents a parsed receipt with extracted information.
class ParsedReceipt {
  /// Name of the store or merchant.
  final String? storeName;

  /// Date and time of the transaction.
  final DateTime? dateTime;

  /// List of items on the receipt.
  final List<ReceiptItem> items;

  /// Subtotal amount before tax.
  final double? subtotal;

  /// VAT/Tax amount.
  final double? vat;

  /// Total amount including tax.
  final double? total;

  /// Currency symbol or code.
  final String? currency;

  /// Creates a new [ParsedReceipt] instance.
  const ParsedReceipt({
    this.storeName,
    this.dateTime,
    this.items = const [],
    this.subtotal,
    this.vat,
    this.total,
    this.currency,
  });

  /// Creates a [ParsedReceipt] from a map.
  factory ParsedReceipt.fromMap(Map<dynamic, dynamic> map) {
    return ParsedReceipt(
      storeName: map['storeName'] as String?,
      dateTime: map['dateTime'] != null
          ? DateTime.tryParse(map['dateTime'] as String)
          : null,
      items: (map['items'] as List<dynamic>?)
              ?.map((item) =>
                  ReceiptItem.fromMap(item as Map<dynamic, dynamic>))
              .toList() ??
          const [],
      subtotal: (map['subtotal'] as num?)?.toDouble(),
      vat: (map['vat'] as num?)?.toDouble(),
      total: (map['total'] as num?)?.toDouble(),
      currency: map['currency'] as String?,
    );
  }

  /// Converts this [ParsedReceipt] to a map.
  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName,
      'dateTime': dateTime?.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'vat': vat,
      'total': total,
      'currency': currency,
    };
  }

  @override
  String toString() {
    return 'ParsedReceipt(storeName: $storeName, dateTime: $dateTime, '
        'items: ${items.length} items, total: $total $currency)';
  }
}

/// Result of a document or receipt scan operation.
class ScanResult {
  /// Whether the scan was successful.
  final bool success;

  /// Error message if the scan failed.
  final String? errorMessage;

  /// List of paths to scanned image files.
  final List<String> imagePaths;

  /// Path to PDF file if PDF output was requested.
  final String? pdfPath;

  /// Raw OCR text extracted from the document.
  final String? ocrText;

  /// Parsed receipt data if receipt parsing was performed.
  final ParsedReceipt? parsedReceipt;

  /// Number of pages scanned.
  final int pageCount;

  /// Creates a new [ScanResult] instance.
  const ScanResult({
    this.success = true,
    this.errorMessage,
    this.imagePaths = const [],
    this.pdfPath,
    this.ocrText,
    this.parsedReceipt,
    this.pageCount = 0,
  });

  /// Creates a [ScanResult] from a map.
  factory ScanResult.fromMap(Map<dynamic, dynamic> map) {
    return ScanResult(
      success: map['success'] as bool? ?? false,
      errorMessage: map['errorMessage'] as String?,
      imagePaths: (map['imagePaths'] as List<dynamic>?)
              ?.map((path) => path as String)
              .toList() ??
          const [],
      pdfPath: map['pdfPath'] as String?,
      ocrText: map['ocrText'] as String?,
      parsedReceipt: map['parsedReceipt'] != null
          ? ParsedReceipt.fromMap(map['parsedReceipt'] as Map<dynamic, dynamic>)
          : null,
      pageCount: map['pageCount'] as int? ?? 0,
    );
  }

  /// Converts this [ScanResult] to a map.
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'errorMessage': errorMessage,
      'imagePaths': imagePaths,
      'pdfPath': pdfPath,
      'ocrText': ocrText,
      'parsedReceipt': parsedReceipt?.toMap(),
      'pageCount': pageCount,
    };
  }

  /// Creates a copy of this [ScanResult] with the given fields replaced.
  ScanResult copyWith({
    bool? success,
    String? errorMessage,
    List<String>? imagePaths,
    String? pdfPath,
    String? ocrText,
    ParsedReceipt? parsedReceipt,
    int? pageCount,
  }) {
    return ScanResult(
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
      imagePaths: imagePaths ?? this.imagePaths,
      pdfPath: pdfPath ?? this.pdfPath,
      ocrText: ocrText ?? this.ocrText,
      parsedReceipt: parsedReceipt ?? this.parsedReceipt,
      pageCount: pageCount ?? this.pageCount,
    );
  }

  @override
  String toString() {
    return 'ScanResult(success: $success, pageCount: $pageCount, '
        'hasOcr: ${ocrText != null}, hasParsedReceipt: ${parsedReceipt != null})';
  }
}
