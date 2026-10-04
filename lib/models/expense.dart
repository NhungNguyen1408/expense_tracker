class Expense {
  final int? id;
  final String merchant;
  final double amount;
  final String date;
  final String category;
  final String note;
  final String? imagePath;
  final String createdAt;

  const Expense({
    this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.note = '',
    this.imagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'date': date,
      'category': category,
      'note': note,
      'imagePath': imagePath,
      'createdAt': createdAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      merchant: map['merchant'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      category: map['category'] as String,
      note: (map['note'] as String?) ?? '',
      imagePath: map['imagePath'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }
}