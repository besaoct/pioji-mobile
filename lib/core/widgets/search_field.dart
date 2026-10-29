import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../utils/debouncer.dart';

class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.hint, required this.onChanged, this.initial = ''});

  final String hint;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _controller = TextEditingController(text: widget.initial);
  final _debounce = Debouncer();

  @override
  void dispose() {
    _controller.dispose();
    _debounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(color: c.fill, shape: AppRadius.controlBorder),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 18, color: c.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              style: AppText.body,
              decoration: InputDecoration(hintText: widget.hint),
              onChanged: (v) {
                setState(() {});
                _debounce(() => widget.onChanged(v.trim()));
              },
            ),
          ),
          if (_controller.text.isNotEmpty)
            Semantics(
              button: true,
              label: 'Clear search',
              child: GestureDetector(
                onTap: () {
                  _controller.clear();
                  setState(() {});
                  widget.onChanged('');
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(CupertinoIcons.clear_circled_solid, size: 18, color: c.textTertiary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
