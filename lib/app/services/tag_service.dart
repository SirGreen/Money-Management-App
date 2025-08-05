import 'package:flutter/material.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class TagService {
  static const String defaultTagId = 'other';
  final DatabaseService _dbService;
  final Uuid _uuid = Uuid();

  TagService(this._dbService);

  List<Tag> getAllTags() {
    return _dbService.getAllTags();
  }

  Future<void> addTag({
    String? id,
    required String name,
    required int colorValue,
    String? iconName,
    String? imagePath,
  }) async {
    final newTag = Tag(
      id: id ?? _uuid.v4(),
      name: name,
      colorValue: colorValue,
      iconName: iconName,
      imagePath: imagePath,
    );
    await _dbService.saveTag(newTag);
  }

  Future<void> updateTag(Tag tag) async {
    await _dbService.saveTag(tag);
  }

  Future<bool> deleteTag(String tagId) async {
    if (tagId == defaultTagId) return false;

    final tags = _dbService.getAllTags();
    if (!tags.any((tag) => tag.id == defaultTagId)) return false;

    final allExpenditures = _dbService.getAllExpenditures();
    final expendituresToUpdate = allExpenditures
        .where((exp) => exp.mainTagId == tagId || exp.subTagIds.contains(tagId))
        .toList();

    for (final exp in expendituresToUpdate) {
      if (exp.mainTagId == tagId) {
        exp.mainTagId = defaultTagId;
      }
      exp.subTagIds.remove(tagId);
      await _dbService.saveExpenditure(exp);
    }

    await _dbService.deleteTag(tagId);
    return true;
  }

  Future<void> createDefaultTags(AppLocalizations l10n) async {
    final defaultTags = [
      Tag(
        id: 'food',
        name: l10n.food,
        colorValue: Colors.orange.toARGB32(),
        iconName: 'restaurant',
      ),
      Tag(
        id: 'transport',
        name: l10n.transport,
        colorValue: Colors.blue.toARGB32(),
        iconName: 'commute',
      ),
      Tag(
        id: 'shopping',
        name: l10n.shopping,
        colorValue: Colors.pink.toARGB32(),
        iconName: 'shopping_bag',
      ),
      Tag(
        id: 'entertainment',
        name: l10n.entertainment,
        colorValue: Colors.purple.toARGB32(),
        iconName: 'sports_esports',
      ),
      Tag(
        id: 'income',
        name: l10n.income,
        colorValue: Colors.green.toARGB32(),
        iconName: 'card_giftcard',
      ),
      Tag(
        id: defaultTagId,
        name: l10n.other,
        colorValue: Colors.grey.toARGB32(),
        iconName: 'label',
      ),
      Tag(
        id: 'savings_contribution',
        name: l10n.savings,
        colorValue: Colors.blue.toARGB32(),
        iconName: 'savings',
      ),
    ];
    for (var tag in defaultTags) {
      await _dbService.saveTag(tag);
    }
  }
}
