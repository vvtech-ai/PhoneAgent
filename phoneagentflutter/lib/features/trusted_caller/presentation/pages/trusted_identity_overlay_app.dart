import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/design/auth_tokens.dart';
import '../../domain/trusted_identity_display_port.dart';
import '../../domain/trusted_incoming_identity.dart';
import 'trusted_identity_credentials_page.dart';

/// Display-only isolate. No providers, account listeners or SDK registration.
class TrustedIdentityOverlayApp extends StatefulWidget {
  const TrustedIdentityOverlayApp({required this.port, super.key});
  final TrustedIdentityDisplayPort port;
  @override
  State<TrustedIdentityOverlayApp> createState() => _OverlayState();
}

class _OverlayState extends State<TrustedIdentityOverlayApp> {
  TrustedIncomingIdentity? _identity;
  StreamSubscription<TrustedIncomingIdentity?>? _subscription;
  @override
  void initState() {
    super.initState();
    _subscription = widget.port.updates.listen((value) {
      if (!mounted) return;
      setState(() => _identity = value);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(value, _identity) && value != null) {
          unawaited(widget.port.rendered(value.presentationId));
        }
      });
    });
    unawaited(widget.port.ready());
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          TooltipVisibility(visible: false, child: child!),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AuthTokens.accent,
        ).copyWith(primary: AuthTokens.accent),
      ),
      home: identity == null
          ? const Scaffold(backgroundColor: Color(0xFF383B40))
          : TrustedIdentityCredentialsPage(
              identity: identity,
              onBack: () {
                unawaited(widget.port.dismiss(identity.presentationId));
              },
            ),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(widget.port.dispose());
    super.dispose();
  }
}
