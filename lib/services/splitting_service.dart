import '../models/split_model.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';

/// Service for calculating expense splits
/// All calculations happen client-side (zero server cost)
class SplittingService {

  /// Calculate splits based on split type
  List<SplitModel> calculateSplits({
    required String expenseId,
    required double amount,
    required String payerId,
    required List<GroupMemberModel> participants,
    required SplitType splitType,
    Map<String, double>? exactAmounts,      // For exact splits
    Map<String, double>? percentages,       // For percentage splits
    Map<String, int>? shares,               // For shares splits
  }) {
    switch (splitType) {
      case SplitType.equal:
        return _equalSplit(expenseId, amount, payerId, participants);
      case SplitType.equity:
        return _equitySplit(expenseId, amount, payerId, participants);
      case SplitType.exact:
        return _exactSplit(expenseId, amount, payerId, participants, exactAmounts!);
      case SplitType.percentage:
        return _percentageSplit(expenseId, amount, payerId, participants, percentages!);
      case SplitType.shares:
        return _sharesSplit(expenseId, amount, payerId, participants, shares!);
    }
  }

  /// Equal split - divide evenly among all participants
  List<SplitModel> _equalSplit(
    String expenseId,
    double amount,
    String payerId,
    List<GroupMemberModel> participants,
  ) {
    final perPerson = amount / participants.length;

    return participants.map((member) {
      final isPayer = member.id == payerId;
      return SplitModel(
        id: '', // Will be set by Firestore
        expenseId: expenseId,
        memberId: member.id,
        userId: member.userId,
        owedAmount: _roundToCents(perPerson),
        paidAmount: isPayer ? amount : 0.0,
      );
    }).toList();
  }

  /// Equity split - based on salary weights (income-based fairness)
  /// Example: If Alice has weight 1.0 and Bob has weight 1.5,
  /// Bob pays 60% and Alice pays 40%
  List<SplitModel> _equitySplit(
    String expenseId,
    double amount,
    String payerId,
    List<GroupMemberModel> participants,
  ) {
    final totalWeight = participants.fold(
      0.0,
      (sum, member) => sum + member.salaryWeight,
    );

    return participants.map((member) {
      final share = (member.salaryWeight / totalWeight) * amount;
      final isPayer = member.id == payerId;
      return SplitModel(
        id: '',
        expenseId: expenseId,
        memberId: member.id,
        userId: member.userId,
        owedAmount: _roundToCents(share),
        paidAmount: isPayer ? amount : 0.0,
      );
    }).toList();
  }

  /// Exact split - specific amounts for each person
  List<SplitModel> _exactSplit(
    String expenseId,
    double amount,
    String payerId,
    List<GroupMemberModel> participants,
    Map<String, double> exactAmounts,
  ) {
    return participants.map((member) {
      final owed = exactAmounts[member.id] ?? 0.0;
      final isPayer = member.id == payerId;
      return SplitModel(
        id: '',
        expenseId: expenseId,
        memberId: member.id,
        userId: member.userId,
        owedAmount: _roundToCents(owed),
        paidAmount: isPayer ? amount : 0.0,
      );
    }).toList();
  }

  /// Percentage split - each person pays a percentage
  List<SplitModel> _percentageSplit(
    String expenseId,
    double amount,
    String payerId,
    List<GroupMemberModel> participants,
    Map<String, double> percentages,
  ) {
    return participants.map((member) {
      final pct = percentages[member.id] ?? 0.0;
      final owed = amount * pct / 100;
      final isPayer = member.id == payerId;
      return SplitModel(
        id: '',
        expenseId: expenseId,
        memberId: member.id,
        userId: member.userId,
        owedAmount: _roundToCents(owed),
        paidAmount: isPayer ? amount : 0.0,
        percentage: pct,
      );
    }).toList();
  }

  /// Shares split - based on number of shares
  /// Example: Alice has 2 shares, Bob has 1 share. Total 3 shares.
  /// Alice pays 2/3, Bob pays 1/3
  List<SplitModel> _sharesSplit(
    String expenseId,
    double amount,
    String payerId,
    List<GroupMemberModel> participants,
    Map<String, int> shares,
  ) {
    final totalShares = shares.values.fold(0, (sum, s) => sum + s);

    return participants.map((member) {
      final memberShares = shares[member.id] ?? 1;
      final owed = (memberShares / totalShares) * amount;
      final isPayer = member.id == payerId;
      return SplitModel(
        id: '',
        expenseId: expenseId,
        memberId: member.id,
        userId: member.userId,
        owedAmount: _roundToCents(owed),
        paidAmount: isPayer ? amount : 0.0,
        shares: memberShares,
      );
    }).toList();
  }

  /// Round to nearest cent to avoid floating point issues
  double _roundToCents(double amount) {
    return (amount * 100).round() / 100;
  }

  /// Simplify debts within a group
  /// Returns a list of optimal payments to settle all debts
  /// Algorithm: Match creditors with debtors to minimize transactions
  List<SimplifiedDebt> simplifyDebts(Map<String, double> balances) {
    final creditors = <_DebtEntry>[];
    final debtors = <_DebtEntry>[];

    // Separate into creditors (positive balance) and debtors (negative balance)
    balances.forEach((memberId, balance) {
      if (balance > 0.01) {
        creditors.add(_DebtEntry(memberId, balance));
      } else if (balance < -0.01) {
        debtors.add(_DebtEntry(memberId, -balance)); // Store as positive amount
      }
    });

    // Sort by amount (largest first) for optimal matching
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final settlements = <SimplifiedDebt>[];
    int i = 0, j = 0;

    while (i < creditors.length && j < debtors.length) {
      final amount = _min(creditors[i].amount, debtors[j].amount);

      settlements.add(SimplifiedDebt(
        fromMemberId: debtors[j].memberId,
        toMemberId: creditors[i].memberId,
        amount: _roundToCents(amount),
      ));

      creditors[i].amount -= amount;
      debtors[j].amount -= amount;

      if (creditors[i].amount < 0.01) i++;
      if (debtors[j].amount < 0.01) j++;
    }

    return settlements;
  }

  double _min(double a, double b) => a < b ? a : b;
}

/// Helper class for debt simplification
class _DebtEntry {
  final String memberId;
  double amount;

  _DebtEntry(this.memberId, this.amount);
}

/// Represents a simplified debt payment
class SimplifiedDebt {
  final String fromMemberId;  // Who pays
  final String toMemberId;    // Who receives
  final double amount;

  SimplifiedDebt({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });
}
