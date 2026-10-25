import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/components/error_message.dart';
import 'package:scamlens/components/primary_button.dart';
import 'package:scamlens/components/profile_field.dart';
import 'package:scamlens/components/scamlens_header.dart';
import 'package:scamlens/features/auth/domain/entities/user_entity.dart';
import 'package:scamlens/features/auth/domain/repositories/auth_repository.dart';
import 'package:scamlens/features/auth/domain/usescases/get_profile_usecase.dart';
import 'package:scamlens/features/auth/domain/usescases/login_usecase.dart';
import 'package:scamlens/features/auth/domain/usescases/sign_out_usecase.dart';
import 'package:scamlens/features/home/bloc/profile_bloc.dart';
import 'package:scamlens/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final UserEntity? initialUser;
  const HomeScreen({super.key, this.initialUser});
  @override
  Widget build(BuildContext context) {
    final authRepository = context.read<AuthRepository>();

    return BlocProvider(
      create: (_) {
        final bloc = ProfileBloc(
          getProfileUseCase: GetProfileUseCase(authRepository),
          signOutUseCase: SignOutUseCase(authRepository),
        );
        if (initialUser == null) {
          bloc.add(OnLoadProfileEvent());
        }
        return bloc;
      },
      child: const _HomeScreenView(),
    );
  }
}

class _HomeScreenView extends StatelessWidget {
  const _HomeScreenView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen del perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BlocListener<ProfileBloc, ProfileState>(
            listener: (context, state) {
              if (state is ProfileSignedOutState) {
                final authRepository = context.read<AuthRepository>();

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) =>
                          LoginBloc(loginUseCase: LoginUseCase(authRepository)),
                      child: LoginScreen(),
                    ),
                  ),
                  (route) => false,
                );
              }
            },
            child: BlocBuilder<ProfileBloc, ProfileState>(
              builder: (context, state) {
                if (state is ProfileLoadingState) {
                  return const SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentCyan,
                      ),
                    ),
                  );
                }

                if (state is ProfileErrorState) {
                  return Column(
                    children: [
                      ErrorMessage(message: state.errorMessage),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Reintentar',
                        onPressed: () => context.read<ProfileBloc>().add(
                          OnLoadProfileEvent(),
                        ),
                      ),
                    ],
                  );
                }

                if (state is ProfileLoadedState) {
                  final user = state.user;
                  final initial = user.name.isNotEmpty
                      ? user.name[0].toUpperCase()
                      : 'S';
                  final formattedDate = user.createdIn
                      .toIso8601String()
                      .split('T')
                      .first;

                  return Column(
                    children: [
                      const ScamLensHeader(showProtectedBadge: true),
                      const SizedBox(height: 28),
                      Container(
                        width: 92,
                        height: 92,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.accentCyan, AppColors.primary],
                          ),
                          border: Border.all(color: AppColors.border, width: 3),
                        ),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: AppColors.buttonText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 28),
                      ProfileField(
                        icon: Icons.person_outline,
                        label: 'Nombre',
                        value: user.name,
                      ),
                      const SizedBox(height: 12),
                      ProfileField(
                        icon: Icons.badge_outlined,
                        label: 'Apellido',
                        value: user.lastName,
                      ),
                      const SizedBox(height: 12),
                      ProfileField(
                        icon: Icons.mail_outline,
                        label: 'Correo electronico',
                        value: user.email,
                      ),
                      const SizedBox(height: 12),
                      ProfileField(
                        icon: Icons.verified_user_outlined,
                        label: 'Estado del escudo',
                        value: user.active ? 'Activo • Protegido' : 'Inactivo',
                      ),
                      const SizedBox(height: 12),
                      ProfileField(
                        icon: Icons.calendar_today_outlined,
                        label: 'Miembro desde',
                        value: formattedDate,
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Cerrar sesion',
                        onPressed: () =>
                            context.read<ProfileBloc>().add(OnSignOutEvent()),
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}
