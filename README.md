# ScamLens 
> Aplicación móvil de ciberseguridad preventiva contra ataques de Phishing, Smishing y QRishing.

---

## Información del Proyecto

- **Asignatura:** Aplicaciones Móviles
- **Sprint:** Sprint 1 — Autenticación, Registro y Perfil de Usuario
- **Integrantes:**
  - Luis Fernando Soto
  - José David Libreros
  - Jhony Bolaños García

---

## Alcance del Sprint 1

En este primer sprint se implementó el flujo base de identidad y acceso de la aplicación:

1. **Onboarding Mínimo y Registro de Usuario:**
   - Captura de datos iniciales del usuario (Nombre, Apellido, Correo electrónico y Contraseña con confirmación).
   - Creación de credenciales cifradas a través de **Supabase Auth** (`auth.users`).
   - Persistencia sincronizada en la tabla `public.user` en PostgreSQL mediante el repositorio de perfiles.

2. **Inicio de Sesión (Login):**
   - Validación segura de credenciales mediante correo y contraseña.
   - Manejo de estados de carga (`loading`), éxito (`success`) y fallo (`failure`) con mensajes de error visuales.

3. **Pantalla de Resumen del Perfil (Home / Profile Summary):**
   - Presentación de los datos del usuario autenticado (Nombre completo, correo, fecha de vinculación y estado del escudo activo).
   - Avatar dinámico generado a partir de la inicial del usuario con la paleta de identidad visual de ScamLens.
   - Cierre de sesión seguro (`SignOutUseCase`) que destruye la sesión y redirige a la pantalla de acceso.

---

## Arquitectura del Software

El proyecto implementa **Clean Architecture** estructurada por capas y características (*feature-based*), garantizando desacoplamiento, mantenibilidad y escalabilidad para los próximos sprints:

```text
lib/
├── components/                  # Widgets visuales reutilizables
│   ├── error_message.dart       # Banner de notificación de errores
│   ├── primary_button.dart      # Botón con degradado cian/menta y spinner
│   ├── profile_field.dart       # Tarjeta de lectura de atributos de perfil
│   └── scamlens_header.dart     # Cabecera con isotipo y estado del escudo
├── features/
│   ├── auth/                    # Capa central de autenticación y perfil
│   │   ├── domain/              # Reglas de negocio puras (independientes del framework)
│   │   │   ├── entities/        # Entidades del dominio (AuthUser, Profile)
│   │   │   ├── repositories/    # Interfaces / Contratos de repositorios
│   │   │   └── usescases/       # Casos de uso (Login, Register, SignOut)
│   │   └── data/                # Implementación técnica y acceso a datos
│   │       ├── datasources/     # Comunicación con Supabase Client
│   │       ├── models/          # Modelos de serialización JSON (ProfileModel)
│   │       └── repositories/    # Implementación concreta de los repositorios
│   ├── login/                   # Módulo de Inicio de Sesión
│   │   └── ui/
│   │       ├── bloc/            # LoginBloc (Eventos, Estados, Lógica)
│   │       └── screens/         # LoginScreen (Formulario y validación)
│   ├── register/                # Módulo de Registro
│   │   └── ui/
│   │       ├── bloc/            # RegisterBloc (Eventos, Estados, Lógica)
│   │       └── screens/         # RegisterScreen (Formulario de alta)
│   ├── home/                    # Módulo de Resumen del Usuario
│   │   └── ui/
│   │       ├── bloc/            # ProfileBloc (Carga, Pull-to-refresh y Logout)
│   │       └── home_screen.dart # Pantalla de resumen del perfil y logout
├── theme/
│   └── app_theme.dart           # Paleta de colores dark mode y tipografía
└── main.dart                    # Inicialización de Supabase y árbol raíz
```

