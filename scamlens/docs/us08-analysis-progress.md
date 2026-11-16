# US-08, etapa 3: progreso real QR y SMS

## Modelo y flujo

`shared/analysis_progress/domain/analysis_progress.dart` define eventos tipados
con etapa, estado, motivo opcional e índice/total de enlaces únicos.
El callback `onProgress` es opcional. Domain no importa Flutter ni BLoC y los
observadores no pueden alterar el resultado: sus excepciones se aíslan.

- `ProcessUrlUseCase`: inicia reconocimiento/normalización antes de ejecutarlos;
  termina la etapa según el resultado real. Solo inicia expansión si el enlace
  es un acortador reconocido. Envuelve la llamada existente al detector de
  marcas y comunica disponibilidad del catálogo o fallo.
- `HttpUrlExpander` y el transporte seguro no cambian. Se interpretan sus
  resultados tipados, sin nuevas solicitudes ni llamadas para medir progreso.
- `DetectBrandImpersonationUseCase` no cambia en esta etapa: su llamada y su
  resultado existente definen los límites de la comprobación de marca.
- `EvaluateUrlRiskUseCase` notifica inicio/fin/error alrededor de su algoritmo
  existente. No cambia la política local-v1. Completar el cálculo de riesgo
  significa que se calculó el resultado, no que el enlace sea seguro.
- `AnalyzeSmsUseCase` notifica extracción, calcula el total de URLs únicas una
  sola vez, contextualiza los eventos de cada URL y notifica preparación del
  resultado final. No vuelve a procesar ni evaluar las apariciones repetidas.
- QR notifica preparación cuando el BLoC construye su estado de éxito a partir
  del procesamiento y la evaluación ya terminados.

`AnalysisJob<T>` pertenece a Presentation y conserva un Future y una instantánea
inmutable del progreso. Los BLoC publican esa instantánea mediante sus estados
existentes de carga, éxito y error. Las pantallas solo presentan los datos.

## Estados y alcance

| Caso | Presentación |
| --- | --- |
| Operación iniciada | En curso, icono de espera |
| Operación terminada normalmente | Completada, icono de verificación |
| Comprobación de marca no aplicable/no configurada | Omitida, con motivo |
| Expansión no solicitada | No se crea esa etapa |
| Expansión fallida, timeout, bloqueo o cancelación | Fallida, con motivo |
| Transporte unsupportedPlatform | No disponible, nunca Completada |
| Catálogo vencido, desconocido o no disponible | No disponible, con motivo |

`noRedirect` completa la comprobación HTTP, pero no confirma un destino final;
la incertidumbre del semáforo existente permanece intacta. Una marca no
aplicable se omite aunque se haya iniciado la extracción del dominio.

`AnalysisProgressView` muestra el avance actual con texto e iconos, sin barras
ni porcentajes. En SMS indica «Enlace único N de M» y muestra las etapas del
enlace actual. Al terminar conserva un historial desplegable «Etapas del
análisis», incluyendo fallos y omisiones. En plataforma no compatible muestra
además el aviso explícito de comprobación no disponible.

No hay temporizadores de presentación, demoras mínimas ni nuevas esperas.
Las etapas síncronas pueden terminar antes de dibujarse un fotograma; el
resultado aparece inmediatamente y el historial conserva las observaciones.

## Solicitudes simultáneas y cierre

- Cada solicitud de Presentation tiene una revisión. Solo la revisión vigente
  puede publicar progreso, éxito o error y solo mientras su Emitter siga activo.
- QR conserva la protección frente a lecturas repetidas de cámara durante el
  análisis/resultado. Reset permite iniciar otro análisis antes de que termine
  el anterior. Los resultados y eventos viejos no sustituyen al nuevo.
- SMS conserva solicitudes simultáneas y reutilización A → B → A y Reset → A.
  Al reanudar un trabajo pendiente se cambia su observador y se reproduce su
  instantánea actual; no se repite el trabajo.
- QR también reutiliza un trabajo idéntico que siga pendiente tras Reset.
- `close()` invalida las revisiones, desconecta observadores y libera los mapas.
  No se emite progreso después de completar el manejador o cerrar el BLoC.
  Las respuestas tardías de permisos de cámara también comprueban la revisión.

## Validación y limitaciones

Se añadieron pruebas de eventos, secuencia y contadores, SMS sin enlaces/uno/
varios/repetidos, errores de expansión, transporte de navegador no compatible,
reanudación, reset y cierre. Los widgets prueban estados textuales e iconos,
avance real pendiente y conservación de los semáforos individuales.

La suite completa termina con 612 pruebas aprobadas y el analizador sin
incidencias. La comprobación de navegador usa `UnsupportedExpansionHttpSession`
real inyectada; no constituye una ejecución manual en Chrome.

No se implementa cancelación física nueva de HTTP o consultas Supabase al salir:
se descartan sus emisiones tardías y se conservan los límites de transporte
existentes. La aplicación no conoce progreso por bytes, saltos individuales ni
porcentaje interno de Supabase. La granularidad es por operación existente.
Se conservan las limitaciones de seguridad del motor local y el catálogo.
