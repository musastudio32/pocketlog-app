import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      home: const RootScreen(),
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

  Entry copyWith({
    double? amount,
    int? categoryIndex,
    bool? isIncome,
    String? note,
  }) {
    return Entry(
      id: id,
      amount: amount ?? this.amount,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      isIncome: isIncome ?? this.isIncome,
      note: note ?? this.note,
      date: date,
    );
  }

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

class RecurringTemplate {
  final String id;
  final double amount;
  final int categoryIndex;
  final bool isIncome;
  final String note;
  final int day; // day of month it repeats on

  RecurringTemplate({
    required this.id,
    required this.amount,
    required this.categoryIndex,
    required this.isIncome,
    required this.note,
    required this.day,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'categoryIndex': categoryIndex,
        'isIncome': isIncome,
        'note': note,
        'day': day,
      };

  factory RecurringTemplate.fromJson(Map<String, dynamic> json) =>
      RecurringTemplate(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        categoryIndex: json['categoryIndex'] as int,
        isIncome: json['isIncome'] as bool,
        note: (json['note'] ?? '') as String,
        day: json['day'] as int,
      );
}

class AddResult {
  final Entry entry;
  final bool repeatMonthly;
  AddResult(this.entry, this.repeatMonthly);
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

const List<String> currencyOptions = ['\$', 'Rs', '€', '£', '₹', '﷼', 'RM'];

// ---------------------------------------------------------------------------
// Storage (offline — everything stays on the phone)
// ---------------------------------------------------------------------------

class Store {
  static const _entriesKey = 'pocketlog_entries_v1';
  static const _currencyKey = 'pocketlog_currency';
  static const _budgetKey = 'pocketlog_budget';

  static Future<List<Entry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Entry.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveEntries(List<Entry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_entriesKey, raw);
  }

  static Future<String> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyKey) ?? '\$';
  }

  static Future<void> saveCurrency(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, symbol);
  }

  static Future<double> loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey) ?? 0;
  }

  static Future<void> saveBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, value);
  }

  static const _recurringKey = 'pocketlog_recurring_v1';

  static Future<List<RecurringTemplate>> loadRecurring() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recurringKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => RecurringTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveRecurring(List<RecurringTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(templates.map((e) => e.toJson()).toList());
    await prefs.setString(_recurringKey, raw);
  }
}