### Gestión de Estado (BLoC Pattern)
Se utilizó la librería oficial `flutter_bloc`:
- **`LoginBloc`:** Escucha el evento `LoginSubmitted`, emite el estado `LoginStatus.loading`, consume `LoginUseCase` y transiciona a `LoginStatus.success` o `LoginStatus.failure`.
- **`RegisterBloc`:** Escucha `OnRegisterSubmittedEvent`, valida contraseñas, consume `RegisterUseCase` y emite `RegisterSuccessState` con el perfil creado.
- **`ProfileBloc`:** Gestiona el ciclo de vida de la pantalla de resumen, permitiendo inicialización inmediata, recarga manual de datos con `LoadProfileEvent` (*Pull-to-Refresh*), y cierre de sesión con `SignOutRequestedEvent`.
- **Inyección de Dependencias:** Gestión mediante `MultiRepositoryProvider` y `MultiBlocProvider` en el punto de entrada de la aplicación.

---

## Modelo de Base de Datos (Supabase / PostgreSQL)

Las tablas correspondientes a este sprint se encuentran versionadas bajo la carpeta `supabase/migrations/`:

### 1. Tabla `public.user` (Perfil)
Almacena la identidad de los usuarios registrados, vinculada por clave foránea a `auth.users`:
- `id` (UUID, Primary Key, referencias a `auth.users(id) ON DELETE CASCADE`)
- `name` (VARCHAR(255), NOT NULL)
- `last_name` (VARCHAR(255), NOT NULL)
- `email` (VARCHAR(255), UNIQUE, NOT NULL)
- `active` (BOOLEAN, DEFAULT TRUE)
- `created_in` (TIMESTAMP WITH TIME ZONE, NOT NULL)

### 2. Tabla `public.device` (Dispositivos)
Registra los dispositivos móviles vinculados al usuario:
- `id` (UUID, Primary Key, `gen_random_uuid()`)
- `user_id` (UUID, FK a `public.user(id)`, nulable para soportar modo invitado)
- `uuid_device` (VARCHAR(255), UNIQUE, NOT NULL)
- `model_device` (VARCHAR(255), NOT NULL)
- `operating_system` (VARCHAR(255), NOT NULL)
- `version_os` (VARCHAR(255), NOT NULL)
- `token_push` (TEXT, nulable)
- `last_access` (TIMESTAMP WITH TIME ZONE, NOT NULL)

### 3. Seguridad a nivel de filas (Row Level Security - RLS)
- Políticas activas en `user` para que cada usuario autenticado solo pueda consultar (`SELECT`) y actualizar (`UPDATE`) su propio registro (`auth.uid() = id`).
- Políticas en `device` para limitar la gestión de dispositivos al propietario de la sesión.

---

## Requisitos y Ejecución Local

### Prerrequisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión 3.13 o superior)
- Dart SDK
- Navegador Google Chrome, Firefox, emulador Android o dispositivo físico.

### Pasos para ejecutar:

1. **Clonar el repositorio:**
   ```bash
   git clone <url-del-repositorio>
   cd scamlens
   ```

2. **Instalar dependencias de Flutter:**
   ```bash
   flutter pub get
   ```

3. **Verificar que no existan errores estáticos:**
   ```bash
   flutter analyze
   ```

4. **Ejecutar la aplicación:**
   - **En Navegador Web (servidor local):**
     ```bash
     flutter run -d web-server --web-port 8080
     ```
     (Abrir `http://localhost:8080` en cualquier navegador).
   - **En Google Chrome:**
     ```bash
     flutter run -d chrome
     ```
   - **En Celular / Emulador Android:**
     ```bash
     flutter run -d <device_id>
     ```

---

## Identidad Visual
El diseño sigue la guía de estilos establecida para ScamLens:
- **Background principal:** Azul nocturno de ciberseguridad (`#080D1A`).
- **Superficie de tarjetas:** Azul marino profundo (`#111827`) con bordes en `#1E293B`.
- **Acentos:** Degradado cian (`#00D2FF`) a verde menta (`#00E5A3`).
- **Semáforo de riesgo:** Verde protegido (`#10B981`), Amarillo advertencia (`#F59E0B`) y Rojo peligro (`#EF4444`).
