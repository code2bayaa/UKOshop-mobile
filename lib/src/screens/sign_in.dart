/// Signing in, and signing up — M7 of the desktop set, on a phone.
///
/// Reached only when the app genuinely needs to know who somebody is: checking out, opening orders,
/// posting an ad. It is pushed rather than being a gate, so it always says **why** it appeared, and
/// closing it returns the buyer to whatever he was doing rather than to a locked door.
///
/// Registering is three steps because the API insists on the middle one: UKO e-mails a code, the code
/// is exchanged for a token, and the token is what `register` requires. That is not ceremony — an
/// account that can receive an order's collection codes has to be reachable at the address it claims.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../auth.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.auth, this.reason = ''});

  final ShopAuth auth;

  /// Why the shopper is looking at this. Shown at the top — an unexplained sign-in wall is the
  /// fastest way to lose somebody mid-basket.
  final String reason;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

enum _Mode { signIn, register }

class _SignInScreenState extends State<SignInScreen> {
  _Mode _mode = _Mode.signIn;

  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _ward = TextEditingController();
  final _county = TextEditingController();

  bool _showPassword = false;
  String _error = '';

  // Registration's middle step.
  bool _codeSent = false;
  String _code = '';
  String _emailToken = '';

  @override
  void dispose() {
    for (final c in [_identifier, _password, _name, _email, _phone, _ward, _county]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _error = '');
    try {
      await widget.auth.signIn(
        identifier: _identifier.text,
        password: _password.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _sendCode() async {
    setState(() => _error = '');
    try {
      await widget.auth.sendOtp(target: _email.text);
      if (mounted) setState(() => _codeSent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _verifyAndRegister() async {
    setState(() => _error = '');
    try {
      _emailToken = await widget.auth.verifyOtp(target: _email.text, code: _code);
      await widget.auth.register(
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
        country: 'Kenya',
        county: _county.text.trim().isEmpty ? 'Nairobi' : _county.text.trim(),
        ward: _ward.text.trim().isEmpty ? 'Kilimani' : _ward.text.trim(),
        emailToken: _emailToken,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool get _canSignIn =>
      _identifier.text.trim().isNotEmpty && _password.text.isNotEmpty;

  bool get _canSendCode =>
      _name.text.trim().length >= 2 &&
      _email.text.contains('@') &&
      _password.text.length >= 8;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: UkoColors.surface,
        appBar: AppBar(
          title: Text(_mode == _Mode.signIn ? 'Sign in' : 'Create an account'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (widget.reason.isNotEmpty) ...[
              UkoNotice(
                widget.reason,
                tone: UkoTone.primary,
                icon: Icons.lock_outline,
              ),
              const SizedBox(height: 18),
            ],
            UkoPanel(
              title: _mode == _Mode.signIn ? 'Welcome back' : 'Join UKO',
              subtitle: _mode == _Mode.signIn
                  ? 'Your e-mail or phone number, and your password.'
                  : 'Your basket comes with you — nothing in it is lost.',
              child: _mode == _Mode.signIn ? _signInForm() : _registerForm(),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 14),
              UkoNotice(_error, tone: UkoTone.danger),
            ],
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _mode = _mode == _Mode.signIn ? _Mode.register : _Mode.signIn;
                  _error = '';
                  _codeSent = false;
                }),
                child: Text(
                  _mode == _Mode.signIn
                      ? 'New to UKO? Create an account'
                      : 'Already have an account? Sign in',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You can browse UKO and fill a basket without an account. Signing in is only needed to '
              'check out, follow an order, or sell.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: UkoColors.muted, height: 1.5),
            ),
          ],
        ),
      );

  Widget _signInForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _identifier,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'E-mail or phone',
              hintText: 'you@example.com or 07xx xxx xxx',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _passwordField(),
          const SizedBox(height: 18),
          AsyncButton(
            label: 'Sign in',
            enabled: _canSignIn,
            onPressed: _canSignIn ? _signIn : null,
          ),
        ],
      );

  Widget _registerForm() {
    if (_codeSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We sent a code to ${_email.text.trim()}. Enter it to finish.',
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: UkoColors.ink2),
          ),
          const SizedBox(height: 16),
          Center(
            child: CodeInput(
              length: 6,
              autofocus: true,
              onChanged: (v) => setState(() => _code = v),
            ),
          ),
          const SizedBox(height: 18),
          AsyncButton(
            label: 'Create my account',
            enabled: _code.length >= 4,
            onPressed: _code.length >= 4 ? _verifyAndRegister : null,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _codeSent = false;
              _code = '';
            }),
            child: const Text('Change my details', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'E-mail'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone (optional)',
            hintText: '07xx xxx xxx',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _county,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'County', hintText: 'Nairobi'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ward,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ward', hintText: 'Kilimani'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Your ward decides which shelves you see first, and what delivery costs.',
          style: TextStyle(fontSize: 11, color: UkoColors.muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        _passwordField(hint: 'At least 8 characters'),
        const SizedBox(height: 18),
        AsyncButton(
          label: 'E-mail me a code',
          icon: Icons.mail_outline,
          enabled: _canSendCode,
          onPressed: _canSendCode ? _sendCode : null,
        ),
        const SizedBox(height: 10),
        const Text(
          'By creating an account you accept the UKO buyer terms.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: UkoColors.muted),
        ),
      ],
    );
  }

  Widget _passwordField({String? hint}) => TextField(
        controller: _password,
        obscureText: !_showPassword,
        decoration: InputDecoration(
          labelText: 'Password',
          hintText: hint,
          suffixIcon: IconButton(
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 20),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        onChanged: (_) => setState(() {}),
      );
}
