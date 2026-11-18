import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../core/validators.dart';
import '../state/auth_notifier.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  /// Проверка пароля по мере ввода и при отправке формы.
  static String? passwordValidator(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Введите пароль';
    if (text.length < 8) return 'Не короче 8 символов';
    if (!RegExp(r'\d').hasMatch(text)) return 'Нужна хотя бы одна цифра';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(text)) {
      return 'Нужен специальный символ';
    }
    return null;
  }

  static String? livePasswordMessage(String value) {
    if (value.isEmpty) return null;
    if (value.length < 8) return 'Не короче 8 символов';
    if (!RegExp(r'\d').hasMatch(value)) return 'Нужна хотя бы одна цифра';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Нужен специальный символ (!@# и т.п.)';
    }
    return 'Пароль подходит';
  }

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _passwordHint;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _fullName.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(
      () => _passwordHint = RegisterScreen.livePasswordMessage(_password.text),
    );
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthNotifier>().register(
        username: _username.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
      );
      if (!mounted) return;
      context.go('/');
    } on ApiValidationException catch (e) {
      setState(() => _error = e.errors.values.join(' '));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Не удалось зарегистрироваться.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintOk = _passwordHint == 'Пароль подходит';
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Регистрация',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Новая учётная запись получает роль «Покупатель».',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _fullName,
                        decoration: const InputDecoration(
                          labelText: 'ФИО',
                          border: OutlineInputBorder(),
                        ),
                        validator: V.combine([
                          V.required('Укажите имя'),
                          V.length(min: 2, max: 120),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'Логин',
                          border: OutlineInputBorder(),
                        ),
                        validator: V.combine([
                          V.required('Введите логин'),
                          V.length(min: 3, max: 40),
                          V.pattern(
                            RegExp(r'^[a-zA-Z0-9_]+$'),
                            'Только латинские буквы, цифры и _',
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          border: const OutlineInputBorder(),
                          helperText: _passwordHint,
                          helperStyle: TextStyle(
                            color: hintOk
                                ? Colors.green.shade700
                                : theme.colorScheme.error,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: RegisterScreen.passwordValidator,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'Повтор пароля',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Повторите пароль';
                          }
                          if (value != _password.text) {
                            return 'Пароли не совпадают';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Зарегистрироваться'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => context.go('/login'),
                        child: const Text('Уже есть аккаунт — войти'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
