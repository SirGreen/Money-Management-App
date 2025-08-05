import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/models/expenditure.dart';
import 'package:test_app/app/models/search_filter.dart';
import 'package:test_app/app/views/add_edit_expenditure_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/tag_icon.dart';
import 'package:test_app/l10n/app_localizations.dart';

class SearchResultsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppLocalizations l10n;
  final Function(SortOption) onSortSelected;

  const SearchResultsAppBar({
    super.key,
    required this.l10n,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.searchResults),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          actions: [
            PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort),
              tooltip: l10n.sortBy,
              onSelected: onSortSelected,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: SortOption.dateDesc,
                  child: Text(l10n.dateNewestFirst),
                ),
                PopupMenuItem(
                  value: SortOption.dateAsc,
                  child: Text(l10n.dateOldestFirst),
                ),
                PopupMenuItem(
                  value: SortOption.amountDesc,
                  child: Text(l10n.amountHighestFirst),
                ),
                PopupMenuItem(
                  value: SortOption.amountAsc,
                  child: Text(l10n.amountLowestFirst),
                ),
                PopupMenuItem(
                  value: SortOption.nameAsc,
                  child: Text(l10n.nameAZ),
                ),
                PopupMenuItem(
                  value: SortOption.nameDesc,
                  child: Text(l10n.nameZA),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class SearchResultsPage extends StatefulWidget {
  final SearchFilter filter;
  final bool findNullAmountTransactions;
  const SearchResultsPage({
    super.key,
    required this.filter,
    this.findNullAmountTransactions = false,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late List<Expenditure> _results;
  SortOption _currentSortOption = SortOption.dateDesc;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    _results = controller.getFilteredExpenditures(
      widget.filter,
      widget.findNullAmountTransactions,
    );
    _sortResults();
  }

  void _sortResults() {
    setState(() {
      switch (_currentSortOption) {
        case SortOption.dateAsc:
          _results.sort((a, b) => a.date.compareTo(b.date));
          break;
        case SortOption.amountDesc:
          _results.sort((a, b) => (b.amount ?? 0).compareTo(a.amount ?? 0));
          break;
        case SortOption.amountAsc:
          _results.sort((a, b) => (a.amount ?? 0).compareTo(b.amount ?? 0));
          break;
        case SortOption.nameAsc:
          _results.sort(
            (a, b) => a.articleName.toLowerCase().compareTo(
              b.articleName.toLowerCase(),
            ),
          );
          break;
        case SortOption.nameDesc:
          _results.sort(
            (a, b) => b.articleName.toLowerCase().compareTo(
              a.articleName.toLowerCase(),
            ),
          );
          break;
        case SortOption.dateDesc:
          _results.sort((a, b) => b.date.compareTo(a.date));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );

    final searchAppBar = SearchResultsAppBar(
      l10n: l10n,
      onSortSelected: (newSortOption) {
        _currentSortOption = newSortOption;
        _sortResults();
      },
    );

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
              padding: EdgeInsets.fromLTRB(8, totalTopOffset + 8, 8, 8),
              sliver: _results.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text(l10n.noResultsFound)),
                    )
                  : SliverList.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final expenditure = _results[index];
                        final mainTag = controller.getTagById(
                          expenditure.mainTagId,
                        );
                        final amountColor = expenditure.isIncome
                            ? Colors.green.shade700
                            : Colors.red.shade700;
                        final currentLocale = l10n.localeName;
                        final currencyCode = expenditure.currencyCode;

                        final String amountString;
                        if (expenditure.amount != null) {
                          final formattedAmount = NumberFormat.currency(
                            locale: currentLocale,
                            decimalDigits: 2,
                            name: currencyCode,
                          ).format(expenditure.amount);
                          final prefix = expenditure.isIncome ? '+' : '-';
                          amountString = '$prefix$formattedAmount';
                        } else {
                          amountString = l10n.noAmountSet;
                        }

                        return GlassCardContainer(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: EdgeInsets.zero,
                          onTap: () async {
                            try {
                              // Attempt to navigate and wait for a result
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AddEditExpenditurePage(
                                    expenditure: expenditure,
                                  ),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  _results = controller.getFilteredExpenditures(
                                    widget.filter,
                                    widget.findNullAmountTransactions,
                                  );
                                  _sortResults();
                                });
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red.shade900,
                                  content: Text('Error opening transaction.'),
                                ),
                              );
                            }
                          },
                          child: ListTile(
                            leading: mainTag != null
                                ? TagIcon(tag: mainTag)
                                : const CircleAvatar(
                                    child: Icon(Icons.help_outline),
                                  ),
                            title: Text(expenditure.articleName),
                            subtitle: Text(
                              '${mainTag?.name ?? l10n.noTag} • ${DateFormat.yMMMd(currentLocale).format(expenditure.date)}',
                            ),
                            trailing: Text(
                              amountString,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: amountColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
