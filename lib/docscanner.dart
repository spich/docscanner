/// Flutter plugin for scanning documents, optimized for long POS receipts.
///
/// This plugin provides document scanning capabilities with automatic
/// perspective correction, multi-page support, and optional OCR text extraction.
library docscanner;

import 'dart:async';
import 'package:flutter/services.dart';

export 'src/models/scan_result.dart';
export 'src/models/receipt_item.dart';
export 'src/receipt_parser.dart';

/// Main class for document scanning functionality.
///
/// Provides methods to scan documents and receipts with optional OCR
/// text extraction and parsing.
class Docscanner {
  static const MethodChannel _channel = MethodChannel('docscanner');

  /// Scans a document using the device camera.
  ///
  /// Opens the native document scanner UI and allows the user to capture
  /// one or more pages. Returns a [ScanResult] containing the scanned images.
  ///
  /// Parameters:
  /// - [allowMultiplePages]: Whether to allow scanning multiple pages (default: true)
  /// - [outputFormat]: Output format, either 'jpeg' or 'pdf' (default: 'jpeg')
  ///
  /// Returns a [ScanResult] with the scanned document data.
  ///
  /// Throws a [PlatformException] if scanning fails.
  static Future<ScanResult> scanDocument({
    bool allowMultiplePages = true,
    String outputFormat = 'jpeg',
  }) async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('scanDocument', {
        'allowMultiplePages': allowMultiplePages,
        'outputFormat': outputFormat,
      });

      if (result == null) {
        return ScanResult(
          success: false,
          errorMessage: 'Scanning was cancelled',
        );
      }

      return ScanResult.fromMap(result);
    } on PlatformException catch (e) {
      return ScanResult(
        success: false,
        errorMessage: e.message ?? 'Unknown error occurred',
      );
    }
  }

  /// Scans a receipt and extracts text using OCR.
  ///
  /// Opens the native document scanner UI optimized for receipt scanning,
  /// captures the receipt, and performs OCR to extract text. The extracted
  /// text is then parsed to identify items, prices, and totals.
  ///
  /// Parameters:
  /// - [language]: OCR language code ('hr' for Croatian, 'en' for English)
  /// - [parseReceipt]: Whether to parse the OCR result into structured data
  ///
  /// Returns a [ScanResult] containing images, OCR text, and parsed receipt data.
  ///
  /// Throws a [PlatformException] if scanning or OCR fails.
  static Future<ScanResult> scanReceipt({
    String language = 'hr',
    bool parseReceipt = true,
  }) async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('scanReceipt', {
        'language': language,
        'performOcr': true,
      });

      if (result == null) {
        return ScanResult(
          success: false,
          errorMessage: 'Scanning was cancelled',
        );
      }

      final scanResult = ScanResult.fromMap(result);

      // Parse the receipt if requested and OCR text is available
      if (parseReceipt && scanResult.ocrText != null) {
        final parsedReceipt = ReceiptParser.parse(
          scanResult.ocrText!,
          language: language,
        );
        return scanResult.copyWith(parsedReceipt: parsedReceipt);
      }

      return scanResult;
    } on PlatformException catch (e) {
      return ScanResult(
        success: false,
        errorMessage: e.message ?? 'Unknown error occurred',
      );
    }
  }

  /// Returns the platform version.
  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
