import 'package:flutter/material.dart';

import '../level/level.dart';
import '../level/level_upload.dart';

/// Sends the level on the bench to be judged: check it here, sign in if
/// needed, send it, and say where it went.
///
/// A dialog rather than a panel on the bench because it is rare and it takes
/// the keyboard — an email and a password — and the bench's panel is
/// built so that nothing in it ever does.
class UploadDialog extends StatefulWidget {
  const UploadDialog({super.key, required this.level, required this.upload});

  final Level level;
  final LevelUpload upload;

  static Future<void> show(
    BuildContext context, {
    required Level level,
    required LevelUpload upload,
  }) => showDialog<void>(
    context: context,
    builder: (_) => UploadDialog(level: level, upload: upload),
  );

  @override
  State<UploadDialog> createState() => _UploadDialogState();
}

enum _Step { working, refused, signIn, sent, failed }

class _UploadDialogState extends State<UploadDialog> {
  _Step _step = _Step.working;
  String _message = '';
  final _email = TextEditingController();
  final _password = TextEditingController();

  LevelBackend get _backend => widget.upload.backend;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _step = _Step.working);
    final result = await widget.upload.send(widget.level);
    if (!mounted) return;
    setState(() {
      switch (result) {
        case RefusedHere(:final reasons):
          _step = _Step.refused;
          _message = reasons;
        case NeedsSignIn():
          _step = _Step.signIn;
          _message = '';
        case Submitted(:final id):
          _step = _Step.sent;
          _message =
              '"$id" is waiting for the gate, which runs every hour — or '
              'now, from "Run workflow" on the gate in GitHub Actions.';
        case Failed(:final message):
          _step = _Step.failed;
          _message = message;
      }
    });
  }

  Future<void> _signInAndSend() async {
    setState(() => _step = _Step.working);
    try {
      await _backend.signIn(_email.text.trim(), _password.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _step = _Step.signIn;
        _message = '$error';
      });
      return;
    }
    if (mounted) await _send();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('send "${widget.level.id}"'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(child: _body()),
      ),
      actions: [
        ..._actions(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_step == _Step.sent ? 'done' : 'close'),
        ),
      ],
    );
  }

  Widget _body() => switch (_step) {
    _Step.working => const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    ),
    _Step.refused => _text(
      'The gate would refuse this, so it was not sent:\n\n$_message',
    ),
    _Step.signIn => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text('It passes. Sign in to send it.'),
        TextField(
          key: const Key('email'),
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'email'),
        ),
        TextField(
          key: const Key('password'),
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'password'),
          onSubmitted: (_) => _signInAndSend(),
        ),
        if (_message.isNotEmpty) _error(_message),
      ],
    ),
    _Step.sent => _text(
      'Sent as ${_backend.signedInAs ?? 'you'}.\n\n$_message',
    ),
    _Step.failed => _text('Not sent:\n\n$_message'),
  };

  List<Widget> _actions() => switch (_step) {
    _Step.signIn => [
      FilledButton(
        onPressed: _signInAndSend,
        child: const Text('sign in and send'),
      ),
    ],
    _Step.failed => [
      FilledButton(onPressed: _send, child: const Text('try again')),
    ],
    _ => const [],
  };

  Widget _text(String text) => SelectableText(text);

  Widget _error(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
