# Detección sintáctica de enlaces en SMS

`SmsUrlExtractor` conserva el texto de cada enlace, el orden y las apariciones.
`WebUrlRecognizer`, en Domain compartido, valida su sintaxis y permite que
`ProcessUrlUseCase` reconozca también dominios sin esquema. El normalizador y
el flujo existente de expansión se reutilizan sin nuevas peticiones HTTP.

Se admiten HTTP/HTTPS sin distinguir mayúsculas, www, dominios sin esquema,
subdominios, TLD alfabéticos de 2–63 caracteres y TLD punycode, sin catálogo
de dominios o TLD. Las etiquetas DNS admiten letras ASCII, números y guiones.
Se conservan rutas, puertos 1–65535, consultas y fragmentos. IPv4 exige cuatro
octetos decimales entre 0 y 255, sin ceros iniciales; sin esquema necesita una
ruta con contenido. IPv6 entre corchetes conserva el soporte con esquema.

Los correos y los tokens inválidos se rechazan completos; no se buscan dominios
internos en ellos. Los límites impiden extraer sufijos dentro de palabras,
incluidas letras Unicode. `abcwww.example.com` sí es un dominio completo válido;
no se interpreta como el fragmento `www.example.com`.

## Ambigüedades y límites

- `archivo.pdf`, `hola.mundo` y una versión como `v1.release` tienen sintaxis de
  dominio. Pueden ser falsos positivos: no se consulta DNS ni una lista de TLD.
- No se determina existencia, accesibilidad, reputación, marca o riesgo.
- Se retira puntuación final de frase (`.,!?:;`) y cierres sobrantes. Paréntesis
  balanceados y puntuación interna se conservan. Un signo final legítimo puede
  ser indistinguible de puntuación de frase y retirarse.
- Enlaces pegados sin espacios o delimitadores de comillas, por ejemplo
  `a.com,b.com`, no se separan: la coma puede pertenecer a una ruta o consulta.
- No se reconstruyen ofuscaciones: `[.]`, `(.)`, espacios alrededor del punto,
  `hxxp(s)` o sustituciones Unicode. No se admiten dominios Unicode sin punycode,
  hosts de una sola etiqueta, credenciales en la extracción ni otros esquemas.
- El procesamiento compartido conserva la clasificación previa de entradas
  explícitas HTTP/HTTPS o www (incluido `https:relative`); la validación estricta
  de extracción SMS no amplía ese comportamiento heredado.

Las pruebas usan expansores de Domain controlados y `MockClient` en Data;
no requieren peticiones HTTP reales.
