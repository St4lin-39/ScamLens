import 'package:flutter/material.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/theme/app_theme.dart';

/// Presentation only. Announced destinations are deliberately not displayed.
class UrlExpansionDetails extends StatelessWidget {
  final UrlExpansionResult? expansion;

  const UrlExpansionDetails({super.key, required this.expansion});

  @override
  Widget build(BuildContext context) {
    final result = expansion;
    if (result == null) return const SizedBox.shrink();
    final message = switch (result.status) {
      UrlExpansionStatus.resolved || UrlExpansionStatus.notAttempted => null,
      UrlExpansionStatus.noRedirect => 'No se detectó una redirección HTTP.',
      UrlExpansionStatus.timeout =>
        'No fue posible completar la comprobación a tiempo.',
      UrlExpansionStatus.failed => 'Ocurrió un error al comprobar el enlace.',
      UrlExpansionStatus.blocked =>
        'La comprobación se bloqueó por una restricción de seguridad de red.',
      UrlExpansionStatus.unsupportedPlatform =>
        'La expansión no está disponible en esta plataforma.',
      UrlExpansionStatus.cancelled => 'La operación fue cancelada.',
    };
    final stateLabel = switch (result.status) {
      UrlExpansionStatus.resolved => 'Destino confirmado mediante HTTP',
      UrlExpansionStatus.noRedirect => 'Sin redirección HTTP',
      UrlExpansionStatus.timeout => 'Tiempo agotado',
      UrlExpansionStatus.failed => 'Error de comprobación',
      UrlExpansionStatus.blocked => 'Bloqueada por política de red',
      UrlExpansionStatus.unsupportedPlatform =>
        'No disponible en esta plataforma',
      UrlExpansionStatus.cancelled => 'Cancelada',
      UrlExpansionStatus.notAttempted => 'Expansión no solicitada',
    };
    const detailStyle = TextStyle(color: AppColors.textSecondary, fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ExpansionTile(
          key: ObjectKey(result),
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          dense: true,
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          title: const Text('Detalles del procesamiento', style: detailStyle),
          children: [
            Text('Estado: $stateLabel', style: detailStyle),
            if (result.status != UrlExpansionStatus.notAttempted &&
                result.status != UrlExpansionStatus.unsupportedPlatform)
              Text(
                'Redirecciones: ${result.redirectCount}',
                style: detailStyle,
              ),
            if (result.lastHttpStatus != null)
              Text('Código HTTP: ${result.lastHttpStatus}', style: detailStyle),
            if (result.failureReason != null)
              Text(
                'Motivo: ${_reason(result.failureReason!)}',
                style: detailStyle,
              ),
          ],
        ),
      ],
    );
  }

  static String _reason(UrlExpansionFailureReason reason) => switch (reason) {
    UrlExpansionFailureReason.unknown => 'No se conoce el motivo.',
    UrlExpansionFailureReason.dns =>
      'No se pudo resolver el nombre del servidor.',
    UrlExpansionFailureReason.connection =>
      'No se pudo establecer la conexión.',
    UrlExpansionFailureReason.tls => 'No se pudo validar la conexión TLS.',
    UrlExpansionFailureReason.httpStatus =>
      'La respuesta del servidor no permitió completar la comprobación.',
    UrlExpansionFailureReason.invalidLocation =>
      'La respuesta no indicó un destino válido.',
    UrlExpansionFailureReason.redirectLoop =>
      'Se detectó un bucle de redirecciones.',
    UrlExpansionFailureReason.redirectLimit =>
      'Se alcanzó el límite de redirecciones.',
    UrlExpansionFailureReason.invalidUrl =>
      'La dirección no tiene un formato admitido.',
    UrlExpansionFailureReason.unsupportedScheme =>
      'El protocolo del destino no está admitido.',
    UrlExpansionFailureReason.forbiddenDestination =>
      'El destino no está permitido por la política de red.',
    UrlExpansionFailureReason.insecureRedirect =>
      'Se rechazó un cambio de HTTPS a HTTP.',
    UrlExpansionFailureReason.securityPolicyUnavailable =>
      'La plataforma no permite aplicar la política de red.',
  };
}
