import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/models/settings.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/views/add_edit_tag_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/tag_icon.dart';
import 'package:test_app/l10n/app_localizations.dart';

class ManageTagsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l10n;

  const ManageTagsAppBar({
    super.key,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.manageTags),
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

class ManageTagsPage extends StatelessWidget {
  const ManageTagsPage({super.key});

  void _deleteTag(
    BuildContext context,
    ExpenditureController controller,
    Settings settings,
    Tag tag,
  ) {
    final isTagInUse = controller.expenditures.any(
        (exp) => exp.mainTagId == tag.id || exp.subTagIds.contains(tag.id));
    final l10n = AppLocalizations.of(context)!;

    if (isTagInUse) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.tagInUse),
          content: Text(l10n.warningTagInUse(tag.name)),
          actions: [
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.deleteAndContinue),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await controller.deleteTag(settings, tag.id);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.confirmDelete),
          content: Text(l10n.removeTag(tag.name)),
          actions: [
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.delete),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await controller.deleteTag(settings, tag.id);
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTagCard(
    BuildContext context,
    Tag tag,
    ExpenditureController controller,
    Settings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isDefaultTag = tag.id == ExpenditureController.defaultTagId;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddEditTagPage(tag: tag)),
        );
      },
      child: Row(
        children: [
          TagIcon(tag: tag, radius: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tag.name, style: Theme.of(context).textTheme.titleLarge),
                if (isDefaultTag) ...[
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(l10n.defaultTag,
                        style: Theme.of(context).textTheme.bodySmall),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ]
              ],
            ),
          ),
          if (!isDefaultTag)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteTag(context, controller, settings, tag);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.delete,
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
              child: const Icon(Icons.more_vert, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsController =
        Provider.of<SettingsController>(context, listen: false);

    final manageTagsAppBar = ManageTagsAppBar(
      l10n: l10n,
    );

    final double appBarHeight = manageTagsAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: manageTagsAppBar,
        body: Consumer<ExpenditureController>(
          builder: (context, controller, child) {
            final tags = controller.tags;
            tags.sort((a, b) => a.name.compareTo(b.name));

            if (tags.isEmpty) {
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(
                          top: totalTopOffset, left: 32, right: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.label_off_outlined,
                              size: 80, color: Colors.grey),
                          const SizedBox(height: 24),
                          Text(l10n.noTagsYet,
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                            l10n.tapToAddFirstTag,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(top: totalTopOffset + 8, bottom: 80), 
                  sliver: SliverList.builder(
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      return _buildTagCard(
                          context, tag, controller, settingsController.settings);
                    },
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddEditTagPage()),
            );
          },
          tooltip: l10n.addNewTag,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}