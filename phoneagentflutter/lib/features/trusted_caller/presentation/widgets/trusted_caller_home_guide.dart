import 'package:flutter/material.dart';
import '../../../../core/design/native_gradient_action.dart';

export 'trusted_caller_home_reminder.dart';

enum TrustedCallerHomeGuideAction { authorize, disable, dismiss }

class TrustedCallerHomeGuide extends StatelessWidget {
  const TrustedCallerHomeGuide({super.key, required this.onAction});
  final ValueChanged<TrustedCallerHomeGuideAction> onAction;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '可信通信被叫',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Image.asset(
                        'assets/images/trusted_caller/chakencalledicon.png',
                        height: 117,
                        width: 117,
                        semanticLabel: '可信通信被叫',
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '开启可信通信被叫相关权限，展示可信来电身份信息。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 22 / 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 20),
                      NativeGradientAction(
                        actionKey: const Key('trusted-home-authorize'),
                        label: '去授权',
                        onPressed: () =>
                            onAction(TrustedCallerHomeGuideAction.authorize),
                      ),
                      TextButton(
                        key: const Key('trusted-home-disable'),
                        onPressed: () =>
                            onAction(TrustedCallerHomeGuideAction.disable),
                        child: const Text('不再提示'),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 8,
                  child: IconButton(
                    key: const Key('trusted-home-close'),
                    tooltip: '关闭',
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        onAction(TrustedCallerHomeGuideAction.dismiss),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
