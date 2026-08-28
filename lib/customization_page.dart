import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'customization_service.dart';
import 'back_arrow_button.dart';
import 'main.dart';

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
  bool _assetsPrecached = false;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_assetsPrecached) {
      _assetsPrecached = true;
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    try {
      final futures = <Future>[
        CustomizationService.loadSelections(),
        ..._knifeData.map(
          (item) => precacheImage(AssetImage(item['asset'] as String), context),
        ),
        ..._targetData.map(
          (item) => precacheImage(AssetImage(item['asset'] as String), context),
        ),
        precacheImage(const AssetImage('assets/images/selected.png'), context),
      ];

      final results = await Future.wait(futures);
      final selections =
          results[0]
              as ({
                int knifeIndex,
                String knifeAsset,
                int targetIndex,
                String targetAsset,
              });

      if (mounted) {
        setState(() {
          _selectedKnifeIndex = selections.knifeIndex;
          _selectedTargetIndex = selections.targetIndex;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading customization data: $e');
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final bool isDesktop = screenWidth >= 768 && screenHeight >= 500;
          final scale = isDesktop
              ? math.min(1.0, screenHeight / 850.0)
              : math.min(
                  screenWidth / GameConfig.baseWidth,
                  screenHeight / GameConfig.baseHeight,
                );

          final gridWidth = 300.0 * scale;
          final topPadding = isDesktop ? 60.0 * scale : 70.0 * scale;

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D1D36),
                  Color(0xFF0B172A),
                  Color(0xFF091222),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Top-Left Back Arrow
                Positioned(
                  left: 24,
                  top: 24,
                  child: SafeArea(
                    child: BackArrowButton(
                      onTap: () => Navigator.pop(context),
                      scale: scale,
                    ),
                  ),
                ),

                // Main Content Anchored From Top (Toggle never jumps when switching tabs)
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2CDFA2),
                      strokeWidth: 3,
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.topCenter,
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.only(top: topPadding),
                        child: SizedBox(
                          width: gridWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Fixed Top Toggle
                              _buildToggle(scale),
                              SizedBox(height: 24 * scale),

                              // Grid Content (Scrollable if needed on small screens)
                              Flexible(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: _buildGrid(scale),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggle(double scale) {
    final toggleWidth = 280.0 * scale;
    final toggleHeight = 56.0 * scale;
    final pillWidth = (toggleWidth - 12 * scale) / 2;

    return Container(
      width: toggleWidth,
      height: toggleHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF8B909A).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            left: _selectedTab == 'knife' ? 6 * scale : toggleWidth / 2,
            top: 5 * scale,
            width: pillWidth,
            height: toggleHeight - 10 * scale,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF404040).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_selectedTab != 'knife') {
                        setState(() {
                          _selectedTab = 'knife';
                        });
                      }
                    },
                    child: Center(
                      child: Text(
                        'KNIFE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15 * scale,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_selectedTab != 'target') {
                        setState(() {
                          _selectedTab = 'target';
                        });
                      }
                    },
                    child: Center(
                      child: Text(
                        'TARGET',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15 * scale,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(double scale) {
    final isKnifeTab = _selectedTab == 'knife';
    final data = isKnifeTab ? _knifeData : _targetData;

    return GridView.builder(
      key: ValueKey(_selectedTab),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 18 * scale,
        mainAxisSpacing: 18 * scale,
        childAspectRatio: 130 / 160,
      ),
      itemCount: data.length,
      itemBuilder: (context, index) {
        return _buildItemCard(index, scale);
      },
    );
  }

  Widget _buildItemCard(int index, double scale) {
    final data = _selectedTab == 'knife' ? _knifeData : _targetData;
    final item = data[index];
    final isSelected = _selectedTab == 'knife'
        ? _selectedKnifeIndex == index
        : _selectedTargetIndex == index;

    return _ItemCard(
      key: ValueKey('${_selectedTab}_$index'),
      knife: item,
      isSelected: isSelected,
      scale: scale,
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
  final double scale;
  final VoidCallback onTap;

  const _ItemCard({
    super.key,
    required this.knife,
    required this.isSelected,
    required this.scale,
    required this.onTap,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final lipHeight = 5.0 * widget.scale;
    final baseWidth = 130.0 * widget.scale;
    final baseHeight = 160.0 * widget.scale;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
                    color: const Color(0xFF686D76),
                    borderRadius: BorderRadius.circular(12 * widget.scale),
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
                bottom: _isPressed ? 0 : lipHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B909A),
                    borderRadius: BorderRadius.circular(12 * widget.scale),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12 * widget.scale),
                    child: Stack(
                      children: [
                        // Main circle (light gray)
                        Positioned(
                          left: 25 * widget.scale,
                          top: 40 * widget.scale,
                          child: Container(
                            width: 80 * widget.scale,
                            height: 80 * widget.scale,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE1E1E1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Decorative circles
                        Positioned(
                          right: 8 * widget.scale,
                          top: 75 * widget.scale,
                          child: Container(
                            width: 17 * widget.scale,
                            height: 17 * widget.scale,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAEAEA),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12 * widget.scale,
                          top: 75 * widget.scale,
                          child: Container(
                            width: 11 * widget.scale,
                            height: 11 * widget.scale,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAEAEA),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 15 * widget.scale,
                          top: 38 * widget.scale,
                          child: Container(
                            width: 8 * widget.scale,
                            height: 8 * widget.scale,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAEAEA),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Item image centered in main circle
                        Positioned(
                          left: 10 * widget.scale,
                          top: 25 * widget.scale,
                          child: SizedBox(
                            width: 110 * widget.scale,
                            height: 110 * widget.scale,
                            child: Center(
                              child: Transform.flip(
                                flipY: widget.knife['flipY'] as bool,
                                child: Transform.rotate(
                                  angle: widget.knife['rotation'] as double,
                                  child: SizedBox(
                                    width: 125 * widget.scale,
                                    height: 125 * widget.scale,
                                    child: Image.asset(
                                      widget.knife['asset'] as String,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Selected checkmark
                        if (widget.isSelected)
                          Positioned(
                            right: 8 * widget.scale,
                            top: 8 * widget.scale,
                            child: Image.asset(
                              'assets/images/selected.png',
                              width: 24 * widget.scale,
                              height: 24 * widget.scale,
                              fit: BoxFit.contain,
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
      ),
    );
  }
}
