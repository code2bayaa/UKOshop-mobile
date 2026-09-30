/// M2 · Category + Filters.
///
/// Search, results and the filter sheet, in the wireframe's order: search field → results header with
/// a sort → active filter chips → the two-column grid → "loading page 2 of 161".
///
/// Paging is by "load more" rather than infinite scroll. The API pages at a fixed `per_page` and the
/// wireframe draws an explicit load indicator; a phone list that silently grows forever also makes the
/// filter sheet — which is at the top — progressively harder to get back to.
///
/// The filter chips are the state, not a decoration. Tapping × on one re-runs the search, which is
/// what makes it obvious that a disappointing result set is something the buyer did rather than
/// something UKO lacks.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../models.dart';
import 'widgets/item_card.dart';

class BrowseTab extends StatefulWidget {
  const BrowseTab({
    super.key,
    required this.api,
    required this.onOpenItem,
    this.initialCategory = '',
    this.initialQuery = '',
  });

  final ShopApi api;
  final void Function(ItemCard) onOpenItem;
  final String initialCategory;
  final String initialQuery;

  @override
  State<BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<BrowseTab> {
  final _search = TextEditingController();
  Timer? _debounce;

  SearchResults? _results;
  final List<ItemCard> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String _error = '';

  String _category = '';
  String _sort = 'relevant';
  final Set<String> _wards = {};
  final Set<String> _conditions = {};
  bool _verifiedOnly = false;
  double? _minAmount;
  double? _maxAmount;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _search.text = widget.initialQuery;
    _load();
  }

  @override
  void didUpdateWidget(BrowseTab old) {
    super.didUpdateWidget(old);
    // The shell can push a new category in while this tab is alive — tapping a category tile on Home.
    if (widget.initialCategory != old.initialCategory ||
        widget.initialQuery != old.initialQuery) {
      _category = widget.initialCategory;
      _search.text = widget.initialQuery;
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// A search per keystroke would be a request per keystroke. 400ms is long enough to finish a word.
  void _onTyped(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = '';
      }
    });
    try {
      final page = more ? _page + 1 : 1;
      final r = await widget.api.search(
        q: _search.text.trim(),
        category: _category,
        wards: _wards.toList(),
        conditions: _conditions.toList(),
        minAmount: _minAmount,
        maxAmount: _maxAmount,
        verified: _verifiedOnly ? true : null,
        sort: _sort,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _results = r;
        _page = page;
        if (more) {
          _items.addAll(r.items);
        } else {
          _items
            ..clear()
            ..addAll(r.items);
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  bool get _anyFilters =>
      _wards.isNotEmpty ||
      _conditions.isNotEmpty ||
      _verifiedOnly ||
      _minAmount != null ||
      _maxAmount != null ||
      _category.isNotEmpty;

  void _clearAll() {
    setState(() {
      _wards.clear();
      _conditions.clear();
      _verifiedOnly = false;
      _minAmount = null;
      _maxAmount = null;
      _category = '';
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _results;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search items, brands, wards',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                    ),
            ),
            onChanged: _onTyped,
            onSubmitted: (_) => _load(),
          ),
        ),
        _resultsHeader(r),
        if (_anyFilters) _activeFilters(),
        Expanded(child: _grid(r)),
      ],
    );
  }

