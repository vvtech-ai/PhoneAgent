import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

/// iOS native first-use explanation; opening or starting is not authorization.
class TrustedCallerIntroductionPage extends StatefulWidget {
  const TrustedCallerIntroductionPage({
    super.key,
    required this.onStart,
    required this.onExit,
    this.busy = false,
  });
  final VoidCallback onStart, onExit;
  final bool busy;

  @override
  State<TrustedCallerIntroductionPage> createState() => _IntroductionState();
}

class _IntroductionState extends State<TrustedCallerIntroductionPage>
    with WidgetsBindingObserver {
  Timer? _rotation;
  int _image = 1;
  bool _resumed = true;
  bool _started = false;

  void _start() {
    if (_started) return;
    _started = true;
    _rotation?.cancel();
    widget.onStart();
  }

  bool _edgeGesture = false;
  double _edgeDistance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRotation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncRotation();
  }

  void _syncRotation() {
    _rotation?.cancel();
    _rotation = null;
    final media = MediaQuery.of(context);
    if (_started ||
        !_resumed ||
        ModalRoute.of(context)?.isCurrent == false ||
        media.disableAnimations ||
        media.accessibleNavigation) {
      return;
    }
    _rotation = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _image = _image % 3 + 1);
    });
  }

  @override
  void dispose() {
    _rotation?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onExit();
      },
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: '返回'): widget.onExit,
        },
        child: GestureDetector(
          onHorizontalDragStart: (details) {
            _edgeGesture = details.localPosition.dx <= 24;
            _edgeDistance = 0;
          },
          onHorizontalDragUpdate: (details) =>
              _edgeDistance += details.primaryDelta ?? 0,
          onHorizontalDragEnd: (details) {
            if (_edgeGesture &&
                (_edgeDistance > 40 || (details.primaryVelocity ?? 0) > 300)) {
              widget.onExit();
            }
          },
          child: Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0C97FB), Color(0xFF1227B8)],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, viewport) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewport.maxHeight,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              '可信通信组件',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(minHeight: 28),
                            width: viewport.maxWidth * .6,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              '来电归属地升级版',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                color: Color(0xFF0E84F0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 26),
                            child: Text(
                              '基于"可信通信"国家标准的被叫服务\n展示带签名来电的数字证书，防篡改，防伪造',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Image.asset(
                              'assets/images/trusted_caller/sdk_show_icon$_image.png',
                              key: ValueKey(
                                'trusted-introduction-image-$_image',
                              ),
                              height: math.max(180, viewport.maxHeight - 275),
                              fit: BoxFit.contain,
                              semanticLabel: '来电身份展示示例 $_image / 3',
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: const Key('trusted-introduction-start'),
                                onPressed: widget.busy ? null : _start,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size.fromHeight(56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                child: const Text(
                                  '开始',
                                  style: TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
