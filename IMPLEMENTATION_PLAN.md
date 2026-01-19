# FairShare - Implementation Plan

## Executive Summary

**FairShare** is a free, superior alternative to Splitwise built on Flutter/Firebase. This document outlines the complete implementation plan, leveraging ~60% of the existing finance_app codebase.

### Core Philosophy
- **Client-Side First**: OCR and calculations happen on device (zero API costs)
- **Frictionless Migration**: One-click CSV import from Splitwise
- **No Paywalls**: All features free forever

---

## Part 1: Codebase Analysis & Reuse Strategy

### Components to REUSE (As-Is)
| Component | Source File | Reuse % |
|-----------|-------------|---------|
| Firebase Auth | `auth_service.dart` | 100% |
| Theme System | `app_theme.dart`, `animations.dart` | 100% |
| Base Service Pattern | All `*_service.dart` | 90% |
| Security Rules Pattern | `firestore.rules` | 80% |
| User Model | `user_model.dart` | 85% |

### Components to ADAPT
| Original | FairShare Equivalent | Changes |
|----------|---------------------|---------|
| `AccountModel` | `GroupModel` | Rename fields, add members list |
| `TransactionModel` | `ExpenseModel` | Add payer_id, splits, receipt_url |
| `AccountsService` | `GroupsService` | Add member management |
| `TransactionsService` | `ExpensesService` | Add split calculation logic |
| `DashboardScreen` | `GroupListScreen` | Show groups instead of accounts |

### NEW Components Required
- `GroupMemberModel` - Junction table for user-group relationship
- `SplitModel` - Individual split amounts per expense
- `SettlementModel` - Payment records between users
- `SplittingService` - Split calculation algorithms
- `CSVImportService` - Splitwise import logic
- `OCRService` - Client-side receipt scanning

---

## Part 2: Database Schema

### Firestore Collections

#### 1. `users` (Existing - Minimal Changes)
```javascript
{
  uid: string,              // Document ID = Firebase Auth UID
  email: string,
  displayName: string,
  photoUrl: string?,
  createdAt: timestamp,
  lastLogin: timestamp,
  defaultCurrency: string,  // NEW: "USD", "EUR", etc.
  phoneNumber: string?,     // NEW: For contact matching
}
```

#### 2. `groups` (NEW - Replaces accounts concept)
```javascript
{
  id: string,               // Auto-generated document ID
  name: string,             // "Trip to Vegas", "Apartment 4B"
  description: string?,
  createdBy: string,        // User ID of creator
  currencyCode: string,     // "USD"
  headerImageUrl: string?,  // Group cover photo
  iconName: string?,        // Material icon name
  colorHex: string?,        // Theme color
  simplifyDebts: boolean,   // Auto-simplify balances
  defaultSplitType: string, // "equal", "equity", "percentage"
  createdAt: timestamp,
  updatedAt: timestamp,
  isArchived: boolean,
  memberCount: int,         // Denormalized for queries
  totalExpenses: double,    // Denormalized for display
}
```

#### 3. `group_members` (NEW - Junction Table)
```javascript
// Path: groups/{groupId}/members/{odcId}
{
  id: string,               // Document ID
  userId: string?,          // Null for ghost users
  email: string?,           // For invites (ghost users)
  nickname: string,         // Display name in group
  role: string,             // "admin", "member"
  salaryWeight: double,     // Default 1.0, for equity splitting
  joinedAt: timestamp,
  invitedBy: string?,       // User ID who invited
  inviteStatus: string,     // "pending", "accepted", "declined"
  balance: double,          // Denormalized: positive = owed, negative = owes
  isActive: boolean,
}
```

