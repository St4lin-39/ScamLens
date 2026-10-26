import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/components/error_message.dart';
import 'package:scamlens/components/primary_button.dart';
import 'package:scamlens/components/scamlens_header.dart';
import 'package:scamlens/features/home/ui/home_screen.dart';
import 'package:scamlens/features/login/ui/bloc/login_bloc.dart';
import 'package:scamlens/features/register/ui/screens/register_screen.dart';
import 'package:scamlens/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _localError = 'Complete todos los campos');
      return;
    }

    setState(() => _localError = null);
    context.read<LoginBloc>().add(
      LoginSubmitted(
        email: email,
        password: password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BlocListener<LoginBloc, LoginState>(
            listener: (context, state) {
              if (state.status == LoginStatus.success && state.profile != null) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(
                      profile: state.profile!,
                    ),
                  ),
                  (route) => false,
                );
              }
            },
            child: BlocBuilder<LoginBloc, LoginState>(
              builder: (context, state) {
                final isLoading = state.status == LoginStatus.loading;
                final blocError = state.status == LoginStatus.failure
                    ? state.errorMessage
                    : null;
                final displayError = _localError ?? blocError;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScamLensHeader(showProtectedBadge: false),
                    const SizedBox(height: 24),
                    const Text(
                      'Bienvenido de nuevo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Inicia sesión para continuar protegiéndote de enlaces y códigos QR sospechosos.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (displayError != null) ...[
                      ErrorMessage(message: displayError),
                      const SizedBox(height: 16),
                    ],
                    PrimaryButton(
                      label: 'Iniciar sesión',
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                if (context.read<LoginBloc>().state.status ==
                                    LoginStatus.loading) {
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                        child: Text(
                          '¿No tienes cuenta? Regístrate',
                          style: TextStyle(
                            color: isLoading
                                ? AppColors.textSecondary
                                : AppColors.accentCyan,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
