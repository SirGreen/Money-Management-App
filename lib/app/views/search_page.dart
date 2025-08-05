import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/models/search_filter.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/section_header.dart';
import 'package:test_app/app/views/helpers/tag_icon.dart';
import 'package:test_app/app/views/search_results_page.dart';
import 'package:test_app/l10n/app_localizations.dart';

class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l10n;

  const SearchAppBar({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.advancedSearch),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _filter = SearchFilter();
  final _keywordController = TextEditingController();
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  List<String> _selectedTagIds = [];

  @override
  void dispose() {
    _keywordController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _performSearch() {
    _filter.keyword = _keywordController.text.trim().isNotEmpty
        ? _keywordController.text.trim()
        : null;
    _filter.minAmount = _minAmountController.text.isNotEmpty
        ? double.tryParse(_minAmountController.text)
        : null;
    _filter.maxAmount = _maxAmountController.text.isNotEmpty
        ? double.tryParse(_maxAmountController.text)
        : null;
    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    _filter.tags = _selectedTagIds
        .map((id) => expenditureController.getTagById(id))
        .whereType<Tag>()
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchResultsPage(filter: _filter)),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _filter.startDate != null && _filter.endDate != null
          ? DateTimeRange(start: _filter.startDate!, end: _filter.endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _filter.startDate = picked.start;
        _filter.endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchAppBar = SearchAppBar(l10n: l10n);
    final double appBarHeight = searchAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: searchAppBar,
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, totalTopOffset + 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildKeywordCard(l10n),
                  const SizedBox(height: 16),
                  _buildAmountCard(l10n),
                  const SizedBox(height: 16),
                  _buildDateCard(l10n),
                  const SizedBox(height: 16),
                  _buildTagsCard(l10n),
                ]),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _performSearch,
          label: Text(l10n.search),
          icon: const Icon(Icons.search),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildKeywordCard(AppLocalizations l10n) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.keyword),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextFormField(
              controller: _keywordController,
              decoration: InputDecoration(
                hintText: l10n.searchByName,
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: Colors.white.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(AppLocalizations l10n) {
    final settingsController = Provider.of<SettingsController>(
      context,
      listen: false,
    );
    final settings = settingsController.settings;
    final currencySymbol = NumberFormat.simpleCurrency(
      name: settings.primaryCurrencyCode,
    ).currencySymbol;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.amountRange),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minAmountController,
                    decoration: InputDecoration(
                      labelText: l10n.minAmount,
                      prefixText: '$currencySymbol ',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _maxAmountController,
                    decoration: InputDecoration(
                      labelText: l10n.maxAmount,
                      prefixText: '$currencySymbol ',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(AppLocalizations l10n) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.dateRange),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.date_range_outlined, color: Colors.grey),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _filter.startDate != null
                        ? '${DateFormat.yMMMd(l10n.localeName).format(_filter.startDate!)} - ${DateFormat.yMMMd(l10n.localeName).format(_filter.endDate!)}'
                        : l10n.anyDate,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                TextButton(
                  onPressed: _selectDateRange,
                  child: Text(
                    _filter.startDate != null ? l10n.change : l10n.select,
                  ),
                ),
                if (_filter.startDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => setState(() {
                      _filter.startDate = null;
                      _filter.endDate = null;
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsCard(AppLocalizations l10n) {
    final controller = Provider.of<ExpenditureController>(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.tags),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: (controller.tags.isEmpty)
                ? Center(
                    child: Text(
                      l10n.noTagsYet,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: controller.tags.map((tag) {
                      final isSelected = _selectedTagIds.contains(tag.id);
                      return FilterChip(
                        label: Text(tag.name),
                        avatar: TagIcon(tag: tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTagIds.add(tag.id);
                            } else {
                              _selectedTagIds.remove(tag.id);
                            }
                          });
                        },
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.7)
                                : Colors.white.withOpacity(0.4),
                          ),
                        ),
                        backgroundColor: Colors.black.withOpacity(0.1),
                        selectedColor: Colors.white.withOpacity(0.8),
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