#### 4. `expenses` (NEW - Replaces transactions concept)
```javascript
// Path: groups/{groupId}/expenses/{expenseId}
{
  id: string,
  groupId: string,          // Parent group reference
  description: string,      // "Dinner at Luigi's"
  amount: double,           // Total amount
  currencyCode: string,
  payerId: string,          // Who paid (member ID)
  payerUserId: string?,     // Actual user ID if not ghost
  date: timestamp,          // When expense occurred
  category: string,         // "food", "transport", "utilities"
  notes: string?,
  receiptImageUrl: string?, // S3/Firebase Storage path
  proofImageUrl: string?,   // Venmo screenshot
  isSettlement: boolean,    // True = payment between users
  settlementFromId: string?,// If settlement, who paid
  settlementToId: string?,  // If settlement, who received
  splitType: string,        // "equal", "exact", "percentage", "shares", "equity"
  createdBy: string,        // User ID who created
  createdAt: timestamp,
  updatedAt: timestamp,
  isDeleted: boolean,       // Soft delete
}
```

#### 5. `splits` (NEW - Individual portions)
```javascript
// Path: groups/{groupId}/expenses/{expenseId}/splits/{splitId}
{
  id: string,
  expenseId: string,        // Parent expense
  memberId: string,         // Group member ID
  userId: string?,          // Actual user ID if exists
  owedAmount: double,       // How much they owe for this expense
  paidAmount: double,       // How much they contributed upfront
  percentage: double?,      // If percentage split
  shares: int?,             // If shares-based split
  isSettled: boolean,
  settledAt: timestamp?,
}
```

#### 6. `settlements` (NEW - Payment records)
```javascript
// Path: groups/{groupId}/settlements/{settlementId}
{
  id: string,
  groupId: string,
  fromMemberId: string,     // Who paid
  toMemberId: string,       // Who received
  fromUserId: string?,
  toUserId: string?,
  amount: double,
  currencyCode: string,
  date: timestamp,
  notes: string?,
  proofImageUrl: string?,   // Venmo/payment screenshot
  createdBy: string,
  createdAt: timestamp,
  isConfirmed: boolean,     // Recipient confirmed
  confirmedAt: timestamp?,
}
```

#### 7. `invites` (NEW - Group invitations)
```javascript
{
  id: string,               // Invite code
  groupId: string,
  groupName: string,        // Denormalized for display
  createdBy: string,
  email: string?,           // If email invite
  inviteCode: string,       // Shareable code
  expiresAt: timestamp,
  usedBy: string?,          // User ID who used it
  usedAt: timestamp?,
  isActive: boolean,
}
```

