import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomizationService {
  static const String _selectedKnifeKey = 'selected_knife';
  static const String _selectedTargetKey = 'selected_target';

  // In-memory cache to avoid repeated asynchronous disk lookups
  static int? _cachedKnifeIndex;
  static int? _cachedTargetIndex;

  // List of available knives (red versions)
  static const List<String> knives = [
    'assets/images/red_knife_v2.png',
    'assets/images/red_knife_v3.png',
    'assets/images/red_knife_v4.png',
    'assets/images/red_knife_v5.png',
    'assets/images/red_knife_v6.png',
    'assets/images/red_knife_v7.png',
  ];

  // List of blue knife versions (matching the red knives index for index)
  static const List<String> blueKnives = [
    'assets/images/blue_knife_v2.png',
    'assets/images/blue_knife_v3.png',
    'assets/images/blue_knife_v4.png',
    'assets/images/blue_knife_v5.png',
    'assets/images/blue_knife_v6.png',
    'assets/images/blue_knife_v7.png',
  ];

  // List of broken red knife versions (matching index for index)
  static const List<String> brokenRedKnives = [
    'assets/images/broken_red_knife_v2.png',
    'assets/images/broken_red_knife_v3.png',
    'assets/images/broken_red_knife_v4.png',
    'assets/images/broken_red_knife_v5.png',
    'assets/images/broken_red_knife_v6.png',
    'assets/images/broken_red_knife_v7.png',
  ];

  // List of broken blue knife versions (matching index for index)
  static const List<String> brokenBlueKnives = [
    'assets/images/broken_blue_knife_v2.png',
    'assets/images/broken_blue_knife_v3.png',
    'assets/images/broken_blue_knife_v4.png',
    'assets/images/broken_blue_knife_v5.png',
    'assets/images/broken_blue_knife_v6.png',
    'assets/images/broken_blue_knife_v7.png',
  ];

  // List of available targets
  static const List<String> targets = [
    'assets/images/tree_truck_target.png',
    'assets/images/initial_cracked_tree_truck_target.png',
  ];

  // Get red version of a knife by index
  static String getRedKnifeByIndex(int index) {
    return knives[index.clamp(0, knives.length - 1)];
  }

  // Get blue version of a knife by index
  static String getBlueKnifeByIndex(int index) {
    return blueKnives[index.clamp(0, blueKnives.length - 1)];
  }

  // Get red version of a knife
  static String getRedKnife(String knifeAsset) {
    final index = knives.indexOf(knifeAsset);
    if (index != -1) {
      return knives[index];
    }
    return knives[0];
  }

  // Get blue version of a knife
  static String getBlueKnife(String knifeAsset) {
    final index = knives.indexOf(knifeAsset);
    if (index != -1) {
      return blueKnives[index];
    }
    return blueKnives[0];
  }

  // Get broken red version by index
  static String getBrokenRedKnifeByIndex(int index) {
    return brokenRedKnives[index.clamp(0, brokenRedKnives.length - 1)];
  }

  // Get broken blue version by index
  static String getBrokenBlueKnifeByIndex(int index) {
    return brokenBlueKnives[index.clamp(0, brokenBlueKnives.length - 1)];
  }

  // Get broken red version (default to v2)
  static String getBrokenRedKnife() {
    return 'assets/images/broken_red_knife_v2.png';
  }

  // Get broken blue version (default to v2)
  static String getBrokenBlueKnife() {
    return 'assets/images/broken_blue_knife_v2.png';
  }

  // Get grey pre-placed knife
  static String getGreyKnife() {
    return 'assets/images/grey_knife_v2.png';
  }

  /// Single batched fetch for all customization data (reads preferences once)
  static Future<
    ({int knifeIndex, String knifeAsset, int targetIndex, String targetAsset})
  >
  loadSelections() async {
    if (_cachedKnifeIndex != null && _cachedTargetIndex != null) {
      final kIdx = _cachedKnifeIndex!.clamp(0, knives.length - 1);
      final tIdx = _cachedTargetIndex!.clamp(0, targets.length - 1);
      return (
        knifeIndex: kIdx,
        knifeAsset: knives[kIdx],
        targetIndex: tIdx,
        targetAsset: targets[tIdx],
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final kIdx = (prefs.getInt(_selectedKnifeKey) ?? 0).clamp(
      0,
      knives.length - 1,
    );
    final tIdx = (prefs.getInt(_selectedTargetKey) ?? 0).clamp(
      0,
      targets.length - 1,
    );

    _cachedKnifeIndex = kIdx;
    _cachedTargetIndex = tIdx;

    return (
      knifeIndex: kIdx,
      knifeAsset: knives[kIdx],
      targetIndex: tIdx,
      targetAsset: targets[tIdx],
    );
  }

  static Future<int> getSelectedKnifeIndex() async {
    if (_cachedKnifeIndex != null) return _cachedKnifeIndex!;
    final selections = await loadSelections();
    return selections.knifeIndex;
  }

  static Future<void> setSelectedKnifeIndex(int index) async {
    final validIndex = index.clamp(0, knives.length - 1);
    _cachedKnifeIndex = validIndex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedKnifeKey, validIndex);
    debugPrint('Saved knife index: $validIndex, asset: ${knives[validIndex]}');
  }

  static Future<int> getSelectedTargetIndex() async {
    if (_cachedTargetIndex != null) return _cachedTargetIndex!;
    final selections = await loadSelections();
    return selections.targetIndex;
  }

  static Future<void> setSelectedTargetIndex(int index) async {
    final validIndex = index.clamp(0, targets.length - 1);
    _cachedTargetIndex = validIndex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTargetKey, validIndex);
    debugPrint(
      'Saved target index: $validIndex, asset: ${targets[validIndex]}',
    );
  }

  static Future<String> getSelectedKnife() async {
    final index = await getSelectedKnifeIndex();
    return knives[index];
  }

  static Future<String> getSelectedTarget() async {
    final index = await getSelectedTargetIndex();
    return targets[index];
  }
}
