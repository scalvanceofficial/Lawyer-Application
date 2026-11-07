import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/account_deletion_service.dart';
import '../services/app_error_message.dart';
import '../services/app_preferences.dart';
import 'welcome_screen.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late final bool _needsPassword =
      FirebaseAuth.instance.currentUser?.providerData.any(
        (provider) => provider.providerId == 'password',
      ) ??
      false;
  StreamSubscription<dynamic>? _watch;
  String? _status;
  String? _error;
  bool _busy = false;
  bool _finishing = false;
  Future<void> _preferences = Future.value();

  bool get _accepted => _status != null;
  bool get _completed => _status == 'completed';

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid == null) return;
    unawaited(_resumePending(uid));
    _watch = AccountDeletionService.watch(uid).listen(
      (doc) {
        final status = doc.data()?['status'] as String?;
        if (!mounted || status == null) return;
        setState(() {
          _status = status;
          _error = null;
        });
        if (status != 'completed') {
          _preferences = _preferences.then(
            (_) => AppPreferences.markDeletionRequested(uid),
          );
        }
        if (status == 'completed') unawaited(_finish());
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(
          () => _error = _accepted
              ? 'Live progress is unavailable. Your deletion request continues on the server. You can safely close the app.'
              : 'Could not check deletion status. Check your connection and reopen this screen.',
        );
      },
    );
  }

  Future<void> _resumePending(String uid) async {
    if (await AppPreferences.deletionRequested(uid) &&
        mounted &&
        _status == null) {
      setState(() => _status = 'queued');
    }
  }

  Future<void> _request() async {
    if (_busy || _accepted) return;
    if (_confirmation.text.trim() != 'DELETE') {
      setState(() => _error = 'Type DELETE to confirm permanent deletion.');
      return;
    }
    if (_needsPassword && _password.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountDeletionService.request(password: _password.text);
      _password.clear();
      if (!_completed && _uid != null) {
        _preferences = _preferences.then(
          (_) => AppPreferences.markDeletionRequested(_uid),
        );
        await _preferences;
      }
      if (mounted) setState(() => _status ??= 'queued');
    } catch (error) {
      if (mounted && !_accepted) {
        setState(() => _error = appErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_finishing || _uid == null) return;
    _finishing = true;
    await _watch?.cancel();
    try {
      await _preferences;
      await AccountDeletionService.leaveAccount(_uid);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your server account was deleted. Close and reopen the app to finish clearing this device’s session.',
        );
      }
    }
    if (mounted) setState(() => _finishing = false);
  }

  Future<void> _leave() async {
    setState(() => _finishing = true);
    try {
      await _preferences;
      if (_uid != null) await AccountDeletionService.leaveAccount(_uid);
    } catch (_) {
      if (FirebaseAuth.instance.currentUser != null) {
        if (mounted) {
          setState(() {
            _finishing = false;
            _error =
                'Could not finish signing out. Your deletion continues on the server. Please try again.';
          });
        }
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _watch?.cancel();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_accepted,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Delete account'),
        automaticallyImplyLeading: !_accepted,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              _completed
                  ? Icons.check_circle_outline
                  : Icons.delete_forever_outlined,
              size: 52,
              color: _completed
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              _completed
                  ? 'Your account has been deleted'
                  : _accepted
                  ? 'Account deletion requested'
                  : 'Permanently delete your account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (_completed)
              const Text(
                'Your sign-in account and associated app data have been removed. This action cannot be undone.',
              )
            else if (_accepted) ...[
              const Text(
                'Your account is being permanently deleted. The process continues even if you close the app. You cannot cancel this request.',
              ),
              const SizedBox(height: 16),
              if (_status == 'retrying')
                const Text(
                  'Cleanup is taking longer than expected. It will retry automatically.',
                ),
              const LinearProgressIndicator(),
            ] else ...[
              const Text(
                'This removes your profile, cases you own, consultation chats, uploaded files, reviews, saved advocates, support history, and app subscription/payment records. Cases owned by other clients remain, but your consultation and personal details are removed.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Deleting this account does not cancel an Apple subscription or request a refund. Cancel any subscription through your Apple account settings to stop future charges. You can delete your account immediately without waiting for a subscription to end.',
              ),
              TextButton(
                onPressed: () async {
                  final opened = await launchUrl(
                    Uri.parse('https://apps.apple.com/account/subscriptions'),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened && mounted) {
                    setState(
                      () => _error =
                          'Open your Apple account settings, then Subscriptions.',
                    );
                  }
                },
                child: const Text('Manage Apple subscriptions'),
              ),
              const Text(
                'Files already exported or shared outside the app and records held by payment providers are not removed by this request.',
              ),
              const SizedBox(height: 20),
              if (_needsPassword)
                TextField(
                  controller: _password,
                  obscureText: true,
                  enabled: !_busy,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmation,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy || _uid == null ? null : _request,
                icon: const Icon(Icons.delete_forever),
                label: Text(
                  _busy ? 'Submitting…' : 'Permanently delete my account',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_accepted) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _finishing ? null : _leave,
                child: Text(
                  _completed
                      ? 'Return to welcome'
                      : 'Sign out while deletion continues',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({super.key});
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AccountDeletionScreen()),
    ),
    icon: const Icon(Icons.delete_forever_outlined),
    label: const Text('Delete account'),
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}
