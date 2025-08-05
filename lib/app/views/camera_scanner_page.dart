import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/services/llm_service.dart';
import 'package:test_app/app/views/add_edit_expenditure_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/l10n/app_localizations.dart';

class CameraScannerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l10n;

  const CameraScannerAppBar({
    super.key,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.scanReceipt),
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

class CameraScannerPage extends StatefulWidget {
  const CameraScannerPage({super.key});

  @override
  State<CameraScannerPage> createState() => _CameraScannerPageState();
}

class _CameraScannerPageState extends State<CameraScannerPage> {
  final LLMService _llmService = LLMService();
  bool _isProcessing = false;

  Future<void> _getImageAndProcess(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null || !mounted) return;

    setState(() => _isProcessing = true);

    final expenditureController =
        Provider.of<ExpenditureController>(context, listen: false);
    final existingTagNames =
        expenditureController.tags.map((t) => t.name).toList();

    final parsedData = await _llmService.processReceiptImage(
      File(pickedFile.path),
      existingTagNames,
    );

    if (!mounted) return;

    String? prefilledName;
    double? prefilledAmount;
    List<Tag> recommendedTags = [];
    String? memo;

    if (parsedData != null) {
      prefilledName = parsedData['store_name'] as String?;

      final amountValue = parsedData['total_amount'];
      if (amountValue is num) {
        prefilledAmount = amountValue.toDouble();
      } else if (amountValue is String) {
        prefilledAmount = double.tryParse(amountValue.replaceAll(',', ''));
      }

      if (parsedData['recommended_tags'] is List) {
        List<String> recommendedTagNames =
            List<String>.from(parsedData['recommended_tags']);
        recommendedTags = expenditureController.tags
            .where((t) => recommendedTagNames.contains(t.name))
            .toList();
      }

      if (parsedData['memo'] is String) {
        memo = parsedData['memo'];
      }
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AddEditExpenditurePage(
          prefilledName: prefilledName,
          prefilledAmount: prefilledAmount,
          prefilledTags: recommendedTags,
          prefilledReceiptPath: pickedFile.path,
          prefilledMemo: memo,
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return SizedBox(
      width: 200,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scannerAppBar = CameraScannerAppBar(l10n: l10n);
    final double appBarHeight = scannerAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: scannerAppBar,
        body: Stack(
          children: [
            // --- THIS IS THE FIX ---
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: totalTopOffset),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            l10n.scanYourReceipt,
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.letAiDoTheHeavyLifting,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),
                          Wrap(
                            spacing: 24,
                            runSpacing: 24,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildOptionCard(
                                context: context,
                                icon: Icons.camera_alt_outlined,
                                title: l10n.takePicture,
                                subtitle: l10n.useYourCameraToScan,
                                onTap: () => _getImageAndProcess(ImageSource.camera),
                              ),
                              _buildOptionCard(
                                context: context,
                                icon: Icons.photo_library_outlined,
                                title: l10n.selectFromGallery,
                                subtitle: l10n.uploadAnExistingImage,
                                onTap: () =>
                                    _getImageAndProcess(ImageSource.gallery),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
             // --- END OF FIX ---
            if (_isProcessing)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: GlassCard(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 24),
                            Text(
                              l10n.analyzingYourReceipt,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}