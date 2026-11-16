# ScamLens — Sprint 2

Aplicación de ciberseguridad preventiva para analizar enlaces de mensajes y códigos QR, detectar posibles suplantaciones de marcas y presentar un semáforo de riesgo.

## 1. Instalación y ejecución

**Requisitos:** Git, Flutter SDK, Google Chrome, conexión a Internet y acceso a la configuración de Supabase del proyecto.

```bash
git clone https://github.com/St4lin-39/ScamLens.git
cd ScamLens
git checkout sprint2
cd scamlens
flutter pub get
flutter run -d chrome
```

Para abrir el proyecto en un editor, abre la carpeta `ScamLens/scamlens` en VS Code o Android Studio.

La demostración de este sprint se realiza en **Chrome**. La ejecución y la expansión HTTP en Android no se han validado manualmente para esta entrega.

## 2. Registro e inicio de sesión

1. Al abrir la aplicación, inicia sesión con una cuenta existente o selecciona la opción de registro.
2. Para registrarte, ingresa nombre, apellido, correo electrónico, contraseña y confirmación. La contraseña debe cumplir las condiciones indicadas por el formulario.
3. Accede con el correo y la contraseña registrados. **Se requiere una cuenta para utilizar los analizadores.**
4. Desde la pantalla principal puedes acceder a la lectura de QR, la sección de **Mensajes** y el perfil; también puedes cerrar sesión.

## 3. Analizar enlaces de mensajes

1. En la pantalla principal, entra a **Mensajes**.
2. Pega un SMS con una o varias direcciones web y ejecuta el análisis.
3. Revisa los enlaces extraídos, la URL normalizada, el semáforo (**verde, amarillo o rojo**), las evidencias y las etapas del procesamiento.

### Dominios oficiales del catálogo de Supabase

Estos son los 12 dominios registrados como marcas oficiales y activos en el catálogo:

| Marca | Dominio oficial |
|---|---|
| Mercado Libre Colombia | `mercadolibre.com.co` |
| DIAN | `dian.gov.co` |
| Microsoft | `microsoft.com` |
| Nequi | `nequi.com.co` |
| Servientrega | `servientrega.com` |
| Banco de Bogotá | `bancodebogota.com` |
| Davivienda | `davivienda.com` |
| Bancolombia | `bancolombia.com` |
| Inter Rapidísimo | `interrapidisimo.com` |
| BBVA Colombia | `bbva.com.co` |
| Google | `google.com` |
| DaviPlata | `daviplata.com` |

### Mensajes para probar el semáforo

** Verde — Dominio oficial reconocido**

```text
Consulta los servicios de Microsoft en https://www.microsoft.com
```

```text
Consulta información oficial de la DIAN en https://www.dian.gov.co
```

** Amarillo — Dominio no reconocido en el catálogo**

```text
Consulta este sitio de ejemplo: https://ejemplo-desconocido-2026.com
```

** Rojo — Posible suplantación de una marca**

```text
Verifica tu cuenta en https://goog1e.com
```

```text
Consulta tu cuenta en https://micros0ft.com
```

Los ejemplos rojos son cadenas de prueba: no abras esos dominios.

La clasificación depende del catálogo vigente y de las evidencias obtenidas. Un dominio oficial puede mostrarse en verde si no hay señales adicionales de riesgo ni incertidumbre crítica. **El verde no garantiza seguridad absoluta.**

## 4. Escanear códigos QR

1. Abre [QR Code Monkey](https://www.qrcode-monkey.com/es/) y selecciona **URL**.
2. Introduce una de las direcciones de la tabla, crea un **QR estático** y descárgalo o muéstralo en otra pantalla.
3. En ScamLens, abre la opción de escaneo QR y utiliza la cámara para leerlo.
4. Comprueba la URL detectada, el semáforo, los detalles de la evaluación y las etapas del análisis.

| Prueba | URL para generar el QR | Resultado esperado |
|---|---|---|
|  Verde | `https://www.microsoft.com` | Verde si el catálogo está vigente y no hay señales de riesgo |
|  Amarillo | `https://ejemplo-desconocido-2026.com` | Amarillo por dominio desconocido |
|  Rojo | `https://goog1e.com` | Rojo si se detecta la suplantación de Google |

No es necesario abrir los enlaces para analizarlos.

## 5. Alcance y limitaciones

El Sprint 2 incluye lectura de QR, extracción de enlaces de mensajes, normalización de URLs, intento de expansión de acortadores, detección de suplantación de marcas mediante Levenshtein, heurísticas locales, semáforo de riesgo y seguimiento de las etapas del análisis.

El análisis es **preventivo y basado en evidencias locales**: no inspecciona el contenido de los sitios ni consulta servicios externos de reputación.

La expansión HTTP segura de acortadores no está disponible en Chrome. La incorporación de verificaciones externas sería una mejora adicional; los flujos comprometidos para este sprint están implementados.