### Firestore Indexes
```
// groups
groups: userId + isArchived + name (ASC)
groups: createdBy + createdAt (DESC)

// expenses
expenses: groupId + date (DESC)
expenses: groupId + payerId + date (DESC)
expenses: groupId + isSettlement + date (DESC)

// members
group_members: groupId + userId
group_members: userId + isActive (for finding user's groups)

// settlements
settlements: groupId + date (DESC)
settlements: fromUserId + isConfirmed
settlements: toUserId + isConfirmed
```

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only access their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Groups: Member-based access
    match /groups/{groupId} {
      allow read: if isGroupMember(groupId);
      allow create: if request.auth != null;
      allow update: if isGroupAdmin(groupId);
      allow delete: if isGroupAdmin(groupId);

      // Nested expenses
      match /expenses/{expenseId} {
        allow read: if isGroupMember(groupId);
        allow create: if isGroupMember(groupId);
        allow update: if isGroupMember(groupId) &&
          (resource.data.createdBy == request.auth.uid || isGroupAdmin(groupId));
        allow delete: if isGroupAdmin(groupId);

        // Splits
        match /splits/{splitId} {
          allow read: if isGroupMember(groupId);
          allow write: if isGroupMember(groupId);
        }
      }

      // Members subcollection
      match /members/{memberId} {
        allow read: if isGroupMember(groupId);
        allow create: if isGroupAdmin(groupId) || request.auth != null;
        allow update: if isGroupAdmin(groupId) ||
          resource.data.userId == request.auth.uid;
        allow delete: if isGroupAdmin(groupId);
      }

      // Settlements
      match /settlements/{settlementId} {
        allow read: if isGroupMember(groupId);
        allow create: if isGroupMember(groupId);
        allow update: if isGroupMember(groupId);
      }
    }

    // Invites: Anyone with code can read, only creator can modify
    match /invites/{inviteId} {
      allow read: if true;  // Public for invite links
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }

    // Helper functions
    function isGroupMember(groupId) {
      return request.auth != null &&
        exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));
    }

    function isGroupAdmin(groupId) {
      return request.auth != null &&
        get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

---

## Part 3: Feature Specifications

### Feature A: Splitwise CSV Importer

#### Flow
```
1. User taps "Import from Splitwise"
2. File picker opens → User selects .csv
3. Parser reads CSV headers to identify columns
4. Match member names to existing group members
5. Create "Ghost Users" for unmatched names
6. Import expenses with calculated splits
7. Show summary: X expenses, Y new members
```

#### Splitwise CSV Format
```csv
Date,Description,Category,Cost,Currency,Alice,Bob,Charlie
2024-01-15,"Dinner",Food,60.00,USD,20.00,20.00,20.00
2024-01-16,"Uber",Transport,25.00,USD,0.00,25.00,0.00
```

#### Implementation
```dart
class CSVImportService {
  Future<ImportResult> importSplitwiseCSV(File csvFile, String groupId) async {
    // 1. Parse CSV
    final csvData = await csvFile.readAsString();
    final rows = const CsvToListConverter().convert(csvData);

    // 2. Extract headers (names start after Currency column)
    final headers = rows[0].map((e) => e.toString()).toList();
    final memberNames = headers.sublist(5); // After Date,Desc,Cat,Cost,Currency

    // 3. Match or create members
    final memberMap = await _matchOrCreateMembers(groupId, memberNames);

    // 4. Parse expenses
    final expenses = <ExpenseModel>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final expense = _parseExpenseRow(row, headers, memberMap);
      expenses.add(expense);
    }

    // 5. Batch write to Firestore
    await _batchCreateExpenses(groupId, expenses);

    return ImportResult(
      expensesImported: expenses.length,
      newMembersCreated: memberMap.values.where((m) => m.isGhost).length,
    );
  }

  Future<Map<String, GroupMember>> _matchOrCreateMembers(
    String groupId,
    List<String> names
  ) async {
    final existingMembers = await _groupService.getMembers(groupId);
    final result = <String, GroupMember>{};

    for (final name in names) {
      // Try fuzzy match
      final match = existingMembers.firstWhereOrNull(
        (m) => m.nickname.toLowerCase() == name.toLowerCase()
      );

      if (match != null) {
        result[name] = match;
      } else {
        // Create ghost user
        final ghost = await _groupService.createGhostMember(groupId, name);
        result[name] = ghost;
      }
    }
    return result;
  }
}
```

#### Mobile Share Intent Support
```dart
// AndroidManifest.xml
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="text/csv" />
  <data android:mimeType="application/csv" />
</intent-filter>

// In app
void handleSharedFile(String? path) {
  if (path?.endsWith('.csv') == true) {
    Navigator.push(context, ImportScreen(filePath: path));
  }
}
```

---

### Feature B: Client-Side OCR (Zero API Cost)

#### Library Choice
- **Flutter**: `google_mlkit_text_recognition` (free, on-device)
- **Web Fallback**: Tesseract.js via platform channels

#### Flow
```
1. User taps camera icon on "Add Expense"
2. Camera opens → Take photo or select from gallery
3. ML Kit processes image locally
4. Regex extracts: Total amount, date, merchant name
5. Pre-fill expense form
6. User confirms/edits → Save expense
```

#### Implementation
```dart
class OCRService {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ReceiptData> scanReceipt(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await textRecognizer.processImage(inputImage);

    String? total;
    String? merchant;
    DateTime? date;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text;

        // Extract total (look for "Total", "Amount Due", etc.)
        if (_isTotalLine(text)) {
          total = _extractAmount(text);
        }

        // Extract date
        final dateMatch = _dateRegex.firstMatch(text);
        if (dateMatch != null) {
          date = _parseDate(dateMatch.group(0)!);
        }

        // First line is often merchant
        if (merchant == null && block == recognizedText.blocks.first) {
          merchant = text;
        }
      }
    }

    return ReceiptData(
      amount: total != null ? double.tryParse(total) : null,
      merchant: merchant,
      date: date,
    );
  }

  static final _amountRegex = RegExp(r'\$?\d+[.,]\d{2}');
  static final _dateRegex = RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}');

  bool _isTotalLine(String text) {
    final lower = text.toLowerCase();
    return lower.contains('total') ||
           lower.contains('amount due') ||
           lower.contains('balance') ||
           lower.contains('grand total');
  }

  String? _extractAmount(String text) {
    final matches = _amountRegex.allMatches(text);
    if (matches.isEmpty) return null;
    // Return the last/largest amount (usually the total)
    return matches.last.group(0)?.replaceAll('\$', '').replaceAll(',', '');
  }
}
```

---

### Feature C: Equity Splitting ("Fair" Mode)

#### Concept
Instead of 50/50 splits, expenses are divided based on income ratios.

#### Example
- Alice earns $100k (weight: 1.0)
- Bob earns $150k (weight: 1.5)
- Charlie earns $50k (weight: 0.5)
- **Total Weight**: 3.0

For a $90 expense:
- Alice: $90 × (1.0/3.0) = $30
- Bob: $90 × (1.5/3.0) = $45
- Charlie: $90 × (0.5/3.0) = $15

#### Implementation
```dart
class SplittingService {

  List<Split> calculateSplits({
    required double amount,
    required List<GroupMember> participants,
    required SplitType type,
    Map<String, double>? customAmounts,    // For "exact" splits
    Map<String, double>? customPercentages, // For "percentage" splits
    Map<String, int>? customShares,         // For "shares" splits
  }) {
    switch (type) {
      case SplitType.equal:
        return _equalSplit(amount, participants);
      case SplitType.equity:
        return _equitySplit(amount, participants);
      case SplitType.exact:
        return _exactSplit(amount, participants, customAmounts!);
      case SplitType.percentage:
        return _percentageSplit(amount, participants, customPercentages!);
      case SplitType.shares:
        return _sharesSplit(amount, participants, customShares!);
    }
  }

  List<Split> _equalSplit(double amount, List<GroupMember> participants) {
    final perPerson = amount / participants.length;
    return participants.map((p) => Split(
      memberId: p.id,
      owedAmount: _roundToCents(perPerson),
    )).toList();
  }

  List<Split> _equitySplit(double amount, List<GroupMember> participants) {
    final totalWeight = participants.fold(0.0, (sum, p) => sum + p.salaryWeight);

    return participants.map((p) {
      final share = (p.salaryWeight / totalWeight) * amount;
      return Split(
        memberId: p.id,
        owedAmount: _roundToCents(share),
      );
    }).toList();
  }

  List<Split> _percentageSplit(
    double amount,
    List<GroupMember> participants,
    Map<String, double> percentages,
  ) {
    return participants.map((p) {
      final pct = percentages[p.id] ?? 0;
      return Split(
        memberId: p.id,
        owedAmount: _roundToCents(amount * pct / 100),
        percentage: pct,
      );
    }).toList();
  }

  double _roundToCents(double amount) {
    return (amount * 100).round() / 100;
  }
}
```

#### UI Toggle
```dart
// In Group Settings
SwitchListTile(
  title: Text('Split by Income (Equity Mode)'),
  subtitle: Text('Higher earners pay proportionally more'),
  value: group.defaultSplitType == SplitType.equity,
  onChanged: (enabled) {
    groupService.updateGroup(group.copyWith(
      defaultSplitType: enabled ? SplitType.equity : SplitType.equal,
    ));
  },
),

// Configure weights
ListView.builder(
  itemCount: members.length,
  itemBuilder: (ctx, i) => ListTile(
    title: Text(members[i].nickname),
    trailing: SizedBox(
      width: 80,
      child: TextField(
        decoration: InputDecoration(labelText: 'Weight'),
        keyboardType: TextInputType.number,
        controller: TextEditingController(
          text: members[i].salaryWeight.toString()
        ),
        onSubmitted: (val) {
          groupService.updateMemberWeight(members[i].id, double.parse(val));
        },
      ),
    ),
  ),
),
```

---

### Feature D: Guest Mode (No-Login View)

#### Public Share Link
```
https://fairshare.app/g/{groupId}/share?token={shareToken}
```

#### Implementation
```dart
// Generate share link
String generateShareLink(String groupId) {
  final token = _generateSecureToken();
  // Store token in group document
  groupService.setShareToken(groupId, token);
  return 'https://fairshare.app/g/$groupId/share?token=$token';
}

// Public view screen
class PublicGroupView extends StatelessWidget {
  final String groupId;
  final String shareToken;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Group?>(
      future: _verifyAndFetchGroup(groupId, shareToken),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) return LoadingScreen();

        final group = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: Text(group.name)),
          body: Column(
            children: [
              // Show balances with first names only
              BalanceSummaryCard(
                balances: group.getPublicBalances(),
                showFullNames: false,
              ),

              // Recent expenses (no personal details)
              ExpenseList(
                expenses: group.recentExpenses,
                anonymized: true,
              ),

              // CTA to join
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  SignUpScreen(prefilledGroupId: groupId),
                ),
                child: Text('Join Group to Settle Up'),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## Part 4: Execution Roadmap

### Phase 1: Foundation (Week 1)

#### Day 1-2: Project Setup
- [ ] Create new Flutter project: `flutter create fairshare_app`
- [ ] Copy Firebase config from finance_app
- [ ] Set up folder structure (lib/models, services, screens, widgets)
- [ ] Copy and adapt AppTheme, animations
- [ ] Set up pubspec.yaml with dependencies

#### Day 3-4: Authentication
- [ ] Copy AuthService (adapt for FairShare)
- [ ] Copy auth screens (Login, SignUp, ForgotPassword)
- [ ] Copy UserModel
- [ ] Test auth flow end-to-end

#### Day 5-7: Core Models & Services
- [ ] Create GroupModel
- [ ] Create GroupMemberModel
- [ ] Create ExpenseModel
- [ ] Create SplitModel
- [ ] Create SettlementModel
- [ ] Implement GroupsService (CRUD operations)

### Phase 2: Core Features (Week 2)

#### Day 8-10: Group Management
- [ ] GroupListScreen (home screen)
- [ ] CreateGroupScreen
- [ ] GroupDetailScreen
- [ ] GroupSettingsScreen
- [ ] Member management UI
- [ ] Invite system (codes + email)

#### Day 11-12: Expense Management
- [ ] AddExpenseScreen with split type toggle
- [ ] ExpenseListScreen
- [ ] ExpenseDetailScreen
- [ ] SplittingService implementation
- [ ] Balance calculation logic

#### Day 13-14: Settlements
- [ ] SettleUpScreen (who owes whom)
- [ ] RecordPaymentScreen
- [ ] Settlement confirmation flow
- [ ] Debt simplification algorithm

### Phase 3: Power Features (Week 3)

#### Day 15-16: CSV Import
- [ ] CSVImportService
- [ ] Import UI flow
- [ ] Ghost user creation
- [ ] Splitwise format support
- [ ] Share intent handling (Android/iOS)

#### Day 17-18: OCR Receipt Scanning
- [ ] Integrate google_mlkit_text_recognition
- [ ] OCRService implementation
- [ ] Camera/gallery image picker
- [ ] Receipt parsing regex
- [ ] Auto-fill expense form

#### Day 19-20: Guest Mode & Sharing
- [ ] Public share link generation
- [ ] PublicGroupView screen
- [ ] Privacy-safe balance display
- [ ] Join group CTA

#### Day 21: Polish
- [ ] Loading states
- [ ] Error handling
- [ ] Offline support
- [ ] Push notifications (optional)

---

## Part 5: File Structure

```
fairshare_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── firebase_options.dart
│   │
│   ├── config/
│   │   ├── app_theme.dart          # From finance_app
│   │   ├── animations.dart         # From finance_app
│   │   ├── constants.dart
│   │   └── routes.dart
│   │
│   ├── models/
│   │   ├── user_model.dart         # Adapted from finance_app
│   │   ├── group_model.dart        # NEW
│   │   ├── group_member_model.dart # NEW
│   │   ├── expense_model.dart      # NEW (based on transaction_model)
│   │   ├── split_model.dart        # NEW
│   │   ├── settlement_model.dart   # NEW
│   │   └── invite_model.dart       # NEW
│   │
│   ├── services/
│   │   ├── auth_service.dart       # From finance_app
│   │   ├── groups_service.dart     # NEW
│   │   ├── expenses_service.dart   # NEW
│   │   ├── splitting_service.dart  # NEW
│   │   ├── settlements_service.dart# NEW
│   │   ├── csv_import_service.dart # NEW
│   │   ├── ocr_service.dart        # NEW
│   │   └── services.dart           # Provider exports
│   │
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   └── forgot_password_screen.dart
│   │   │
│   │   ├── groups/
│   │   │   ├── group_list_screen.dart      # Home
│   │   │   ├── create_group_screen.dart
│   │   │   ├── group_detail_screen.dart
│   │   │   ├── group_settings_screen.dart
│   │   │   └── members_screen.dart
│   │   │
│   │   ├── expenses/
│   │   │   ├── add_expense_screen.dart
│   │   │   ├── expense_list_screen.dart
│   │   │   └── expense_detail_screen.dart
│   │   │
│   │   ├── settlements/
│   │   │   ├── settle_up_screen.dart
│   │   │   └── record_payment_screen.dart
│   │   │
│   │   ├── import/
│   │   │   └── csv_import_screen.dart
│   │   │
│   │   └── public/
│   │       └── public_group_view.dart
│   │
│   └── widgets/
│       ├── common/
│       │   ├── loading_indicator.dart
│       │   ├── error_view.dart
│       │   └── empty_state.dart
│       │
│       ├── groups/
│       │   ├── group_card.dart
│       │   ├── member_avatar.dart
│       │   └── balance_summary.dart
│       │
│       ├── expenses/
│       │   ├── expense_tile.dart
│       │   ├── split_selector.dart
│       │   └── receipt_scanner.dart
│       │
│       └── settlements/
│           ├── debt_graph.dart
│           └── payment_tile.dart
│
├── functions/                      # Firebase Cloud Functions
│   ├── index.js
│   ├── package.json
│   └── .env
│
├── android/
├── ios/
├── web/
├── pubspec.yaml
├── firebase.json
├── firestore.rules
└── firestore.indexes.json
```

---

## Part 6: Dependencies (pubspec.yaml)

```yaml
name: fairshare_app
description: Free expense splitting app - better than Splitwise
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_storage: ^11.6.0

  # State Management
  provider: ^6.1.1

  # UI
  google_fonts: ^6.1.0
  fl_chart: ^0.66.0
  flutter_spinkit: ^5.2.0
  shimmer: ^3.0.0
  cached_network_image: ^3.3.1
  cupertino_icons: ^1.0.2

  # Image & OCR
  image_picker: ^1.0.7
  google_mlkit_text_recognition: ^0.11.0

  # CSV Parsing
  csv: ^5.1.1

  # File Handling
  file_picker: ^6.1.1
  share_plus: ^7.2.1
  receive_sharing_intent: ^1.6.6

  # Utilities
  intl: ^0.18.1
  uuid: ^4.3.1
  collection: ^1.18.0

  # Storage
  flutter_secure_storage: ^9.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
```

---

## Part 7: API Endpoints (Firebase Functions)

### Required Cloud Functions

```javascript
// functions/index.js

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

/**
 * Create invite code for a group
 */
exports.createGroupInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated');

  const { groupId, expiresInDays = 7 } = data;

  // Verify user is admin
  const memberDoc = await db.collection('groups').doc(groupId)
    .collection('members').doc(context.auth.uid).get();

  if (!memberDoc.exists || memberDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied');
  }

  const inviteCode = generateCode(8);
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000)
  );

  await db.collection('invites').doc(inviteCode).set({
    groupId,
    groupName: (await db.collection('groups').doc(groupId).get()).data().name,
    createdBy: context.auth.uid,
    inviteCode,
    expiresAt,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { inviteCode };
});

