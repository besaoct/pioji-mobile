import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';
import 'scaffolds.dart';
import 'states.dart';

/// Opens a detail screen by ID. Shows the record passed from the list right
/// away, then replaces it with the fresh copy from `GET /{module}/{id}`.
/// Opened without a record (deep link), it loads first.
class DetailLoader<T> extends ConsumerStatefulWidget {
  const DetailLoader({
    super.key,
    required this.id,
    required this.initial,
    required this.fetch,
    required this.builder,
    required this.what,
  });

  final int? id;
  final T? initial;
  final Future<T> Function(WidgetRef ref, int id) fetch;
  final Widget Function(T item) builder;
  final String what;

  @override
  ConsumerState<DetailLoader<T>> createState() => _DetailLoaderState<T>();
}

class _DetailLoaderState<T> extends ConsumerState<DetailLoader<T>> {
  late T? _item = widget.initial;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.id;
    if (id == null) {
      setState(() => _error = const NotFoundFailure());
      return;
    }
    try {
      final fresh = await widget.fetch(ref, id);
      if (mounted) setState(() => _item = fresh);
    } on AppFailure catch (f) {
      // Keep showing the list copy if we have one.
      if (mounted && _item == null) setState(() => _error = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item != null) return widget.builder(item);
    if (_error != null) {
      return DetailScaffold(
        title: widget.what[0].toUpperCase() + widget.what.substring(1),
        children: [
          ErrorState(
            error: _error!,
            onRetry: () {
              setState(() => _error = null);
              _load();
            },
          ),
        ],
      );
    }
    return const DetailScaffold(
      title: '',
      children: [Padding(padding: EdgeInsets.all(48), child: Center(child: CupertinoActivityIndicator()))],
    );
  }
}
