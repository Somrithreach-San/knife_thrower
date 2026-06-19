import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomizationService {
  static const String _selectedKnifeKey = 'selected_knife';
  static const String _selectedTargetKey = 'selected_target';

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
    return knives[index];
  }

  // Get blue version of a knife by index
  static String getBlueKnifeByIndex(int index) {
    return blueKnives[index];
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
    return brokenRedKnives[index];
  }

  // Get broken blue version by index
  static String getBrokenBlueKnifeByIndex(int index) {
    return brokenBlueKnives[index];
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

  static Future<int> getSelectedKnifeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_selectedKnifeKey) ?? 0;
    debugPrint('Loaded knife index: $index, asset: ${knives[index]}');
    return index;
  }

  static Future<void> setSelectedKnifeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedKnifeKey, index);
    debugPrint('Saved knife index: $index, asset: ${knives[index]}');
  }

  static Future<int> getSelectedTargetIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_selectedTargetKey) ?? 0;
    // Ensure index is valid (in case targets list was shortened)
    final validIndex = index.clamp(0, targets.length - 1);
    debugPrint('Loaded target index: $validIndex, asset: ${targets[validIndex]}');
    return validIndex;
  }

  static Future<void> setSelectedTargetIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTargetKey, index);
    debugPrint('Saved target index: $index, asset: ${targets[index]}');
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
