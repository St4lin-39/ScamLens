import 'package:flutter/material.dart';
import 'package:scamlens/components/profile_field.dart';
import 'package:scamlens/components/scamlens_header.dart';
import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final Profile profile;

  const HomeScreen({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScamLensHeader(),
              const SizedBox(height: 24),
              const Text(
                'Resumen de tu perfil',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Estos son los datos asociados a tu cuenta de ScamLens.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ProfileField(
                icon: Icons.person_outline,
                label: 'Nombre',
                value: profile.name,
              ),
              const SizedBox(height: 16),
              ProfileField(
                icon: Icons.badge_outlined,
                label: 'Apellido',
                value: profile.lastName,
              ),
              const SizedBox(height: 16),
              ProfileField(
                icon: Icons.mail_outline,
                label: 'Correo electrónico',
                value: profile.email,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
