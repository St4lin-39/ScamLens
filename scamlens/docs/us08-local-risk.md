# US-08, etapa 1: evaluación local de URLs

Este documento describe el núcleo de la etapa 1. La integración posterior con
QR/SMS y el semáforo se documentan en `us08-risk-presentation.md` (etapa 2).

El motor está en `lib/shared/url_risk/domain/`. No realiza I/O ni depende de
Flutter, BLoC o Supabase. No necesita una capa Data propia: consume el
`UrlProcessingResult` existente mediante `EvaluateUrlRiskUseCase.call`.
En la etapa 1 se dejaron pendientes la integración QR/SMS, el semáforo y el progreso.

## Flujo y compatibilidad

1. El consumidor ejecuta el `ProcessUrlUseCase` existente una sola vez.
2. US-07 conserva sus comparaciones y añade al resultado la disponibilidad del
   catálogo y la lista inmutable de marcas activas que ya consultó.
3. El evaluador recibe ese resultado y reutiliza ambas observaciones. No vuelve
   a consultar marcas ni a calcular Levenshtein.
4. Devuelve nivel, evidencias con identificadores tipados estables, explicaciones,
   URL evaluada, motivos de incertidumbre y completitud del perfil local.

`OfficialBrandCatalogReader` amplía opcionalmente el contrato del repositorio.
`getActiveBrands()` conserva su firma, caché, coalescencia y fallback anterior.
La implementación Supabase ahora expone snapshots `available`, `stale` o
`unavailable`. Una consulta exitosa vacía es `available` y produce dominio
desconocido, no verde. Implementaciones antiguas sin metadatos son `unknown`:
pueden seguir participando en US-07, pero no habilitan verde en US-08.
Un resultado de marca nulo también impide verde.

## Política local-v1

Precedencia: rojo > amarillo > verde. Las señales débiles no se suman para
producir rojo. El riesgo y la completitud son dimensiones independientes.

| Condición | Clasificación |
| --- | --- |
| US-07 suspectedImpersonation, distancia 1 y catálogo disponible | Rojo: posible suplantación fuerte |
| Dominio oficial completo como secuencia de etiquetas en subdominio ajeno | Rojo: posible señuelo de identidad |
| Otra sospecha US-07, incluida similitud más distante | Amarillo |
| Nombre de marca de al menos 5 caracteres como etiqueta exacta de subdominio ajeno | Amarillo; puede ser legítimo |
| HTTP explícito, IP, credenciales en autoridad o puerto distinto de 80/443 | Amarillo |
| URL mayor de 2048 caracteres o al menos 4 etiquetas de subdominio | Amarillo; indicios débiles |
| Host internacionalizado o punycode | Amarillo; no se implementa detección de homógrafos |
| Dominio desconocido o marca no aplicable | Amarillo |
| Catálogo vencido/no disponible/desconocido, marca ausente o de otro dominio | Amarillo y parcial, salvo evidencia roja independiente |
| Expansión blocked/timeout/failed/unsupportedPlatform/cancelled o ausente | Amarillo y parcial, salvo evidencia roja independiente |
| Acortador sin verifiedDestination | Amarillo y parcial; evaluatedUrl es null |
| Coincidencia oficial correspondiente al host, catálogo disponible, sin señales ni incertidumbre | Verde local |
| Entrada no URL | Amarillo, notApplicable; evaluatedUrl es null |

Para un enlace ordinario se examina el contenido original, no la URL de
presentación que elimina parámetros. Para un acortador confirmado se examina
`verifiedDestination`. HTTP en la entrada también se conserva aunque el destino
use HTTPS. Nunca se usa `announcedDestination`. Sin destino confirmado no se
aplica el resultado de marca del acortador al destino desconocido.

## Limitaciones de seguridad

- Verde significa dominio oficial reconocido sin señales locales detectadas;
  no garantiza contenido benigno, HTTPS válido, ausencia de malware o seguridad
  absoluta. No se realiza una conexión adicional para otorgar este color.
- `complete` significa completitud de este perfil local, no cobertura de todas
  las amenazas. Un dominio desconocido puede tener análisis local completo y
  seguir amarillo.
- No existen reputación, RDAP, APIs nuevas, nuevas tablas ni dependencias nuevas.
- El catálogo sigue siendo limitado y puede estar hasta 5 minutos en caché
  vigente. Los fallos de renovación identifican explícitamente la caché vencida.
- Se reutiliza el extractor de dominios de US-07, cuya lista de sufijos es
  parcial. No hay PSL completa, IDNA completo ni inspección de páginas o
  redirecciones JavaScript. La expansión solo ocurre en acortadores conocidos.
- Un dominio oficial puede estar comprometido y alojar contenido de terceros.
- Incluso rojo expresa posible suplantación, no confirmación de una amenaza.
  Marcas parecidas y dominios oficiales mencionados por servicios legítimos
  pueden generar falsos positivos; los umbrales requieren calibración futura.
- La señal de etiqueta de marca evita coincidencias por substring y omite
  nombres menores de 5 caracteres para reducir falsos positivos.
- Se confía en que las observaciones recibidas provengan del procesamiento
  existente. Se comprueba coherencia de dominio, pero no se autentican objetos
  fabricados por terceros.
- Los mensajes SMS todavía no se analizan semánticamente: no hay detección de
  urgencia ni solicitudes de credenciales dentro del texto.

## Trabajo posterior previsto al cerrar la etapa 1

Conectar el motor compartido a los flujos QR y SMS, presentar sus razones y
cobertura en un semáforo accesible, y añadir progreso real por etapas con control
de resultados tardíos. Reputación y RDAP requieren una decisión de otro sprint.