  Widget _resultsHeader(SearchResults? r) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r?.title ?? 'All items',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                  if (r != null)
                    Text('${r.total} ${plural(r.total, 'item')}',
                        style: const TextStyle(fontSize: 11.5, color: UkoColors.muted)),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Filter', style: TextStyle(fontSize: 12.5)),
              onPressed: () => _filterSheet(r),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
      );

  Widget _activeFilters() => SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          children: [
            if (_verifiedOnly)
              _chip('Verified only', () => setState(() => _verifiedOnly = false)),
            for (final w in _wards.toList()) _chip(w, () => setState(() => _wards.remove(w))),
            for (final c in _conditions.toList())
              _chip(c, () => setState(() => _conditions.remove(c))),
            if (_minAmount != null || _maxAmount != null)
              _chip(
                '${_minAmount == null ? 'Up to' : ksh(_minAmount!)}'
                '${_minAmount != null && _maxAmount != null ? ' – ' : ' '}'
                '${_maxAmount == null ? '' : ksh(_maxAmount!)}',
                () => setState(() {
                  _minAmount = null;
                  _maxAmount = null;
                }),
              ),
            TextButton(
              onPressed: _clearAll,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Clear all', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _chip(String label, VoidCallback onRemove) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(
          label: Text(label, style: const TextStyle(fontSize: 11.5)),
          onDeleted: () {
            onRemove();
            _load();
          },
          deleteIcon: const Icon(Icons.close, size: 14),
          visualDensity: VisualDensity.compact,
          backgroundColor: UkoColors.primary050,
          side: const BorderSide(color: UkoColors.primary300),
        ),
      );

  Widget _grid(SearchResults? r) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: UkoEmpty(
          icon: Icons.wifi_off,
          title: 'Could not search',
          subtitle: _error,
          action: AsyncButton(label: 'Try again', onPressed: () => _load()),
        ),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: UkoEmpty(
          icon: Icons.search_off,
          title: 'Nothing matched',
          subtitle: _anyFilters
              ? 'Try removing a filter — the ward and price ones narrow things fast.'
              : 'Try a different word, or browse a category from Home.',
          action: _anyFilters
              ? AsyncButton(label: 'Clear filters', outlined: true, onPressed: () async => _clearAll())
              : null,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ProductGrid(items: _items, onOpen: widget.onOpenItem),
          const SizedBox(height: 16),
          if (r != null && r.hasMore)
            AsyncButton(
              label: _loadingMore ? 'Loading…' : 'Load more (page ${_page + 1} of ${r.pages})',
              outlined: true,
              enabled: !_loadingMore,
              onPressed: _loadingMore ? null : () => _load(more: true),
            )
          else if (r != null)
            Center(
              child: Text('That is all ${r.total} of them',
                  style: const TextStyle(fontSize: 11.5, color: UkoColors.muted)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- the filter sheet
  Future<void> _filterSheet(SearchResults? r) async {
    final wards = r?.wards ?? const <({String name, int count})>[];
    final conditions = r?.conditions ?? const ['New', 'Used'];
    final min = TextEditingController(text: _minAmount?.round().toString() ?? '');
    final max = TextEditingController(text: _maxAmount?.round().toString() ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: UkoColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(UkoRadius.lg)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: UkoColors.borderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Filter',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),

                SwitchListTile(
                  value: _verifiedOnly,
                  onChanged: (v) => setSheet(() => _verifiedOnly = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Verified items only',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                    'On a shelf, checked by a host, paid through escrow.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
                const Divider(height: 24),

                const _SheetLabel('Price (KSh)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: min,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'From', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: max,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'To', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (conditions.isNotEmpty) ...[
                  const _SheetLabel('Condition'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in conditions)
                        FilterChip(
                          label: Text(c, style: const TextStyle(fontSize: 12)),
                          selected: _conditions.contains(c),
                          onSelected: (on) => setSheet(() {
                            on ? _conditions.add(c) : _conditions.remove(c);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                if (wards.isNotEmpty) ...[
                  const _SheetLabel('Ward'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final w in wards.take(12))
                        FilterChip(
                          label: Text('${w.name} (${w.count})',
                              style: const TextStyle(fontSize: 12)),
                          selected: _wards.contains(w.name),
                          onSelected: (on) => setSheet(() {
                            on ? _wards.add(w.name) : _wards.remove(w.name);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                const _SheetLabel('Sort by'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in const [
                      ('relevant', 'Most relevant'),
                      ('new', 'Newest'),
                      ('cheap', 'Price: low to high'),
                      ('expensive', 'Price: high to low'),
                    ])
                      ChoiceChip(
                        label: Text(s.$2, style: const TextStyle(fontSize: 12)),
                        selected: _sort == s.$1,
                        onSelected: (_) => setSheet(() => _sort = s.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: AsyncButton(
                        label: 'Clear',
                        outlined: true,
                        onPressed: () async {
                          Navigator.pop(sheet);
                          _clearAll();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AsyncButton(
                        label: 'Show results',
                        onPressed: () async {
                          _minAmount = double.tryParse(min.text.trim());
                          _maxAmount = double.tryParse(max.text.trim());
                          Navigator.pop(sheet);
                          await _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    min.dispose();
    max.dispose();
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: UkoColors.muted),
      );
}