/**
 * Join group via invite code
 */
exports.joinGroupWithCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated');

  const { inviteCode } = data;

  const inviteDoc = await db.collection('invites').doc(inviteCode).get();
  if (!inviteDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Invalid invite code');
  }

  const invite = inviteDoc.data();
  if (!invite.isActive || invite.expiresAt.toDate() < new Date()) {
    throw new functions.https.HttpsError('failed-precondition', 'Invite expired');
  }

  // Check if already a member
  const existingMember = await db.collection('groups').doc(invite.groupId)
    .collection('members').doc(context.auth.uid).get();

  if (existingMember.exists) {
    throw new functions.https.HttpsError('already-exists', 'Already a member');
  }

  // Get user info
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const user = userDoc.data();

  // Add as member
  await db.collection('groups').doc(invite.groupId)
    .collection('members').doc(context.auth.uid).set({
      userId: context.auth.uid,
      nickname: user.displayName || user.email.split('@')[0],
      role: 'member',
      salaryWeight: 1.0,
      balance: 0,
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      invitedBy: invite.createdBy,
      isActive: true,
    });

  // Update member count
  await db.collection('groups').doc(invite.groupId).update({
    memberCount: admin.firestore.FieldValue.increment(1),
  });

  // Mark invite as used (optional: or allow multiple uses)
  await inviteDoc.ref.update({
    usedBy: context.auth.uid,
    usedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { groupId: invite.groupId, groupName: invite.groupName };
});

