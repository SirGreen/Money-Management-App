import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/l10n/app_localizations.dart';

class EditUserContextPage extends StatefulWidget {
  const EditUserContextPage({super.key});

  @override
  State<EditUserContextPage> createState() => _EditUserContextPageState();
}

class _EditUserContextPageState extends State<EditUserContextPage> {
  late final TextEditingController _contextController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsController>(context, listen: false).settings;
    _contextController = TextEditingController(text: settings.userContext);
  }

  @override
  void dispose() {
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _saveContext() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    final controller = Provider.of<SettingsController>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    try {
      await controller.updateUserContext(_contextController.text);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.contextSaved),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSavingContext),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.financialContextTitle),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveContext,
              tooltip: l10n.save,
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.financialContextDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contextController,
                maxLines: null, 
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: l10n.financialContextHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  labelText: l10n.yourContext,
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }
}