# Docscanner

A Flutter plugin for scanning documents, optimized for long POS receipts. The plugin allows users to scan documents from top to bottom using the camera, automatically merge images, and optionally perform OCR text extraction.

[![Pub Version](https://img.shields.io/pub/v/docscanner)](https://pub.dev/packages/docscanner)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ✅ Single and multi-page document scanning
- ✅ Automatic image stitching for long receipts
- ✅ Automatic perspective correction and edge detection
- ✅ OCR text extraction (optional)
- ✅ POS receipt parser that extracts:
  - Store name
  - Date and time
  - Items (name, quantity, price)
  - Subtotal
  - VAT/Tax
  - Total amount
- ✅ Support for Croatian and English languages
- ✅ JPEG and PDF output formats (Android)

## Platform Support

| Android | iOS |
|---------|-----|
| ✅ SDK 21+ | ✅ iOS 13.0+ |

## Installation

Add `docscanner` to your `pubspec.yaml`:

```yaml
dependencies:
  docscanner: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### Android Setup

Add camera permission to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

The plugin uses ML Kit Document Scanner API which requires Google Play Services.

### iOS Setup

Add camera usage description to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to scan documents.</string>
```

## Usage

### Import the package

```dart
import 'package:docscanner/docscanner.dart';
```

### Scan a Document

```dart
// Scan a document (one or more pages)
final result = await Docscanner.scanDocument(
  allowMultiplePages: true,
  outputFormat: 'jpeg', // or 'pdf'
);

if (result.success) {
  print('Scanned ${result.pageCount} pages');
  print('Image paths: ${result.imagePaths}');
  
  // If PDF was requested
  if (result.pdfPath != null) {
    print('PDF path: ${result.pdfPath}');
  }
} else {
  print('Error: ${result.errorMessage}');
}
```

### Scan a Receipt with OCR

```dart
// Scan a receipt and extract text
final result = await Docscanner.scanReceipt(
  language: 'hr', // or 'en' for English
  parseReceipt: true,
);

if (result.success) {
  // Raw OCR text
  print('OCR Text: ${result.ocrText}');
  
  // Parsed receipt data
  if (result.parsedReceipt != null) {
    final receipt = result.parsedReceipt!;
    print('Store: ${receipt.storeName}');
    print('Date: ${receipt.dateTime}');
    print('Total: ${receipt.total} ${receipt.currency}');
    
    // Print items
    for (final item in receipt.items) {
      print('${item.name}: ${item.totalPrice}');
    }
  }
}
```

## API Reference

### Docscanner

The main class providing scanning functionality.

#### Methods

| Method | Description |
|--------|-------------|
| `scanDocument()` | Opens document scanner and returns scanned images |
| `scanReceipt()` | Opens scanner with OCR and receipt parsing |
| `platformVersion` | Returns the platform version |

### ScanResult

Result of a scan operation.

| Property | Type | Description |
|----------|------|-------------|
| `success` | `bool` | Whether the scan was successful |
| `errorMessage` | `String?` | Error message if scan failed |
| `imagePaths` | `List<String>` | Paths to scanned images |
| `pdfPath` | `String?` | Path to PDF file (if requested) |
| `ocrText` | `String?` | Raw OCR text (if OCR was performed) |
| `parsedReceipt` | `ParsedReceipt?` | Parsed receipt data |
| `pageCount` | `int` | Number of pages scanned |

### ParsedReceipt

Structured data extracted from a receipt.

| Property | Type | Description |
|----------|------|-------------|
| `storeName` | `String?` | Name of the store |
| `dateTime` | `DateTime?` | Transaction date and time |
| `items` | `List<ReceiptItem>` | List of items |
| `subtotal` | `double?` | Subtotal before tax |
| `vat` | `double?` | VAT/Tax amount |
| `total` | `double?` | Total amount |
| `currency` | `String?` | Currency code |

### ReceiptItem

Single item on a receipt.

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Item name |
| `quantity` | `double` | Quantity purchased |
| `unit` | `String?` | Unit of measurement |
| `unitPrice` | `double?` | Price per unit |
| `totalPrice` | `double` | Total price for item |

## Platform Implementation Details

### Android

The plugin uses:
- **ML Kit Document Scanner API** for document scanning
- **ML Kit Text Recognition** for OCR
- Supports scanning multiple pages
- Automatic perspective correction
- JPEG and PDF output formats

### iOS

The plugin uses:
- **VisionKit** (`VNDocumentCameraViewController`) for document scanning
- **Vision Framework** for OCR
- Supports scanning multiple pages
- Automatic perspective correction

## Example App

See the [example](example/) directory for a complete demo application showing all plugin capabilities.

```dart
import 'package:docscanner/docscanner.dart';

// Simple example
void scanAndPrint() async {
  final result = await Docscanner.scanReceipt();
  
  if (result.success && result.parsedReceipt != null) {
    final receipt = result.parsedReceipt!;
    print('Store: ${receipt.storeName}');
    print('Total: ${receipt.total} ${receipt.currency}');
  }
}
```

## Requirements

- Flutter 3.0.0 or higher
- Android SDK 21 or higher
- iOS 13.0 or higher

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a pull request.
