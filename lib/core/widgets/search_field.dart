import 'dart:async';

import 'package:flutter/material.dart' show InputDecoration, TextField;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';

/// A search field in the app's own dress — the same container as the
/// add-by-URL field, so nothing new was invented for it.
///
/// Debounced, because filtering runs on every keystroke and a 45-item catalog
/// does not need to be re-grouped forty times a second.
class HsSearchField extends StatefulWidget {
  const new({
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
    this.debounce = const Duration(milliseconds: 180),
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final Duration debounce;

  @override
  State<HsSearchField> createState() => _HsSearchFieldState();
}

class _HsSearchFieldState extends State<HsSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  var _hasText = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _hasText = value.isNotEmpty);
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () => widget.onChanged(value));
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() => _hasText = false);
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return Container(
      height: HsSize.buttonLarge,
      padding: const EdgeInsets.only(left: HsSpace.x4, right: HsSpace.x2),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.stroke),
        borderRadius: HsRadius.buttonBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              cursorColor: palette.textPrimary,
              style: HsType.buttonLarge.copyWith(color: palette.textPrimary),
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: HsType.buttonLarge.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _hasText ? 1 : 0,
            duration: HsMotion.micro,
            curve: HsMotion.microCurve,
            child: IgnorePointer(
              ignoring: !_hasText,
              child: Pressable(
                onTap: _clear,
                semanticLabel: 'Clear search',
                child: SizedBox(
                  width: HsSize.navItem,
                  height: HsSize.navItem,
                  child: Center(
                    child: Text(
                      '×',
                      style: HsType.buttonLarge.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