/**
 * Simplify debts within a group
 */
exports.simplifyDebts = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated');

  const { groupId } = data;

  // Get all members and their balances
  const membersSnap = await db.collection('groups').doc(groupId)
    .collection('members').get();

  const balances = {};
  membersSnap.docs.forEach(doc => {
    balances[doc.id] = doc.data().balance;
  });

  // Simplification algorithm
  const settlements = simplifyBalances(balances);

  return { settlements };
});

// Helper: Debt simplification algorithm
function simplifyBalances(balances) {
  const creditors = [];
  const debtors = [];

  Object.entries(balances).forEach(([id, balance]) => {
    if (balance > 0.01) creditors.push({ id, amount: balance });
    else if (balance < -0.01) debtors.push({ id, amount: -balance });
  });

  creditors.sort((a, b) => b.amount - a.amount);
  debtors.sort((a, b) => b.amount - a.amount);

  const settlements = [];
  let i = 0, j = 0;

  while (i < creditors.length && j < debtors.length) {
    const amount = Math.min(creditors[i].amount, debtors[j].amount);

    settlements.push({
      from: debtors[j].id,
      to: creditors[i].id,
      amount: Math.round(amount * 100) / 100,
    });

    creditors[i].amount -= amount;
    debtors[j].amount -= amount;

    if (creditors[i].amount < 0.01) i++;
    if (debtors[j].amount < 0.01) j++;
  }

  return settlements;
}

function generateCode(length) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < length; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}
```

---

## Summary: Ready to Execute?

### What I'll Build
1. **New Flutter Project** - `fairshare_app` with clean architecture
2. **Firebase Backend** - Firestore schema, security rules, Cloud Functions
3. **Auth System** - Reused from finance_app with minimal changes
4. **Core Features** - Groups, Expenses, Splits, Settlements
5. **Power Features** - CSV Import, OCR Scanning, Equity Splitting, Guest Mode

### Key Decisions Made
- **Client-side OCR** with Google ML Kit (zero API cost)
- **Firestore subcollections** for expenses/members (better queries)
- **Ghost users** for non-registered members (import compatibility)
- **Equity splitting** via salary weights (fair mode)
- **Debt simplification** algorithm server-side

### Estimated Reuse
- ~60% code from finance_app (auth, theme, patterns)
- ~40% new code (group logic, splitting, import)

---

**Ready to proceed with Phase 1?** I'll start by creating the Flutter project and setting up the foundation.
