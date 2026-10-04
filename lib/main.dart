import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'models/expense.dart';
import 'package:image_picker/image_picker.dart';
import 'services/ocr_service.dart';
import 'services/receipt_parser.dart';
import 'widgets/expense_charts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      ),
      home: const MainScreen(),
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  void refresh() {
    setState(() {});
  }

  void openScan() {
    setState(() {
      currentIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        onChanged: refresh,
        onScan: openScan,
      ),
      TransactionsScreen(
        onChanged: refresh,
      ),
      ScanReceiptScreen(
        onChanged: refresh,
      ),
    ];

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardScreen extends StatefulWidget {
  final VoidCallback onChanged;
  final VoidCallback onScan;

  const DashboardScreen({
    super.key,
    required this.onChanged,
    required this.onScan,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Expense> expenses = [];

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    try {
      final rows = await DatabaseHelper.instance.getExpenses();

      if (!mounted) return;

      setState(() {
        expenses = rows
            .map((row) => Expense.fromMap(row))
            .toList();
      });
    } catch (e) {
      debugPrint('Database error: $e');
    }
  }

  double get total {
    return expenses.fold(
      0,
      (sum, expense) => sum + expense.amount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadExpenses,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ----------------------------------------------------
            // HEADER
            // ----------------------------------------------------

            const Text(
              'Expense Tracker',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Personal Finance Manager',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------
            // TOTAL CARD
            // ----------------------------------------------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1976D2),
                    Color(0xFF42A5F5),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Spent',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    formatMoney(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${expenses.length} transaction(s)',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ----------------------------------------------------
            // ACTION BUTTONS
            // ----------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final result =
                          await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) =>
                            const AddExpenseSheet(),
                      );

                      if (result == true) {
                        await loadExpenses();
                        widget.onChanged();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onScan,
                    icon: const Icon(
                      Icons.document_scanner,
                    ),
                    label: const Text('Scan Receipt'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ====================================================
            // PIE CHART
            // ====================================================

            ExpensePieChart(
              expenses: expenses,
            ),

            const SizedBox(height: 20),

            // ====================================================
            // BAR CHART
            // ====================================================

            MonthlyExpenseBarChart(
              expenses: expenses,
            ),

            const SizedBox(height: 30),

            // ----------------------------------------------------
            // RECENT TRANSACTIONS
            // ----------------------------------------------------

            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),

                    SizedBox(height: 12),

                    Text(
                      'No expenses yet',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

            ...expenses.take(5).map(
                  (expense) => ExpenseTile(
                    expense: expense,
                    onDelete: () async {
                      if (expense.id == null) return;

                      await DatabaseHelper.instance
                          .deleteExpense(expense.id!);

                      await loadExpenses();
                      widget.onChanged();
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TRANSACTIONS
// ============================================================

class TransactionsScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const TransactionsScreen({
    super.key,
    required this.onChanged,
  });

  @override
  State<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState
    extends State<TransactionsScreen> {
  List<Expense> expenses = [];

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    try {
      final rows = await DatabaseHelper.instance.getExpenses();

      if (!mounted) return;

      setState(() {
        expenses = rows
            .map((row) => Expense.fromMap(row))
            .toList();
      });
    } catch (e) {
      debugPrint('Database error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadExpenses,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Transactions',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            if (expenses.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'No transactions',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

            ...expenses.map(
              (expense) => ExpenseTile(
                expense: expense,
                onDelete: () async {
                  if (expense.id == null) return;

                  await DatabaseHelper.instance
                      .deleteExpense(expense.id!);

                  await loadExpenses();
                  widget.onChanged();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADD EXPENSE
// ============================================================

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  State<AddExpenseSheet> createState() =>
      _AddExpenseSheetState();
}

class _AddExpenseSheetState
    extends State<AddExpenseSheet> {
  final merchantController =
      TextEditingController();

  final amountController =
      TextEditingController();

  final noteController =
      TextEditingController();

  String category = 'Food';

  final categories = const [
    'Food',
    'Shopping',
    'Transport',
    'Bills',
    'Entertainment',
    'Health',
    'Other',
  ];

  @override
  void dispose() {
    merchantController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> saveExpense() async {
    final merchant =
        merchantController.text.trim();

    final amount = double.tryParse(
      amountController.text
          .replaceAll(',', '')
          .trim(),
    );

    if (merchant.isEmpty ||
        amount == null ||
        amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid merchant and amount.',
          ),
        ),
      );

      return;
    }

    final now = DateTime.now();

    final expense = Expense(
      merchant: merchant,
      amount: amount,
      date: now.toIso8601String(),
      category: category,
      note: noteController.text.trim(),
      createdAt: now.toIso8601String(),
    );

    await DatabaseHelper.instance.insertExpense(
      expense.toMap(),
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Expense',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: merchantController,
              decoration: const InputDecoration(
                labelText: 'Merchant',
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon:
                    Icon(Icons.payments),
                suffixText: 'VND',
                hintText: 'e.g. 125,000',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  category = value;
                });
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saveExpense,
                child: const Text(
                  'SAVE EXPENSE',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SCAN RECEIPT
// ============================================================

class ScanReceiptScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const ScanReceiptScreen({
    super.key,
    required this.onChanged,
  });

  @override
  State<ScanReceiptScreen> createState() =>
      _ScanReceiptScreenState();
}

class _ScanReceiptScreenState
    extends State<ScanReceiptScreen> {
  final ImagePicker _picker = ImagePicker();

  final OcrService _ocrService =
      OcrService();

  bool isProcessing = false;

  Future<void> pickAndProcess(
    ImageSource source,
  ) async {
    try {
      setState(() {
        isProcessing = true;
      });

      final image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image == null) {
        if (!mounted) return;

        setState(() {
          isProcessing = false;
        });

        return;
      }

      final rawText =
          await _ocrService.recognizeText(
        image.path,
      );

      if (!mounted) return;

      final receipt =
          ReceiptParser.parse(rawText);

      setState(() {
        isProcessing = false;
      });

      final saved =
          await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ReceiptResultScreen(
            rawText: rawText,
            receipt: receipt,
            imagePath: image.path,
          ),
        ),
      );

      if (saved == true) {
        widget.onChanged();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'OCR error: $e',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: isProcessing
              ? const Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),

                    SizedBox(height: 20),

                    Text(
                      'Reading receipt...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Please wait while ML Kit '
                      'recognizes the text.',
                      textAlign:
                          TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons
                          .document_scanner_outlined,
                      size: 100,
                      color:
                          Colors.blue.shade400,
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Scan Receipt',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Take a photo of your receipt '
                      'or select an existing image. '
                      'The app will extract '
                      'merchant, date and total.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed: () =>
                            pickAndProcess(
                          ImageSource.camera,
                        ),
                        icon: const Icon(
                          Icons.camera_alt,
                        ),
                        label: const Text(
                          'Take Photo',
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child:
                          OutlinedButton.icon(
                        onPressed: () =>
                            pickAndProcess(
                          ImageSource.gallery,
                        ),
                        icon: const Icon(
                          Icons.photo,
                        ),
                        label: const Text(
                          'Choose from Gallery',
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ============================================================
// OCR RESULT
// ============================================================

class ReceiptResultScreen extends StatefulWidget {
  final String rawText;
  final ReceiptData receipt;
  final String imagePath;

  const ReceiptResultScreen({
    super.key,
    required this.rawText,
    required this.receipt,
    required this.imagePath,
  });

  @override
  State<ReceiptResultScreen> createState() =>
      _ReceiptResultScreenState();
}

class _ReceiptResultScreenState
    extends State<ReceiptResultScreen> {
  late final TextEditingController
      merchantController;

  late final TextEditingController
      amountController;

  late final TextEditingController
      dateController;

  String category = 'Food';

  final categories = const [
    'Food',
    'Shopping',
    'Transport',
    'Bills',
    'Entertainment',
    'Health',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    merchantController =
        TextEditingController(
      text: widget.receipt.merchant,
    );

    amountController =
        TextEditingController(
      text: widget.receipt.total == null
          ? ''
          : formatMoney(
              widget.receipt.total!,
            ).replaceFirst(' ₫', ''),
    );

    dateController =
        TextEditingController(
      text: widget.receipt.date,
    );
  }

  @override
  void dispose() {
    merchantController.dispose();
    amountController.dispose();
    dateController.dispose();
    super.dispose();
  }

  Future<void> saveExpense() async {
    final merchant =
        merchantController.text.trim();

    final amountText =
        amountController.text.trim();

    final date =
        dateController.text.trim();

    final amount =
        double.tryParse(
      amountText.replaceAll(',', ''),
    );

    if (merchant.isEmpty ||
        amount == null ||
        amount <= 0 ||
        date.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please check merchant, amount and date.',
          ),
        ),
      );

      return;
    }

    final now = DateTime.now();

    final expense = Expense(
      merchant: merchant,
      amount: amount,
      date: date,
      category: category,
      note:
          'Imported from receipt by OCR',
      imagePath: widget.imagePath,
      createdAt:
          now.toIso8601String(),
    );

    await DatabaseHelper.instance
        .insertExpense(
      expense.toMap(),
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OCR Result',
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(20),
          children: [
            const Text(
              'Extracted Information',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller:
                  merchantController,
              decoration:
                  const InputDecoration(
                labelText: 'Merchant',
                prefixIcon:
                    Icon(Icons.store),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller:
                  amountController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText:
                    'Total Amount',
                prefixIcon:
                    Icon(Icons.payments),
                suffixText: 'VND',
                hintText:
                    'e.g. 125,000',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller:
                  dateController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Transaction Date',
                prefixIcon:
                    Icon(
                  Icons.calendar_today,
                ),
                hintText:
                    'YYYY-MM-DD',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: category,
              decoration:
                  const InputDecoration(
                labelText: 'Category',
                border:
                    OutlineInputBorder(),
              ),
              items:
                  categories.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  category = value;
                });
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'Raw OCR Text',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(
                color:
                    Colors.grey.shade100,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Text(
                widget.rawText.isEmpty
                    ? 'No text recognized.'
                    : widget.rawText,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    saveExpense,
                icon: const Icon(
                  Icons.save,
                ),
                label: const Text(
                  'SAVE EXPENSE',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// EXPENSE TILE
// ============================================================

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onDelete,
  });

  IconData get icon {
    switch (expense.category) {
      case 'Food':
        return Icons.restaurant;

      case 'Shopping':
        return Icons.shopping_cart;

      case 'Transport':
        return Icons.directions_car;

      case 'Bills':
        return Icons.receipt_long;

      case 'Entertainment':
        return Icons.movie;

      case 'Health':
        return Icons.favorite;

      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Colors.blue.shade50,
          child: Icon(
            icon,
            color: Colors.blue,
          ),
        ),

        title: Text(
          expense.merchant,
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        subtitle: Text(
          '${expense.category} • '
          '${expense.date.length >= 10 ? expense.date.substring(0, 10) : expense.date}',
        ),

        trailing: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              '- ${formatMoney(expense.amount)}',
              style: const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MONEY FORMATTER
// ============================================================

String formatMoney(double amount) {
  final value =
      amount.round().toString();

  final formatted =
      value.replaceAllMapped(
    RegExp(
      r'\B(?=(\d{3})+(?!\d))',
    ),
    (_) => ',',
  );

  return '$formatted ₫';
}