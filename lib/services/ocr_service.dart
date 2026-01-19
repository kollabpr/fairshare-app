import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Receipt data extracted from OCR
class ReceiptData {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  final List<ReceiptLineItem> items;
  final String rawText;

  ReceiptData({
    this.amount,
    this.merchant,
    this.date,
    this.items = const [],
    this.rawText = '',
  });
}

/// Individual line item from a receipt
class ReceiptLineItem {
  final String description;
  final double? price;

  ReceiptLineItem({
    required this.description,
    this.price,
  });
}

/// Client-side OCR service for receipt scanning
/// Uses Google ML Kit (100% on-device, zero API cost)
class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // Regex patterns for extracting data
  static final _amountRegex = RegExp(r'\$?\d+[.,]\d{2}');
  static final _dateRegex = RegExp(
    r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})',
  );
  static final _totalKeywords = [
    'total',
    'amount due',
    'balance due',
    'grand total',
    'subtotal',
    'amount',
    'due',
  ];

  /// Scan a receipt image and extract data
  Future<ReceiptData> scanReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      String? totalAmount;
      String? merchant;
      DateTime? date;
      final items = <ReceiptLineItem>[];
      final allText = StringBuffer();

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          allText.writeln(text);

          // Extract total amount (look for keywords)
          if (totalAmount == null && _isTotalLine(text)) {
            totalAmount = _extractAmount(text);
          }

          // Extract date
          if (date == null) {
            final dateMatch = _dateRegex.firstMatch(text);
            if (dateMatch != null) {
              date = _parseDate(dateMatch);
            }
          }

          // First substantial text block is often merchant name
          if (merchant == null &&
              block == recognizedText.blocks.first &&
              text.length > 2 &&
              !_isNumericOnly(text)) {
            merchant = text;
          }

          // Extract line items (text followed by price)
          final lineItem = _extractLineItem(text);
          if (lineItem != null) {
            items.add(lineItem);
          }
        }
      }

      // If no total found, try to find the largest amount
      if (totalAmount == null) {
        totalAmount = _findLargestAmount(allText.toString());
      }

      return ReceiptData(
        amount: totalAmount != null ? double.tryParse(totalAmount) : null,
        merchant: merchant,
        date: date,
        items: items,
        rawText: allText.toString(),
      );
    } catch (e) {
      debugPrint('OCR Error: $e');
      return ReceiptData(rawText: 'Error scanning receipt: $e');
    }
  }

  /// Check if a line likely contains the total
  bool _isTotalLine(String text) {
    final lower = text.toLowerCase();
    return _totalKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Extract amount from text
  String? _extractAmount(String text) {
    final matches = _amountRegex.allMatches(text).toList();
    if (matches.isEmpty) return null;

    // Return the last match (usually the total is at the end of the line)
    final match = matches.last.group(0);
    return match?.replaceAll('\$', '').replaceAll(',', '');
  }

  /// Find the largest amount in the text (fallback for total)
  String? _findLargestAmount(String text) {
    final matches = _amountRegex.allMatches(text);
    double largest = 0;
    String? largestStr;

    for (final match in matches) {
      final str = match.group(0)?.replaceAll('\$', '').replaceAll(',', '');
      final value = double.tryParse(str ?? '') ?? 0;
      if (value > largest) {
        largest = value;
        largestStr = str;
      }
    }

    return largestStr;
  }

  /// Parse date from regex match
  DateTime? _parseDate(RegExpMatch match) {
    try {
      final month = int.parse(match.group(1)!);
      final day = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);

      // Handle 2-digit years
      if (year < 100) {
        year += year > 50 ? 1900 : 2000;
      }

      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  /// Check if text is only numbers
  bool _isNumericOnly(String text) {
    return RegExp(r'^[\d\s.,\$]+$').hasMatch(text);
  }

  /// Extract a line item (description + price)
  ReceiptLineItem? _extractLineItem(String text) {
    final amountMatch = _amountRegex.firstMatch(text);
    if (amountMatch == null) return null;

    final description = text.substring(0, amountMatch.start).trim();
    if (description.length < 2) return null;

    final priceStr = amountMatch.group(0)?.replaceAll('\$', '').replaceAll(',', '');
    final price = double.tryParse(priceStr ?? '');

    // Skip if it's likely a total line
    if (_isTotalLine(description)) return null;

    return ReceiptLineItem(
      description: description,
      price: price,
    );
  }

  /// Dispose of the text recognizer
  void dispose() {
    _textRecognizer.close();
  }
}
