import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/components/error_message.dart';
import 'package:scamlens/components/primary_button.dart';
import 'package:scamlens/components/profile_field.dart';
import 'package:scamlens/components/scamlens_header.dart';
import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/features/auth/domain/usescases/get_profile_usecase.dart';
import 'package:scamlens/features/auth/domain/usescases/sign_out_usecase.dart';
import 'package:scamlens/features/home/ui/bloc/profile_bloc.dart';
import 'package:scamlens/features/login/ui/screens/login_screen.dart';
import 'package:scamlens/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final Profile? initialProfile;

  const HomeScreen({super.key, Profile? initialProfile, Profile? profile})
      : initialProfile = initialProfile ?? profile;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = ProfileBloc(
          getProfileUseCase: context.read<GetProfileUseCase>(),
          signOutUseCase: context.read<SignOutUseCase>(),
          initialProfile: initialProfile,
        );
        if (initialProfile == null) {
          bloc.add(LoadProfileEvent());
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
      appBar: AppBar(
        title: const Text('Resumen del Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              context.read<ProfileBloc>().add(SignOutRequestedEvent());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocListener<ProfileBloc, ProfileState>(
          listener: (context, state) {
            if (state is ProfileUnauthenticatedState) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
          child: BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, state) {
              if (state is ProfileLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                );
              }

              if (state is ProfileErrorState) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ErrorMessage(message: state.errorMessage),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Reintentar',
                        onPressed: () {
                          context.read<ProfileBloc>().add(LoadProfileEvent());
                        },
                      ),
                    ],
                  ),
                );
              }

              if (state is ProfileLoadedState) {
                final profile = state.profile;
                final initial = profile.name.isNotEmpty
                    ? profile.name[0].toUpperCase()
                    : 'S';
                final formattedDate =
                    profile.createdIn.toIso8601String().split('T').first;

                return RefreshIndicator(
                  color: AppColors.accentCyan,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    context.read<ProfileBloc>().add(LoadProfileEvent());
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                          profile.fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 28),
                        ProfileField(
                          icon: Icons.person_outline,
                          label: 'Nombre',
                          value: profile.name,
                        ),
                        const SizedBox(height: 12),
                        ProfileField(
                          icon: Icons.badge_outlined,
                          label: 'Apellido',
                          value: profile.lastName,
                        ),
                        const SizedBox(height: 12),
                        ProfileField(
                          icon: Icons.mail_outline,
                          label: 'Correo electrónico',
                          value: profile.email,
                        ),
                        const SizedBox(height: 12),
                        ProfileField(
                          icon: Icons.verified_user_outlined,
                          label: 'Estado del escudo',
                          value: profile.active
                              ? 'Activo • Protegido'
                              : 'Inactivo',
                        ),
                        const SizedBox(height: 12),
                        ProfileField(
                          icon: Icons.calendar_today_outlined,
                          label: 'Miembro desde',
                          value: formattedDate,
                        ),
                        const SizedBox(height: 28),
                        PrimaryButton(
                          label: 'Cerrar sesión',
                          onPressed: () {
                            context
                                .read<ProfileBloc>()
                                .add(SignOutRequestedEvent());
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        currentIndex: 2,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Escáner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Mensajes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            label: 'Comunidad / Perfil',
          ),
        ],
      ),
    );
  }
}
