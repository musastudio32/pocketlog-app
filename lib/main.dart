import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PocketLogApp());
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class PocketLogApp extends StatelessWidget {
  const PocketLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1B7A4B); // PocketLog green — money, calm, growth
    return MaterialApp(
      title: 'PocketLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8F6),
      ),
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class Entry {
  final String id;
  final double amount;
  final int categoryIndex;
  final bool isIncome;
  final String note;
  final DateTime date;

  Entry({
    required this.id,
    required this.amount,
    required this.categoryIndex,
    required this.isIncome,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'categoryIndex': categoryIndex,
        'isIncome': isIncome,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        categoryIndex: json['categoryIndex'] as int,
        isIncome: json['isIncome'] as bool,
        note: (json['note'] ?? '') as String,
        date: DateTime.parse(json['date'] as String),
      );
}

class Category {
  final String name;
  final IconData icon;
  final Color color;
  const Category(this.name, this.icon, this.color);
}

const List<Category> expenseCategories = [
  Category('Food', Icons.restaurant, Color(0xFFE07A5F)),
  Category('Grocery', Icons.shopping_basket, Color(0xFF81B29A)),
  Category('Transport', Icons.directions_bus, Color(0xFF3D8BFD)),
  Category('Bills', Icons.receipt_long, Color(0xFFB56576)),
  Category('Shopping', Icons.shopping_bag, Color(0xFFF2A65A)),
  Category('Health', Icons.favorite, Color(0xFFE63946)),
  Category('Fun', Icons.movie, Color(0xFF9B5DE5)),
  Category('Other', Icons.category, Color(0xFF6C757D)),
];

const List<Category> incomeCategories = [
  Category('Salary', Icons.payments, Color(0xFF1B7A4B)),
  Category('Business', Icons.storefront, Color(0xFF2A9D8F)),
  Category('Gift', Icons.card_giftcard, Color(0xFFF4A261)),
  Category('Other', Icons.attach_money, Color(0xFF6C757D)),
];

// ---------------------------------------------------------------------------
// Storage (offline — everything stays on the phone)
// ---------------------------------------------------------------------------

class Store {
  static const _key = 'pocketlog_entries_v1';

  static Future<List<Entry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Entry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<Entry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}

// ---------------------------------------------------------------------------
// Home screen
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Entry> _entries = [];
  bool _loading = true;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await Store.load();
    entries.sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  List<Entry> get _monthEntries => _entries
      .where((e) => e.date.year == _month.year && e.date.month == _month.month)
      .toList();

  double get _income => _monthEntries
      .where((e) => e.isIncome)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get _expense => _monthEntries
      .where((e) => !e.isIncome)
      .fold(0.0, (sum, e) => sum + e.amount);

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  Future<void> _addEntry() async {
    final entry = await showModalBottomSheet<Entry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddEntrySheet(),
    );
    if (entry != null) {
      setState(() {
        _entries.insert(0, entry);
        _entries.sort((a, b) => b.date.compareTo(a.date));
        _month = DateTime(entry.date.year, entry.date.month);
      });
      await Store.save(_entries);
    }
  }

  Future<void> _deleteEntry(Entry entry) async {
    setState(() {
      _entries.removeWhere((e) => e.id == entry.id);
    });
    await Store.save(_entries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() {
              _entries.add(entry);
              _entries.sort((a, b) => b.date.compareTo(a.date));
            });
            await Store.save(_entries);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final monthLabel = DateFormat('MMMM yyyy').format(_month);
    final monthEntries = _monthEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketLog',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Month selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(monthLabel,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                // Summary card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B7A4B), Color(0xFF2FA36B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Balance this month',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          money.format(_income - _expense),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _SummaryChip(
                              label: 'Income',
                              value: money.format(_income),
                              icon: Icons.arrow_downward,
                            ),
                            const SizedBox(width: 12),
                            _SummaryChip(
                              label: 'Expense',
                              value: money.format(_expense),
                              icon: Icons.arrow_upward,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Entries list
                Expanded(
                  child: monthEntries.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: monthEntries.length,
                          itemBuilder: (context, index) {
                            final e = monthEntries[index];
                            final cats = e.isIncome
                                ? incomeCategories
                                : expenseCategories;
                            final cat = cats[
                                e.categoryIndex.clamp(0, cats.length - 1)];
                            return Dismissible(
                              key: ValueKey(e.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _deleteEntry(e),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                color: Colors.red.shade400,
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cat.color.withOpacity(0.15),
                                  child: Icon(cat.icon,
                                      color: cat.color, size: 20),
                                ),
                                title: Text(
                                  e.note.isEmpty ? cat.name : e.note,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  '${cat.name} · ${DateFormat('d MMM').format(e.date)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  (e.isIncome ? '+' : '-') +
                                      money.format(e.amount),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: e.isIncome
                                        ? const Color(0xFF1B7A4B)
                                        : const Color(0xFF212529),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryChip(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                  Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No entries this month',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Tap Add to record your first expense',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add entry sheet — the 2-tap promise: type amount, tap a category, saved.
// ---------------------------------------------------------------------------

class AddEntrySheet extends StatefulWidget {
  const AddEntrySheet({super.key});

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isIncome = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveWithCategory(int categoryIndex) {
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount first')),
      );
      return;
    }
    final entry = Entry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      categoryIndex: categoryIndex,
      isIncome: _isIncome,
      note: _noteController.text.trim(),
      date: DateTime.now(),
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final cats = _isIncome ? incomeCategories : expenseCategories;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Expense / Income toggle
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Expense')),
                  ButtonSegment(value: true, label: Text('Income')),
                ],
                selected: {_isIncome},
                onSelectionChanged: (selection) {
                  setState(() => _isIncome = selection.first);
                },
              ),
              const SizedBox(height: 16),
              // Amount
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54),
                  hintText: '0.00',
                  border: InputBorder.none,
                ),
              ),
              // Note (optional)
              TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Note (optional)',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF1F3F1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Tap a category to save',
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 8),
              // Category grid — tapping saves instantly (tap #2)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: cats.length,
                itemBuilder: (context, index) {
                  final cat = cats[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _saveWithCategory(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cat.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child:
                              Icon(cat.icon, color: cat.color, size: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(cat.name,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
