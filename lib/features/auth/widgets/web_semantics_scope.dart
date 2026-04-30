import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Holds an outstanding [SemanticsHandle] for as long as it is mounted, so
/// Flutter web emits the per-field hidden `<input>` elements that browser
/// password managers rely on for autofill. Released on unmount.
///
/// Scoped to auth screens because globally-on web semantics breaks
/// flutter_quill's tap-to-focus on mobile browsers — the soft keyboard
/// fails to open when semantics nodes intercept the user-gesture chain.
class WebSemanticsScope extends StatefulWidget {
  const WebSemanticsScope({super.key, required this.child});

  final Widget child;

  @override
  State<WebSemanticsScope> createState() => _WebSemanticsScopeState();
}

class _WebSemanticsScopeState extends State<WebSemanticsScope> {
  SemanticsHandle? _handle;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _handle = SemanticsBinding.instance.ensureSemantics();
    }
  }

  @override
  void dispose() {
    _handle?.dispose();
    _handle = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
