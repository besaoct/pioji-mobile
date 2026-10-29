import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_provider.dart';
import '../errors/app_failure.dart';

/// Shared submit behaviour for every form: blocks double submits, maps 422
/// errors onto fields, shows other failures in a banner, keeps entered values.
mixin FormSubmit<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  bool submitting = false;
  String? banner;
  Map<String, String> errors = const {};

  String? err(String key) => errors[key];

  /// Runs [action]. Returns its result, or null when it failed (state is
  /// updated for the UI). [onDuplicate] handles a duplicate invoice response.
  Future<T?> submit<T>(
    Future<T> Function() action, {
    Map<String, String> clientErrors = const {},
    Future<T?> Function(DuplicateFailure f)? onDuplicate,
  }) async {
    if (submitting) return null;
    FocusManager.instance.primaryFocus?.unfocus();
    if (clientErrors.isNotEmpty) {
      setState(() {
        errors = clientErrors;
        banner = 'Check the highlighted fields.';
      });
      return null;
    }
    final online = ref.read(isOnlineProvider).value ?? true;
    if (!online) {
      setState(() => banner = "You're offline. Connect to save. Your entries are kept.");
      return null;
    }
    setState(() {
      submitting = true;
      banner = null;
      errors = const {};
    });
    try {
      return await action();
    } on DuplicateFailure catch (f) {
      if (onDuplicate != null) {
        if (mounted) setState(() => submitting = false);
        return onDuplicate(f);
      }
      _fail(f);
    } on ValidationFailure catch (f) {
      if (mounted) {
        setState(() {
          errors = f.fieldErrors;
          banner = f.fieldErrors.isEmpty ? f.serverMessage : 'Check the highlighted fields.';
        });
      }
    } on AppFailure catch (f) {
      _fail(f);
    } catch (e) {
      _fail(UnknownFailure(e));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
    return null;
  }

  void _fail(AppFailure f) {
    if (mounted) setState(() => banner = f.message);
  }
}
