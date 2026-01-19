import 'dart:io';
import 'package:csv/csv.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';
import 'groups_service.dart';
import 'expenses_service.dart';
import 'splitting_service.dart';

/// Result of CSV import operation
class ImportResult {
  final int expensesImported;
  final int newMembersCreated;
  final List<String> errors;
  final List<String> warnings;

  ImportResult({
    required this.expensesImported,
    required this.newMembersCreated,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => !hasErrors && expensesImported > 0;
}

/// Service for importing expenses from Splitwise CSV
class CSVImportService {
  final GroupsService _groupsService;
  final ExpensesService _expensesService;
  final SplittingService _splittingService;

  CSVImportService({
    required GroupsService groupsService,
    required ExpensesService expensesService,
    required SplittingService splittingService,
  })  : _groupsService = groupsService,
        _expensesService = expensesService,
        _splittingService = splittingService;

  /// Import expenses from a Splitwise CSV file
  ///
  /// Splitwise CSV format:
  /// Date,Description,Category,Cost,Currency,Alice,Bob,Charlie
  /// 2024-01-15,"Dinner",Food,60.00,USD,20.00,20.00,20.00
  Future<ImportResult> importSplitwiseCSV({
    required File csvFile,
    required String groupId,
    required String currentUserId,
  }) async {
    final warnings = <String>[];
    int expensesImported = 0;
    int newMembersCreated = 0;

    try {
      // Read and parse CSV
      final csvData = await csvFile.readAsString();
      final rows = const CsvToListConverter().convert(csvData);

      if (rows.isEmpty) {
        return ImportResult(
          expensesImported: 0,
          newMembersCreated: 0,
          errors: ['CSV file is empty'],
        );
      }

      // Parse headers
      final headers = rows[0].map((e) => e.toString().trim()).toList();

      // Find required column indices
      final dateIdx = _findColumnIndex(headers, ['date']);
      final descIdx = _findColumnIndex(headers, ['description', 'desc']);
      final categoryIdx = _findColumnIndex(headers, ['category', 'cat']);
      final costIdx = _findColumnIndex(headers, ['cost', 'amount', 'total']);
      final currencyIdx = _findColumnIndex(headers, ['currency']);

      if (dateIdx == -1 || descIdx == -1 || costIdx == -1) {
        return ImportResult(
          expensesImported: 0,
          newMembersCreated: 0,
          errors: ['Missing required columns (Date, Description, Cost)'],
        );
      }

      // Member names start after the standard columns
      // Typically: Date, Description, Category, Cost, Currency, [Members...]
      final memberStartIdx = _findMemberStartIndex(headers);
      final memberNames = headers.sublist(memberStartIdx);

      if (memberNames.isEmpty) {
        return ImportResult(
          expensesImported: 0,
          newMembersCreated: 0,
          errors: ['No member columns found in CSV'],
        );
      }

      // Match or create members
      final existingMembers = await _groupsService.getMembers(groupId);
      final memberMap = await _matchOrCreateMembers(
        groupId: groupId,
        memberNames: memberNames,
        existingMembers: existingMembers,
        currentUserId: currentUserId,
      );

      newMembersCreated = memberMap.values
          .where((m) => m.isGhostUser)
          .length;

      // Parse expenses
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        try {
          // Skip empty rows
          if (row.length < memberStartIdx) {
            warnings.add('Row $i: Skipped (incomplete data)');
            continue;
          }

          final date = _parseDate(row[dateIdx].toString());
          final description = row[descIdx].toString().trim();
          final cost = _parseAmount(row[costIdx].toString());
          final currency = currencyIdx >= 0 && row.length > currencyIdx
              ? row[currencyIdx].toString().trim()
              : 'USD';
          final category = categoryIdx >= 0 && row.length > categoryIdx
              ? _mapCategory(row[categoryIdx].toString())
              : 'other';

          if (description.isEmpty || cost == null || cost <= 0) {
            warnings.add('Row $i: Skipped (invalid description or amount)');
            continue;
          }

          // Parse member amounts
          final memberAmounts = <String, double>{};
          String? payerId;
          double? maxPaid;

          for (int j = 0; j < memberNames.length; j++) {
            final colIdx = memberStartIdx + j;
            if (colIdx >= row.length) continue;

            final amount = _parseAmount(row[colIdx].toString());
            if (amount != null) {
              final member = memberMap[memberNames[j]];
              if (member != null) {
                memberAmounts[member.id] = amount;

                // The person with the highest positive amount likely paid
                if (maxPaid == null || amount > maxPaid) {
                  maxPaid = amount;
                  payerId = member.id;
                }
              }
            }
          }

          if (payerId == null || memberAmounts.isEmpty) {
            warnings.add('Row $i: Skipped (no valid splits)');
            continue;
          }

          // Create splits from the amounts
          final participants = memberAmounts.keys
              .map((id) => memberMap.values.firstWhere((m) => m.id == id))
              .toList();

          final splits = _splittingService.calculateSplits(
            expenseId: '',
            amount: cost,
            payerId: payerId,
            participants: participants,
            splitType: SplitType.exact,
            exactAmounts: memberAmounts,
          );

          // Create the expense
          final expense = await _expensesService.createExpense(
            groupId: groupId,
            description: description,
            amount: cost,
            payerId: payerId,
            createdBy: currentUserId,
            splits: splits,
            currencyCode: currency,
            date: date,
            category: category,
          );

          if (expense != null) {
            expensesImported++;
          } else {
            warnings.add('Row $i: Failed to create expense');
          }
        } catch (e) {
          warnings.add('Row $i: Error - $e');
        }
      }

      return ImportResult(
        expensesImported: expensesImported,
        newMembersCreated: newMembersCreated,
        warnings: warnings,
      );
    } catch (e) {
      return ImportResult(
        expensesImported: expensesImported,
        newMembersCreated: newMembersCreated,
        errors: ['Failed to parse CSV: $e'],
        warnings: warnings,
      );
    }
  }

  /// Find column index by possible names
  int _findColumnIndex(List<String> headers, List<String> possibleNames) {
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase();
      if (possibleNames.any((name) => header.contains(name))) {
        return i;
      }
    }
    return -1;
  }

