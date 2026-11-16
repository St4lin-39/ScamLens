# US-08, etapa 2: integración QR/SMS y semáforo

El progreso posterior de la etapa 3 se documenta en `us08-analysis-progress.md`.
Las referencias a carga pendiente describen el estado al cerrar la etapa 2.

## Flujo y dependencias

`main.dart` registra un `EvaluateUrlRiskUseCase` compartido. Lo inyecta en
`AnalyzeSmsUseCase`; `HomeScreen` lo inyecta en `ScannerBloc`.
Los parámetros opcionales conservan los constructores existentes de pruebas.

- QR: `ScannerBloc` ejecuta `ProcessUrlUseCase` una vez y pasa el mismo objeto
  al evaluador. `ScannerSuccessState` conserva `result` y añade `riskEvaluation`.
  El contenido QR que no sea URL conserva su presentación de texto.
- SMS: `AnalyzeSmsUseCase` conserva la extracción y el procesamiento existentes.
  Un mapa por cadena de URL reutiliza también su evaluación local.
  `SmsAnalysisResult.riskEvaluations[index]` corresponde a `urls[index]`;
  ambas listas son inmutables y se valida que tengan la misma longitud.
  Las apariciones repetidas conservan el orden y comparten los mismos objetos.
- `SmishingBloc` no cambia: sus estados, revisión de solicitudes y trabajos
  pendientes transportan el resultado enriquecido de Domain.

El evaluador no realiza I/O. La integración no repite normalización, expansión,
Levenshtein ni consultas de marcas. Se conserva la caché existente del catálogo.
Resultados construidos por productores antiguos sin evaluación reciben amarillo
parcial mediante `RiskEvaluationResult.notEvaluated`; no se fabrican resultados
verdes ni se ejecutan heurísticas desde las entidades o widgets.

## Presentación

`components/risk_traffic_light.dart` es compartido por ambas pantallas.
Sustituye el banner de marca dentro de esos flujos; el componente anterior sigue
disponible sin cambios. Se conservan los detalles de expansión existentes.

| Nivel | Presentación |
| --- | --- |
| Verde | Icono de verificación, texto «Dominio oficial reconocido», explicación que no garantiza seguridad absoluta |
| Amarillo | Icono de advertencia, «Precaución», estado parcial cuando hay incertidumbre |
| Rojo | Icono de protección con alerta, «Posible suplantación», aviso de apertura bloqueada |

El desplegable «Detalles de la evaluación» está disponible en todos los niveles:
muestra las justificaciones reales, la URL de cada evidencia, la URL evaluada
cuando existe, la completitud local y las limitaciones. No muestra destinos solo
anunciados como confirmados. Una evaluación nueva reinicia su desplegable cerrado.

Las pantallas actuales no ofrecen navegación externa. El componente permite
un callback opcional de apertura para consumidores que lo necesiten: si se
proporciona, el botón está deshabilitado para rojo y para destino no evaluado.
QR y SMS no proporcionan ese callback ni incorporan un lanzador de URLs.
No se añade un botón de reporte ni se simula un envío inexistente.

## Validación

`test/us08/` contiene fixtures sin red y pruebas de BLoC/integración y widgets.
Usan el procesamiento, detector y evaluador reales con catálogo y expansor
controlados. Cubren los tres colores, catálogo no disponible, acortadores sin
destino confirmado, evidencias desplegables, navegación bloqueada y conservación
de resultados individuales. Los contadores comprueban la ausencia de trabajo
duplicado para URLs repetidas.

## Limitaciones y etapa 3

Se conserva la política local-v1 y sus limitaciones documentadas en
`us08-local-risk.md`: no hay reputación, RDAP, inspección del sitio ni garantía
de seguridad absoluta. El texto SMS no se analiza semánticamente. No se ofrece
un veredicto global para todos los enlaces del mensaje; cada uno conserva el suyo.

Los indicadores de carga anteriores permanecen sin cambios. La etapa 3 deberá
incorporar eventos reales de etapas desde Domain y traducirlos a Presentation,
respetando deduplicación, revisiones y resultados tardíos. No hay porcentajes
simulados ni eventos de progreso añadidos en esta etapa.
