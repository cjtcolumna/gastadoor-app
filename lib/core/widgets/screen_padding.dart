import 'package:flutter/widgets.dart';

/// Padding for a tab's scrolling list. The bottom includes the space taken
/// by the floating tab bar (Flutter reports it as bottom padding), so the
/// last item can scroll up above the bar instead of hiding behind it.
EdgeInsets screenPadding(BuildContext context) {
  final bottom = MediaQuery.paddingOf(context).bottom;
  return EdgeInsets.fromLTRB(16, 8, 16, bottom + 24);
}
