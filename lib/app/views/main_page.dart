import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:test_app/app/views/assets_page.dart';
import 'package:test_app/app/views/dashboard_page.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/home_page.dart';
import 'package:test_app/app/views/reports_page.dart';
import 'package:test_app/app/views/settings_page.dart';
import 'package:test_app/l10n/app_localizations.dart';

class MainPage extends StatefulWidget {
  final int? initialIndex;

  const MainPage({super.key, this.initialIndex});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  late final TabController _assetsTabController;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;

    _assetsTabController = TabController(length: 3, vsync: this);

    _assetsTabController.addListener(() {
      if (_selectedIndex == 3) {
        setState(() {});
      }
    });

    _widgetOptions = <Widget>[
      DashboardPage(
        onViewAllTransactions: () => _onItemTapped(1),
        onViewBudgets: () => _onItemTapped(3),
        onNavigateToSettings: () => _onItemTapped(4),
      ),
      const HomePage(),
      const ReportsPage(),
      AssetsPage(tabController: _assetsTabController),
      const SettingsPage(),
    ];
  }

  @override
  void dispose() {
    _assetsTabController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Widget? fab;
    final currentPageWidget = _widgetOptions[_selectedIndex];

    if (currentPageWidget is HomePage) {
      fab = currentPageWidget.buildFab(context);
    } else if (currentPageWidget is AssetsPage) {
      fab = currentPageWidget.buildFab(context, _assetsTabController.index);
    } else if (currentPageWidget is DashboardPage) {
      fab = currentPageWidget.buildFab(context);
    }

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
        floatingActionButton: fab,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white.withOpacity(0.2),
              elevation: 0,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.6),
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: const Icon(Icons.dashboard_outlined),
                  activeIcon: const Icon(Icons.dashboard),
                  label: l10n.dashboard, 
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.receipt_long_outlined),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: l10n.transactionsSingle, 
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.bar_chart_outlined),
                  activeIcon: const Icon(Icons.bar_chart),
                  label: l10n.reports, 
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: const Icon(Icons.account_balance_wallet),
                  label: l10n.assets, 
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings_outlined),
                  activeIcon: const Icon(Icons.settings),
                  label: l10n.settings, 
                ),
              ],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            ),
          ),
        ),
      ),
    );
  }
}