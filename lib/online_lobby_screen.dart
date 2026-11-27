import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'back_arrow_button.dart';
import 'customization_service.dart';
import 'main.dart';
import 'mode_selection_screen.dart';
import 'services/online_game_service.dart';
import 'widgets/game_toast.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final OnlineGameService _onlineService = OnlineGameService();
  final TextEditingController _roomCodeController = TextEditingController();

  bool _isWaitingForFriend = false;
  bool _isCreatingRoom = false;
  bool _isJoiningRoom = false;
  String? _createdRoomCode;
  bool _hasJoinError = false;
  bool _navigatedToGame = false;
  int _roomCodeLength = 0; // tracks typed length to enable/disable Join button

  bool get _isBusy => _isCreatingRoom || _isJoiningRoom;

  @override
  void initState() {
    super.initState();
    _roomCodeController.addListener(() {
      final len = _roomCodeController.text.trim().length;
      if (len != _roomCodeLength || _hasJoinError) {
        setState(() {
          _roomCodeLength = len;
          // Clear error highlight when user starts correcting the input
          _hasJoinError = false;
        });
      }
    });
    _onlineService.connectionState.addListener(_onConnectionStateChanged);
    _initService();
  }

  void _onConnectionStateChanged() {
    if (!mounted || _navigatedToGame) return;
    if (_isWaitingForFriend &&
        _onlineService.connectionState.value ==
            OnlineConnectionState.disconnected) {
      setState(() {
        _isWaitingForFriend = false;
        _isCreatingRoom = false;
        _isJoiningRoom = false;
        _createdRoomCode = null;
      });
      GameToast.show(
        context,
        'Connection lost. Please try again.',
        type: GameToastType.error,
      );
    }
  }

  Future<void> _initService() async {
    await _onlineService.loadSavedServerUrl();

    _onlineService.onRoomCreated = (code, playerNum, seed) {
      if (!mounted) return;
      setState(() {
        _isCreatingRoom = false;
        _isJoiningRoom = false;
        _isWaitingForFriend = true;
        _createdRoomCode = code;
        _hasJoinError = false;
      });
    };

    _onlineService.onRoomError = (err) {
      if (!mounted) return;
      setState(() {
        _isCreatingRoom = false;
        _isJoiningRoom = false;
        _isWaitingForFriend = false;
        _hasJoinError = true;
      });
      GameToast.show(context, err, type: GameToastType.error);
    };

    _onlineService.onGameStart = (code, seed) {
      if (!mounted || _navigatedToGame) return;
      _navigatedToGame = true;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => GamePage(
                isOnlineMode: true,
                onlineService: _onlineService,
                roomCode: code,
                localPlayerNumber: _onlineService.localPlayerNumber ?? 1,
                matchSeed: seed,
              ),
            ),
          )
          .then((_) {
            if (!mounted) return;
            _navigatedToGame = false;
            _onlineService.clearInGameCallbacks();
            _onlineService.leaveRoom();
            _roomCodeController.clear();
            setState(() {
              _isWaitingForFriend = false;
              _isCreatingRoom = false;
              _isJoiningRoom = false;
              _createdRoomCode = null;
              _hasJoinError = false;
            });
          });
    };
  }

  @override
  void dispose() {
    _onlineService.connectionState.removeListener(_onConnectionStateChanged);
    _onlineService.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRoom() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isCreatingRoom = true;
      _hasJoinError = false;
    });
    final selections = await CustomizationService.loadSelections();
    await _onlineService.createRoom(knifeIndex: selections.knifeIndex);
    if (mounted &&
        _onlineService.connectionState.value == OnlineConnectionState.error) {
      final msg =
          _onlineService.errorMessage.value ??
          'Something went wrong. Please try again.';
      setState(() {
        _isCreatingRoom = false;
      });
      GameToast.show(context, msg, type: GameToastType.error);
    }
  }

  Future<void> _handleJoinRoom() async {
    FocusScope.of(context).unfocus();
    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.length < 3) return; // button is already disabled, guard anyway
    setState(() {
      _isJoiningRoom = true;
      _hasJoinError = false;
    });
    final selections = await CustomizationService.loadSelections();
    await _onlineService.joinRoom(code, knifeIndex: selections.knifeIndex);
    if (mounted &&
        _onlineService.connectionState.value == OnlineConnectionState.error) {
      final msg =
          _onlineService.errorMessage.value ??
          'Something went wrong. Please try again.';
      setState(() {
        _isJoiningRoom = false;
      });
      GameToast.show(context, msg, type: GameToastType.error);
    }
  }

  void _cancelWaiting() {
    _onlineService.leaveRoom();
    setState(() {
      _isWaitingForFriend = false;
      _isCreatingRoom = false;
      _isJoiningRoom = false;
      _createdRoomCode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF182842),
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final bool isDesktop = screenWidth >= 768 && screenHeight >= 500;
          final scale = isDesktop
              ? math.min(1.1, screenHeight / GameConfig.baseHeight)
              : math.min(
                  screenWidth / GameConfig.baseWidth,
                  screenHeight / GameConfig.baseHeight,
                );

          return Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF182842),
            child: Stack(
              children: [
                // Back Arrow
                Positioned(
                  top: 24,
                  left: 24,
                  child: SafeArea(
                    child: BackArrowButton(
                      onTap: () => Navigator.of(context).pop(),
                      scale: scale,
                    ),
                  ),
                ),

                // Main Content
                Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 32 * scale,
                      vertical: 24 * scale,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 360.0 : screenWidth,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'ONLINE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontFamily: 'Montserrat',
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            'VS. FRIEND',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30 * scale,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 36 * scale),
                          if (_isWaitingForFriend && _createdRoomCode != null)
                            _buildWaitingView(scale)
                          else
                            _buildCreateOrJoinView(scale),
                        ],
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

  Widget _buildCreateOrJoinView(double scale) {
    final bool codeComplete = _roomCodeLength >= 3;
    final bool joinEnabled = codeComplete && !_isBusy;

    return Column(
      children: [
        GameButton(
          label: _isCreatingRoom ? 'CONNECTING...' : 'CREATE ROOM',
          mainColor: const Color(0xFF2CDFA2),
          accentColor: const Color(0xFF52EBB6),
          lipColor: const Color(0xFF1C9B71),
          scale: scale,
          fontSize: 18,
          onTap: _isBusy ? null : _handleCreateRoom,
        ),
        SizedBox(height: 28 * scale),
        Text(
          'OR JOIN',
          style: TextStyle(
            color: Colors.white54,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 12 * scale,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 20 * scale),
        SizedBox(
          width: 230 * scale,
          child: TextField(
            controller: _roomCodeController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 3,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
              fontSize: 20 * scale,
              letterSpacing: 4.0 * scale,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ROOM PIN',
              hintStyle: TextStyle(
                color: Colors.white30,
                fontSize: 15 * scale,
                letterSpacing: 2.0 * scale,
              ),
              filled: true,
              // Subtle red tint on fill when there's a join error
              fillColor: _hasJoinError
                  ? const Color(0xFFFF3B30).withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: _hasJoinError
                    ? BorderSide(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.7),
                        width: 1.5,
                      )
                    : BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: _hasJoinError
                    ? const BorderSide(color: Color(0xFFFF3B30), width: 2)
                    : const BorderSide(color: Color(0xFF9B59B6), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 14 * scale,
              ),
            ),
          ),
        ),
        SizedBox(height: 16 * scale),
        Opacity(
          opacity: joinEnabled ? 1.0 : 0.4,
          child: GameButton(
            label: _isJoiningRoom ? 'JOINING...' : 'JOIN ROOM',
            mainColor: const Color(0xFFAA29C1),
            accentColor: const Color(0xFFBA68C8),
            lipColor: const Color(0xFF8E24AA),
            scale: scale,
            fontSize: 18,
            // null onTap = no interaction; also disabled when code incomplete
            onTap: joinEnabled ? _handleJoinRoom : null,
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingView(double scale) {
    return Container(
      width: 260 * scale,
      padding: EdgeInsets.all(22 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Text(
            'SHARE ROOM CODE',
            style: TextStyle(
              color: Colors.white60,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 12 * scale,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12 * scale),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _createdRoomCode!));
              GameToast.show(
                context,
                'Room code copied!',
                type: GameToastType.success,
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 18 * scale,
                vertical: 12 * scale,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF07101E),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(
                  color: const Color(0xFF2CDFA2).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _createdRoomCode!,
                    style: TextStyle(
                      color: const Color(0xFF2CDFA2),
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w900,
                      fontSize: 24 * scale,
                      letterSpacing: 3.0 * scale,
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                  Icon(
                    Icons.copy_rounded,
                    color: Colors.white,
                    size: 18 * scale,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20 * scale),
          _AnimatedWaitingText(scale: scale),
          SizedBox(height: 20 * scale),
          GameButton(
            label: 'CANCEL',
            mainColor: const Color(0xFFFF3B30),
            accentColor: const Color(0xFFFF6B63),
            lipColor: const Color(0xFFB71C1C),
            scale: scale * 0.85,
            fontSize: 16,
            onTap: _cancelWaiting,
          ),
        ],
      ),
    );
  }
}

class _AnimatedWaitingText extends StatefulWidget {
  final double scale;
  const _AnimatedWaitingText({required this.scale});

  @override
  State<_AnimatedWaitingText> createState() => _AnimatedWaitingTextState();
}

class _AnimatedWaitingTextState extends State<_AnimatedWaitingText> {
  Timer? _timer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount % 3) + 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white70,
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w700,
      fontSize: 13 * widget.scale,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Waiting for friend to join', style: style),
        SizedBox(
          width: 16 * widget.scale,
          child: Text('.' * _dotCount, style: style),
        ),
      ],
    );
  }
}
