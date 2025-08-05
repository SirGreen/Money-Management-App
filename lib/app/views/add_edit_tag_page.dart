import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class AddEditTagAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l10n;
  final bool isEditing;

  const AddEditTagAppBar({
    super.key,
    required this.l10n,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: isEditing ? l10n.editTag : l10n.addTag),
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

class AddEditTagPage extends StatefulWidget {
  final Tag? tag;
  const AddEditTagPage({super.key, this.tag});

  @override
  State<AddEditTagPage> createState() => _AddEditTagPageState();
}

class _AddEditTagPageState extends State<AddEditTagPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late Color _selectedColor;

  final Map<String, IconData> _availableIcons = {
    'restaurant': Icons.restaurant_menu,
    'commute': Icons.commute,
    'shopping_bag': Icons.shopping_bag_outlined,
    'sports_esports': Icons.sports_esports_outlined,
    'house': Icons.house_siding,
    'flight': Icons.flight_takeoff,
    'movie': Icons.movie_filter,
    'receipt': Icons.receipt_long,
    'health': Icons.healing,
    'label': Icons.label_outline,
    'shopping_cart': Icons.shopping_cart_outlined,
    'local_cafe': Icons.local_cafe,
    'school': Icons.school,
    'pets': Icons.pets,
    'card_giftcard': Icons.card_giftcard,
    'subscriptions': Icons.subscriptions_outlined,
    'local_gas_station': Icons.local_gas_station,
    'content_cut': Icons.content_cut,
    'lightbulb': Icons.lightbulb_outline,
    'construction': Icons.construction,
    'savings': Icons.savings_outlined,
  };
  String? _selectedIconName;

  String? _imagePath;
  File? _imageFile;

  bool get isEditing => widget.tag != null;

  final List<Color> _colorPresets = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final tag = widget.tag!;
      _nameController = TextEditingController(text: tag.name);
      _selectedColor = tag.color;
      _selectedIconName = tag.iconName;
      _imagePath = tag.imagePath;
    } else {
      _nameController = TextEditingController();
      _selectedColor = Colors.orange;
      _selectedIconName = 'label';
      _imagePath = null;
      _imageFile = null;
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 400,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imagePath = null;
        _selectedIconName = null;
      });
    }
  }

  void _pickColor(AppLocalizations l10n) {
    Color dialogPickerColor = _selectedColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chooseColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: dialogPickerColor,
            onColorChanged: (color) => dialogPickerColor = color,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
            labelTypes: const [],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            child: Text(l10n.done),
            onPressed: () {
              setState(() => _selectedColor = dialogPickerColor);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveTag(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    String? finalImagePath = _imagePath;
    if (_imageFile != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(_imageFile!.path);
        final savedImage = await _imageFile!.copy('${appDir.path}/$fileName');
        finalImagePath = savedImage.path;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.imageSaveFailed(e))));
        }
        return;
      }
    }

    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final settingsController = Provider.of<SettingsController>(
      context,
      listen: false,
    );
    final settings = settingsController.settings;

    if (isEditing) {
      final updatedTag = widget.tag!;
      updatedTag.name = _nameController.text;
      updatedTag.colorValue = _selectedColor.value;
      updatedTag.iconName = _selectedIconName;
      updatedTag.imagePath = finalImagePath;
      expenditureController.updateTag(settings, updatedTag);
      Navigator.of(context).pop();
    } else {
      final newTagId = const Uuid().v4();
      expenditureController.addTag(
        id: newTagId,
        name: _nameController.text,
        colorValue: _selectedColor.value,
        iconName: _selectedIconName,
        imagePath: finalImagePath,
      );
      Navigator.of(context).pop(newTagId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final addEditTagAppBar = AddEditTagAppBar(l10n: l10n, isEditing: isEditing);
    final double appBarHeight = addEditTagAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: addEditTagAppBar,
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, totalTopOffset + 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildTagPreviewCard(),
                    const SizedBox(height: 24),
                    _buildCustomizationCard(l10n),
                  ]),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _saveTag(l10n),
          label: Text(isEditing ? l10n.update : l10n.save),
          icon: const Icon(Icons.check),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildTagPreviewCard() {
    return GlassCard(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _selectedColor,
            backgroundImage: _imageFile != null
                ? FileImage(_imageFile!)
                : (_imagePath != null ? FileImage(File(_imagePath!)) : null)
                      as ImageProvider?,
            child: (_imageFile == null && _imagePath == null)
                ? Icon(
                    _availableIcons[_selectedIconName],
                    size: 40,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _nameController.text.isEmpty ? 'Tag Name' : _nameController.text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _nameController.text.isEmpty ? Colors.grey : null,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationCard(AppLocalizations l10n) {
    return GlassCard(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.tagName,
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? l10n.inputTagName : null,
          ),
          const SizedBox(height: 24),
          Text(l10n.color, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._colorPresets.map(
                (color) => InkWell(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == color
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: _selectedColor == color ? 3 : 1,
                      ),
                    ),
                    child: _selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _pickColor(l10n),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Icon(Icons.colorize, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.icon, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              InkWell(
                onTap: _pickImage,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _imageFile != null || _imagePath != null
                        ? _selectedColor.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _imageFile != null || _imagePath != null
                          ? _selectedColor
                          : Colors.transparent,
                      width: 2,
                    ),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : (_imagePath != null
                              ? DecorationImage(
                                  image: FileImage(File(_imagePath!)),
                                  fit: BoxFit.cover,
                                )
                              : null),
                  ),
                  child: _imageFile == null && _imagePath == null
                      ? const Icon(Icons.add_a_photo_outlined)
                      : null,
                ),
              ),
              ..._availableIcons.entries.map((entry) {
                final isSelected = entry.key == _selectedIconName;
                return InkWell(
                  onTap: () => setState(() {
                    _selectedIconName = entry.key;
                    _imageFile = null;
                    _imagePath = null;
                  }),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _selectedColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      color: isSelected ? _selectedColor : Colors.black54,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
