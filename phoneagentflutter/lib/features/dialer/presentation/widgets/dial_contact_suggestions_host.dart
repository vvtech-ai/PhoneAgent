import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/dial_contact_providers.dart';
import '../../domain/dial_contact_suggestion.dart';
import 'dial_contact_suggestions.dart';

/// Route adapter: shared widget remains provider/platform independent.
class DialContactSuggestionsHost extends ConsumerStatefulWidget {
  const DialContactSuggestionsHost({
    super.key,
    required this.query,
    required this.onSelect,
    this.enabled = true,
  });
  final String query;
  final bool enabled;
  final ValueChanged<DialContactSuggestion> onSelect;
  @override
  ConsumerState<DialContactSuggestionsHost> createState() =>
      _SuggestionsHostState();
}

class _SuggestionsHostState extends ConsumerState<DialContactSuggestionsHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(dialContactsProvider.notifier).load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DialContactSuggestions(
    query: widget.query,
    nativeLayout: true,
    state: ref.watch(dialContactsProvider),
    enabled: widget.enabled,
    onSelect: widget.onSelect,
    onRetry: () => ref.read(dialContactsProvider.notifier).load(),
  );
}
