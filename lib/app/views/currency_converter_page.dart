import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/helpers/currency_input_formatter.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/l10n/app_localizations.dart';
import 'package:test_app/app/views/helpers/currency_picker_sheet.dart';

class CurrencyConverterAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l10n;

  const CurrencyConverterAppBar({
    super.key,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.currencyConverter),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}


class CurrencyConverterPage extends StatefulWidget {
  const CurrencyConverterPage({super.key});

  @override
  State<CurrencyConverterPage> createState() => _CurrencyConverterPageState();
}

class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
  final _fromAmountController = TextEditingController(text: '1,000');

  double? _exchangeRate;
  double? _convertedAmount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fromAmountController.addListener(_convert);
    WidgetsBinding.instance.addPostFrameCallback((_) => _convert());
  }

  @override
  void dispose() {
    _fromAmountController.removeListener(_convert);
    _fromAmountController.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final settingsController = Provider.of<SettingsController>(context, listen: false);
    final fromCurrency = settingsController.settings.converterFromCurrency;
    final toCurrency = settingsController.settings.converterToCurrency;

    final amount = double.tryParse(_fromAmountController.text.replaceAll(',', ''));
    if (amount == null) {
      if (mounted) setState(() { _convertedAmount = null; _exchangeRate = null; });
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    final controller = Provider.of<ExpenditureController>(context, listen: false);
    final rate = await controller.getBestExchangeRate(fromCurrency, toCurrency);

    if (mounted) {
      setState(() {
        _exchangeRate = rate;
        _convertedAmount = (rate != null) ? amount * rate : null;
        _isLoading = false;
      });
    }
  }

  void _swapCurrencies() {
    final settingsController = Provider.of<SettingsController>(context, listen: false);
    final from = settingsController.settings.converterFromCurrency;
    final to = settingsController.settings.converterToCurrency;

    settingsController.updateConverterCurrencies(from: to, to: from);

    final currentConvertedAmount = _convertedAmount;
    if (currentConvertedAmount != null) {
      final formattedString = NumberFormat.decimalPattern(AppLocalizations.of(context)!.localeName).format(currentConvertedAmount);
      _fromAmountController.text = formattedString;
    }
  }

  Future<void> _showCurrencyPicker(bool isFrom) async {
    final l10n = AppLocalizations.of(context)!;
    final settingsController = Provider.of<SettingsController>(context, listen: false);

    final selectedCurrency = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CurrencyPickerSheet(
        supportedCurrencies: currencyFlags.keys.toList(),
        title: isFrom ? l10n.convertFrom : l10n.convertTo,
      ),
    );

    if (selectedCurrency != null && mounted) {
      if (isFrom) {
        settingsController.updateConverterCurrencies(from: selectedCurrency);
      } else {
        settingsController.updateConverterCurrencies(to: selectedCurrency);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final converterAppBar = CurrencyConverterAppBar(l10n: l10n);
    final double appBarHeight = converterAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Consumer<SettingsController>(
        builder: (context, settingsController, child) {
          final fromCurrency = settingsController.settings.converterFromCurrency;
          final toCurrency = settingsController.settings.converterToCurrency;

          return Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: converterAppBar,
            body: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, totalTopOffset + 16, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildFromCard(l10n: l10n, fromCurrency: fromCurrency),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.white70)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: OutlinedButton(
                                onPressed: _swapCurrencies,
                                style: OutlinedButton.styleFrom(
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(12),
                                  side: const BorderSide(color: Colors.white70),
                                ),
                                child: const Icon(Icons.swap_vert),
                              ),
                            ),
                            const Expanded(child: Divider(color: Colors.white70)),
                          ],
                        ),
                      ),
                      _buildToCard(l10n: l10n, toCurrency: toCurrency),
                      const SizedBox(height: 32),
                      if (_isLoading && _convertedAmount == null)
                        const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator())
                      else if (_exchangeRate != null)
                        Center(
                          child: Chip(
                            avatar: const Icon(Icons.currency_exchange, size: 18),
                            label: Text('1 $fromCurrency = ${_exchangeRate!.toStringAsFixed(4)} $toCurrency'),
                          ),
                        )
                      else if (!_isLoading)
                        Center(
                          child: Chip(
                            avatar: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                            label: Text(l10n.exchangeRateError),
                          ),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFromCard({required AppLocalizations l10n, required String fromCurrency}) {
    final flag = currencyFlags[fromCurrency] ?? '🏳️';
    return GlassCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showCurrencyPicker(true),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(fromCurrency, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _fromAmountController,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalCurrencyInputFormatter(locale: l10n.localeName)],
          ),
        ],
      ),
    );
  }
  
  Widget _buildToCard({required AppLocalizations l10n, required String toCurrency}) {
    final flag = currencyFlags[toCurrency] ?? '🏳️';
    final theme = Theme.of(context);

    return GlassCard(
      padding: EdgeInsets.all(16),
      color: Colors.black.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showCurrencyPicker(false),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(toCurrency, style: theme.textTheme.titleLarge),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _convertedAmount != null ? NumberFormat("#,##0.00", l10n.localeName).format(_convertedAmount) : '---',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}