  /// Find where member columns start
  int _findMemberStartIndex(List<String> headers) {
    // Standard Splitwise columns before members
    final standardColumns = ['date', 'description', 'category', 'cost', 'currency'];

    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase();
      final isStandard = standardColumns.any((col) => header.contains(col));
      if (!isStandard && i >= 2) {
        return i;
      }
    }

    // Default: assume members start after column 5
    return headers.length > 5 ? 5 : headers.length;
  }

  /// Match CSV member names to existing members or create ghost users
  Future<Map<String, GroupMemberModel>> _matchOrCreateMembers({
    required String groupId,
    required List<String> memberNames,
    required List<GroupMemberModel> existingMembers,
    required String currentUserId,
  }) async {
    final result = <String, GroupMemberModel>{};

    for (final name in memberNames) {
      final normalizedName = name.toLowerCase().trim();

      // Try to find existing member by name (fuzzy match)
      GroupMemberModel? match = existingMembers.firstWhere(
        (m) => m.nickname.toLowerCase() == normalizedName,
        orElse: () => existingMembers.firstWhere(
          (m) => m.nickname.toLowerCase().contains(normalizedName) ||
                 normalizedName.contains(m.nickname.toLowerCase()),
          orElse: () => GroupMemberModel(
            id: '',
            nickname: '',
            joinedAt: DateTime.now(),
          ),
        ),
      );

      if (match.id.isNotEmpty) {
        result[name] = match;
      } else {
        // Create ghost member
        final ghost = await _groupsService.createGhostMember(groupId, name);
        if (ghost != null) {
          result[name] = ghost;
        }
      }
    }

    return result;
  }

  /// Parse date from various formats
  DateTime _parseDate(String dateStr) {
    try {
      // Try ISO format first (YYYY-MM-DD)
      final iso = DateTime.tryParse(dateStr);
      if (iso != null) return iso;

      // Try MM/DD/YYYY or MM-DD-YYYY
      final parts = dateStr.split(RegExp(r'[/\-.]'));
      if (parts.length == 3) {
        int month = int.parse(parts[0]);
        int day = int.parse(parts[1]);
        int year = int.parse(parts[2]);

        if (year < 100) year += 2000;

        return DateTime(year, month, day);
      }
    } catch (_) {}

    return DateTime.now();
  }

  /// Parse amount from string
  double? _parseAmount(String amountStr) {
    try {
      final cleaned = amountStr
          .replaceAll('\$', '')
          .replaceAll(',', '')
          .replaceAll(' ', '')
          .trim();

      if (cleaned.isEmpty) return null;
      return double.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  /// Map Splitwise categories to our categories
  String _mapCategory(String category) {
    final lower = category.toLowerCase();

    if (lower.contains('food') || lower.contains('dining') || lower.contains('restaurant')) {
      return 'food';
    }
    if (lower.contains('groceries')) return 'groceries';
    if (lower.contains('transport') || lower.contains('uber') || lower.contains('lyft')) {
      return 'transportation';
    }
    if (lower.contains('utilities') || lower.contains('electric') || lower.contains('gas')) {
      return 'utilities';
    }
    if (lower.contains('rent') || lower.contains('housing')) return 'rent';
    if (lower.contains('entertainment') || lower.contains('fun')) return 'entertainment';
    if (lower.contains('shopping')) return 'shopping';
    if (lower.contains('travel') || lower.contains('vacation')) return 'travel';
    if (lower.contains('health') || lower.contains('medical')) return 'health';

    return 'other';
  }
}
