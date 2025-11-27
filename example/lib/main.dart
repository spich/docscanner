import 'dart:io';
import 'package:flutter/material.dart';
import 'package:docscanner/docscanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Scanner Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ScannerHomePage(),
    );
  }
}

class ScannerHomePage extends StatefulWidget {
  const ScannerHomePage({super.key});

  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  ScanResult? _scanResult;
  bool _isLoading = false;
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    _getPlatformVersion();
  }

  Future<void> _getPlatformVersion() async {
    final version = await Docscanner.platformVersion ?? 'Unknown platform version';
    setState(() {
      _platformVersion = version;
    });
  }

  Future<void> _scanDocument() async {
    setState(() {
      _isLoading = true;
      _scanResult = null;
    });

    try {
      final result = await Docscanner.scanDocument(
        allowMultiplePages: true,
        outputFormat: 'jpeg',
      );
      setState(() {
        _scanResult = result;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanReceipt() async {
    setState(() {
      _isLoading = true;
      _scanResult = null;
    });

    try {
      final result = await Docscanner.scanReceipt(
        language: 'hr',
        parseReceipt: true,
      );
      setState(() {
        _scanResult = result;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Platform version
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Running on: $_platformVersion',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scan buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _scanDocument,
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Scan Document'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _scanReceipt,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Scan Receipt'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Scanning...'),
                  ],
                ),
              ),

            // Results
            if (_scanResult != null) ...[
              // Status card
              Card(
                color: _scanResult!.success ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _scanResult!.success ? Icons.check_circle : Icons.error,
                            color: _scanResult!.success ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _scanResult!.success ? 'Scan Successful' : 'Scan Failed',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      if (_scanResult!.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Error: ${_scanResult!.errorMessage}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      if (_scanResult!.success) ...[
                        const SizedBox(height: 8),
                        Text('Pages scanned: ${_scanResult!.pageCount}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Scanned images
              if (_scanResult!.imagePaths.isNotEmpty) ...[
                Text(
                  'Scanned Images',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _scanResult!.imagePaths.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_scanResult!.imagePaths[index]),
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // OCR text
              if (_scanResult!.ocrText != null && _scanResult!.ocrText!.isNotEmpty) ...[
                Text(
                  'Extracted Text (OCR)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText(
                      _scanResult!.ocrText!,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Parsed receipt
              if (_scanResult!.parsedReceipt != null) ...[
                Text(
                  'Parsed Receipt',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _buildParsedReceiptCard(_scanResult!.parsedReceipt!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParsedReceiptCard(ParsedReceipt receipt) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store name
            if (receipt.storeName != null) ...[
              Text(
                receipt.storeName!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
            ],

            // Date/time
            if (receipt.dateTime != null) ...[
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${receipt.dateTime!.day}.${receipt.dateTime!.month}.${receipt.dateTime!.year} '
                    '${receipt.dateTime!.hour}:${receipt.dateTime!.minute.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Items
            if (receipt.items.isNotEmpty) ...[
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...receipt.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity > 1 ? '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)}x ' : ''}${item.name}',
                      ),
                    ),
                    Text(
                      item.totalPrice.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )),
              const Divider(),
            ],

            // Totals
            if (receipt.subtotal != null)
              _buildTotalRow('Subtotal', receipt.subtotal!, receipt.currency),
            if (receipt.vat != null)
              _buildTotalRow('VAT/PDV', receipt.vat!, receipt.currency),
            if (receipt.total != null)
              _buildTotalRow('TOTAL', receipt.total!, receipt.currency, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, String? currency, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            '${amount.toStringAsFixed(2)} ${currency ?? ''}',
            style: style,
          ),
        ],
      ),
    );
  }
}