// ---------------------------------------------------------------------------
// Root screen — holds shared state, Home & Stats tabs
// ---------------------------------------------------------------------------

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  List<Entry> _entries = [];
  bool _loading = true;
  int _tab = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _currency = '\$';
  double _budget = 0;

  // search state
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RecurringTemplate> _templates = [];

  Future<void> _load() async {
    final entries = await Store.loadEntries();
    final currency = await Store.loadCurrency();
    final budget = await Store.loadBudget();
    final templates = await Store.loadRecurring();
    entries.sort((a, b) => b.date.compareTo(a.date));
    _entries = entries;
    _templates = templates;
    final added = _applyRecurring();
    if (added) {
      _entries.sort((a, b) => b.date.compareTo(a.date));
      await Store.saveEntries(_entries);
    }
    setState(() {
      _currency = currency;
      _budget = budget;
      _loading = false;
    });
  }

  /// Adds this month's entry for each recurring template once its day arrives.
  /// Returns true if anything was added.
  bool _applyRecurring() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    var added = false;
    for (final t in _templates) {
      final id = 'rec_${t.id}_${now.year}_${now.month}';
      final day = t.day > daysInMonth ? daysInMonth : t.day;
      if (now.day >= day && !_entries.any((e) => e.id == id)) {
        _entries.add(Entry(
          id: id,
          amount: t.amount,
          categoryIndex: t.categoryIndex,
          isIncome: t.isIncome,
          note: t.note,
          date: DateTime(now.year, now.month, day),
        ));
        added = true;
      }
    }
    return added;
  }

  NumberFormat get _money =>
      NumberFormat.currency(symbol: '$_currency ', decimalDigits: 2);

  List<Entry> get _monthEntries => _entries
      .where((e) => e.date.year == _month.year && e.date.month == _month.month)
      .toList();

  double get _income => _monthEntries
      .where((e) => e.isIncome)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get _expense => _monthEntries
      .where((e) => !e.isIncome)
      .fold(0.0, (sum, e) => sum + e.amount);

  List<Entry> get _searchResults {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _entries.where((e) {
      final cats = e.isIncome ? incomeCategories : expenseCategories;
      final cat = cats[e.categoryIndex.clamp(0, cats.length - 1)];
      return e.note.toLowerCase().contains(q) ||
          cat.name.toLowerCase().contains(q) ||
          e.amount.toStringAsFixed(2).contains(q);
    }).toList();
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  Future<void> _addOrEditEntry({Entry? existing}) async {
    final result = await showModalBottomSheet<AddResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEntrySheet(currency: _currency, existing: existing),
    );
    if (result != null) {
      var entry = result.entry;
      if (result.repeatMonthly && existing == null) {
        // Create a recurring template; give this month's entry the
        // deterministic id so it is not duplicated by _applyRecurring.
        final template = RecurringTemplate(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          amount: entry.amount,
          categoryIndex: entry.categoryIndex,
          isIncome: entry.isIncome,
          note: entry.note,
          day: entry.date.day,
        );
        _templates.add(template);
        await Store.saveRecurring(_templates);
        entry = Entry(
          id: 'rec_${template.id}_${entry.date.year}_${entry.date.month}',
          amount: entry.amount,
          categoryIndex: entry.categoryIndex,
          isIncome: entry.isIncome,
          note: entry.note,
          date: entry.date,
        );
      }
      setState(() {
        if (existing != null) {
          final i = _entries.indexWhere((e) => e.id == existing.id);
          if (i != -1) _entries[i] = entry;
        } else {
          _entries.insert(0, entry);
          _month = DateTime(entry.date.year, entry.date.month);
        }
        _entries.sort((a, b) => b.date.compareTo(a.date));
      });
      await Store.saveEntries(_entries);
      if (result.repeatMonthly && existing == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Recurring entry created — it will repeat every month')),
        );
      }
    }
  }

  Future<void> _manageRecurring() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
                  const SizedBox(height: 12),
                  const Text('Recurring entries',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'These repeat automatically every month.',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (_templates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No recurring entries yet.\nTurn on "Repeat every month" when adding an entry.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _templates.length,
                        itemBuilder: (context, index) {
                          final t = _templates[index];
                          final cats = t.isIncome
                              ? incomeCategories
                              : expenseCategories;
                          final cat = cats[
                              t.categoryIndex.clamp(0, cats.length - 1)];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: cat.color.withOpacity(0.15),
                              child: Icon(cat.icon,
                                  color: cat.color, size: 20),
                            ),
                            title: Text(
                              t.note.isEmpty ? cat.name : t.note,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${t.isIncome ? '+' : '-'}${_money.format(t.amount)} · every month on day ${t.day}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade400),
                              onPressed: () async {
                                _templates.removeAt(index);
                                await Store.saveRecurring(_templates);
                                setSheetState(() {});
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEntry(Entry entry) async {
    setState(() {
      _entries.removeWhere((e) => e.id == entry.id);
    });
    await Store.saveEntries(_entries);
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
            await Store.saveEntries(_entries);
          },
        ),
      ),
    );
  }

  Future<void> _setBudget() async {
    final controller =
        TextEditingController(text: _budget > 0 ? _budget.toString() : '');
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly budget'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '$_currency ',
            hintText: '0 = no budget',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                      controller.text.replaceAll(',', '.')) ??
                  0;
              Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null) {
      setState(() => _budget = value);
      await Store.saveBudget(value);
    }
  }

  Future<void> _pickCurrency() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Currency symbol'),
        children: [
          for (final c in currencyOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Row(
                children: [
                  Text(c, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  if (c == _currency)
                    const Icon(Icons.check, size: 18, color: Color(0xFF1B7A4B)),
                ],
              ),
            ),
        ],
      ),
    );
    if (choice != null) {
      setState(() => _currency = choice);
      await Store.saveCurrency(choice);
    }
  }

  Future<void> _backup() async {
    final raw = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Backup copied to clipboard. Paste it somewhere safe (notes, email).'),
      ),
    );
  }

  Future<void> _restore() async {
    final data = await Clipboard.getData('text/plain');
    final raw = data?.text ?? '';
    if (raw.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final restored = list
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore backup?'),
          content: Text(
              'This will replace your current ${_entries.length} entries with ${restored.length} entries from the backup.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        restored.sort((a, b) => b.date.compareTo(a.date));
        setState(() => _entries = restored);
        await Store.saveEntries(_entries);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Clipboard does not contain a valid backup')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search note, category, amount…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('PocketLog',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                _query = '';
                _searchController.clear();
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'budget':
                  _setBudget();
                  break;
                case 'currency':
                  _pickCurrency();
                  break;
                case 'recurring':
                  _manageRecurring();
                  break;
                case 'backup':
                  _backup();
                  break;
                case 'restore':
                  _restore();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'budget', child: Text('Set monthly budget')),
              PopupMenuItem(value: 'currency', child: Text('Currency')),
              PopupMenuItem(
                  value: 'recurring', child: Text('Recurring entries')),
              PopupMenuItem(value: 'backup', child: Text('Backup data')),
              PopupMenuItem(value: 'restore', child: Text('Restore backup')),
            ],
          ),
        ],
      ),
      body: _searching
          ? _buildSearchResults()
          : (_tab == 0 ? _buildHomeTab() : _buildStatsTab()),
      floatingActionButton: _searching
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addOrEditEntry(),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
      bottomNavigationBar: _searching
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Entries',
                ),
                NavigationDestination(
                  icon: Icon(Icons.pie_chart_outline),
                  selectedIcon: Icon(Icons.pie_chart),
                  label: 'Stats',
                ),
              ],
            ),
    );
  }

  // ------------------------------- Home tab -------------------------------

  Widget _buildHomeTab() {
    final monthLabel = DateFormat('MMMM yyyy').format(_month);
    final monthEntries = _monthEntries;

    return Column(
      children: [
        _MonthSelector(
          label: monthLabel,
          onPrev: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _SummaryCard(
            money: _money,
            income: _income,
            expense: _expense,
            budget: _budget,
            onSetBudget: _setBudget,
          ),
        ),
        Expanded(
          child: monthEntries.isEmpty
              ? const _EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No entries this month',
                  subtitle: 'Tap Add to record your first expense',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: monthEntries.length,
                  itemBuilder: (context, index) =>
                      _entryTile(monthEntries[index]),
                ),
        ),
      ],
    );
  }

  Widget _entryTile(Entry e, {bool showFullDate = false}) {
    final cats = e.isIncome ? incomeCategories : expenseCategories;
    final cat = cats[e.categoryIndex.clamp(0, cats.length - 1)];
    final dateText = showFullDate
        ? DateFormat('d MMM yyyy').format(e.date)
        : DateFormat('d MMM').format(e.date);
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteEntry(e),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        onTap: () => _addOrEditEntry(existing: e),
        leading: CircleAvatar(
          backgroundColor: cat.color.withOpacity(0.15),
          child: Icon(cat.icon, color: cat.color, size: 20),
        ),
        title: Text(
          e.note.isEmpty ? cat.name : e.note,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${cat.name} · $dateText',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          (e.isIncome ? '+' : '-') + _money.format(e.amount),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: e.isIncome ? const Color(0xFF1B7A4B) : const Color(0xFF212529),
          ),
        ),
      ),
    );
  }

  // ------------------------------ Search view ------------------------------

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (_query.trim().isEmpty) {
      return const _EmptyState(
        icon: Icons.search,
        title: 'Search all your entries',
        subtitle: 'Type a note, category name, or amount',
      );
    }
    if (results.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off,
        title: 'Nothing found',
        subtitle: 'Try a different word or amount',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: results.length,
      itemBuilder: (context, index) =>
          _entryTile(results[index], showFullDate: true),
    );
  }

  // ------------------------------- Stats tab -------------------------------

  Widget _buildStatsTab() {
    final monthLabel = DateFormat('MMMM yyyy').format(_month);
    final expenses = _monthEntries.where((e) => !e.isIncome).toList();

    final totals = <int, double>{};
    for (final e in expenses) {
      totals[e.categoryIndex] = (totals[e.categoryIndex] ?? 0) + e.amount;
    }
    final items = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue =
        items.isEmpty ? 0.0 : items.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        _MonthSelector(
          label: monthLabel,
          onPrev: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Where your money went',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(_money.format(_expense),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B7A4B))),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const _EmptyState(
                  icon: Icons.pie_chart_outline,
                  title: 'No expenses this month',
                  subtitle: 'Your category breakdown will appear here',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    final cat = expenseCategories[
                        entry.key.clamp(0, expenseCategories.length - 1)];
                    final share =
                        _expense > 0 ? entry.value / _expense * 100 : 0.0;
                    final barValue =
                        maxValue > 0 ? entry.value / maxValue : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: cat.color.withOpacity(0.15),
                            child: Icon(cat.icon, color: cat.color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(cat.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                      '${_money.format(entry.value)} · ${share.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: barValue,
                                    minHeight: 8,
                                    backgroundColor: cat.color.withOpacity(0.12),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(cat.color),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _MonthSelector extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthSelector(
      {required this.label, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final NumberFormat money;
  final double income;
  final double expense;
  final double budget;
  final VoidCallback onSetBudget;

  const _SummaryCard({
    required this.money,
    required this.income,
    required this.expense,
    required this.budget,
    required this.onSetBudget,
  });

  @override
  Widget build(BuildContext context) {
    final budgetUsed = budget > 0 ? (expense / budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = budget > 0 && expense > budget;
    final budgetColor = overBudget
        ? const Color(0xFFFF6B6B)
        : (budgetUsed > 0.8 ? const Color(0xFFFFD166) : Colors.white);

    return Container(
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
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            money.format(income - expense),
            style: const TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryChip(
                label: 'Income',
                value: money.format(income),
                icon: Icons.arrow_downward,
              ),
              const SizedBox(width: 12),
              _SummaryChip(
                label: 'Expense',
                value: money.format(expense),
                icon: Icons.arrow_upward,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (budget > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  overBudget
                      ? 'Over budget by ${money.format(expense - budget)}'
                      : 'Budget: ${money.format(expense)} of ${money.format(budget)}',
                  style: TextStyle(color: budgetColor, fontSize: 12),
                ),
                InkWell(
                  onTap: onSetBudget,
                  child: const Icon(Icons.edit, color: Colors.white70, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budgetUsed,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(budgetColor),
              ),
            ),
          ] else
            InkWell(
              onTap: onSetBudget,
              child: Row(
                children: const [
                  Icon(Icons.add_circle_outline,
                      color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('Set a monthly budget',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
        ],
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
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
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
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit entry sheet — the 2-tap promise: type amount, tap category, done
// ---------------------------------------------------------------------------

class AddEntrySheet extends StatefulWidget {
  final String currency;
  final Entry? existing;
  const AddEntrySheet({super.key, required this.currency, this.existing});

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late bool _isIncome;
  bool _repeatMonthly = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountController = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _noteController = TextEditingController(text: e?.note ?? '');
    _isIncome = e?.isIncome ?? false;
  }

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
    final Entry result;
    if (_isEditing) {
      result = widget.existing!.copyWith(
        amount: amount,
        categoryIndex: categoryIndex,
        isIncome: _isIncome,
        note: _noteController.text.trim(),
      );
    } else {
      result = Entry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        amount: amount,
        categoryIndex: categoryIndex,
        isIncome: _isIncome,
        note: _noteController.text.trim(),
        date: DateTime.now(),
      );
    }
    Navigator.of(context)
        .pop(AddResult(result, _repeatMonthly && !_isEditing));
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
        child: SingleChildScrollView(
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
                const SizedBox(height: 12),
                if (_isEditing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Edit entry',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
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
                TextField(
                  controller: _amountController,
                  autofocus: !_isEditing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    prefixText: '${widget.currency} ',
                    prefixStyle: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54),
                    hintText: '0.00',
                    border: InputBorder.none,
                  ),
                ),
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
                if (!_isEditing)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _repeatMonthly,
                    onChanged: (v) => setState(() => _repeatMonthly = v),
                    title: const Text('Repeat every month',
                        style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      'For bills, rent, salary — added automatically',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                    _isEditing
                        ? 'Tap a category to save changes'
                        : 'Tap a category to save',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 8),
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
                    final isSelected = _isEditing &&
                        widget.existing!.isIncome == _isIncome &&
                        widget.existing!.categoryIndex == index;
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
                              border: isSelected
                                  ? Border.all(color: cat.color, width: 2)
                                  : null,
                            ),
                            child: Icon(cat.icon, color: cat.color, size: 24),
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
      ),
    );
  }
}
