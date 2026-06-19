import 'package:flutter/material.dart';
import 'customization_service.dart';
import 'back_arrow_button.dart';

class CustomizationPage extends StatefulWidget {
  const CustomizationPage({super.key});

  @override
  State<CustomizationPage> createState() => _CustomizationPageState();
}

class _CustomizationPageState extends State<CustomizationPage> {
  String _selectedTab = 'knife';
  int _selectedKnifeIndex = 0;
  int _selectedTargetIndex = 0;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _knifeData = [
    {
      'asset': 'assets/images/red_knife_v2.png',
      'rotation': 0.5,
      'flipY': false,
    },
    {
      'asset': 'assets/images/red_knife_v3.png',
      'rotation': 0.5,
      'flipY': false,
    },
    {
      'asset': 'assets/images/red_knife_v4.png',
      'rotation': 0.5,
      'flipY': false,
    },
    {
      'asset': 'assets/images/red_knife_v5.png',
      'rotation': 0.5,
      'flipY': false,
    },
    {
      'asset': 'assets/images/red_knife_v6.png',
      'rotation': 0.5,
      'flipY': false,
    },
    {
      'asset': 'assets/images/red_knife_v7.png',
      'rotation': 0.5,
      'flipY': false,
    },
  ];

  final List<Map<String, dynamic>> _targetData = [
    {
      'asset': 'assets/images/tree_truck_target.png',
      'rotation': 0.0,
      'flipY': false,
    },
    {
      'asset': 'assets/images/initial_cracked_tree_truck_target.png',
      'rotation': 0.0,
      'flipY': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSelections();
  }

  Future<void> _loadSelections() async {
    try {
      final knifeIndex = await CustomizationService.getSelectedKnifeIndex();
      final targetIndex = await CustomizationService.getSelectedTargetIndex();
      if (mounted) {
        setState(() {
          _selectedKnifeIndex = knifeIndex;
          _selectedTargetIndex = targetIndex;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading selections: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveKnifeSelection(int index) async {
    try {
      await CustomizationService.setSelectedKnifeIndex(index);
      debugPrint('Saved knife index: $index');
    } catch (e) {
      debugPrint('Error saving knife selection: $e');
    }
  }

  Future<void> _saveTargetSelection(int index) async {
    try {
      await CustomizationService.setSelectedTargetIndex(index);
      debugPrint('Saved target index: $index');
    } catch (e) {
      debugPrint('Error saving target selection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale =
              1.0; // Using fixed scale for customization page to match original
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF181D35), Color(0xFF112E55)],
              ),
            ),
            child: Stack(
              children: [
                // Back arrow at consistent position
                Positioned(
                  left: 16 * scale,
                  top: 16 * scale,
                  child: SafeArea(child: _buildBackArrow(scale: scale)),
                ),
                // Toggle
                Positioned(
                  top: statusBarH + 80,
                  left: 0,
                  right: 0,
                  child: _buildToggle(),
                ),
                // Grid
                Positioned(
                  top: statusBarH + 181,
                  left: 52,
                  right: 52,
                  bottom: 0,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _buildGrid(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackArrow({double scale = 1.0}) {
    return BackArrowButton(onTap: () => Navigator.pop(context), scale: scale);
  }

  Widget _buildToggle() {
    return Center(
      child: Container(
        width: 290,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF999999),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF747474),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: _selectedTab == 'knife' ? 6 : 147,
              top: 5,
              width: 137,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF404040).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTab = 'knife';
                      });
                    },
                    child: const Center(
                      child: Text(
                        'KNIFE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTab = 'target';
                      });
                    },
                    child: const Center(
                      child: Text(
                        'TARGET',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final data = _selectedTab == 'knife' ? _knifeData : _targetData;
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 28,
        mainAxisSpacing: 15,
        childAspectRatio: 130 / 160,
      ),
      itemCount: data.length,
      itemBuilder: (context, index) {
        return _buildItemCard(index);
      },
    );
  }

  Widget _buildItemCard(int index) {
    final data = _selectedTab == 'knife' ? _knifeData : _targetData;
    final item = data[index];
    final isSelected = _selectedTab == 'knife'
        ? _selectedKnifeIndex == index
        : _selectedTargetIndex == index;

    return _ItemCard(
      knife: item,
      isSelected: isSelected,
      onTap: () async {
        setState(() {
          if (_selectedTab == 'knife') {
            _selectedKnifeIndex = index;
          } else {
            _selectedTargetIndex = index;
          }
        });
        if (_selectedTab == 'knife') {
          await _saveKnifeSelection(index);
        } else {
          await _saveTargetSelection(index);
        }
      },
    );
  }
}

class _ItemCard extends StatefulWidget {
  final Map<String, dynamic> knife;
  final bool isSelected;
  final VoidCallback onTap;

  const _ItemCard({
    required this.knife,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const lipHeight = 4.0;
    const baseWidth = 130.0;
    const baseHeight = 160.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: SizedBox(
        width: baseWidth,
        height: baseHeight,
        child: Stack(
          children: [
            // 3D bottom lip
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: baseHeight - lipHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF676E7B),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Main face
            AnimatedPositioned(
              duration: _isPressed
                  ? const Duration(milliseconds: 50)
                  : const Duration(milliseconds: 100),
              top: _isPressed ? lipHeight : 0,
              left: 0,
              right: 0,
              height: baseHeight - lipHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF778090),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Main circle (D9D9D9)
                      Positioned(
                        left: 17,
                        top: 32,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD9D9D9),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Decorative circles around main circle (matching your image)
                      Positioned(
                        right: 8,
                        top: 75,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6E4E4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 75,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6E4E4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 15,
                        top: 38,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6E4E4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Knife image centered in main circle
                      Positioned(
                        left: 17,
                        top: 32,
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: Center(
                            child: Transform.flip(
                              flipY: widget.knife['flipY'] as bool,
                              child: Transform.rotate(
                                angle: widget.knife['rotation'] as double,
                                child: SizedBox(
                                  width: 109.51,
                                  height: 109.51,
                                  child: Image.asset(
                                    widget.knife['asset'] as String,
                                    width: 109.51,
                                    height: 109.51,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Selected checkmark badge
                      if (widget.isSelected)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
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
