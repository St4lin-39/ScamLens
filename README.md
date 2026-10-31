# ScamLens

> Aplicación móvil de ciberseguridad preventiva contra ataques de Phishing, Smishing y QRishing.

---

## Guía rápida de navegación — Sprint 1

Este Sprint implementa el flujo inicial de autenticación y perfil de usuario de ScamLens. Para probarlo, la aplicación puede recorrerse de la siguiente manera:

```text
Inicio de la aplicación
        │
        ▼
Inicio de Sesión
        │
        ├── ¿No tienes una cuenta?
        │           │
        │           ▼
        │       Registro
        │           │
        │           ▼
        │    Resumen del Perfil
        │
        └── Usuario registrado
                    │
                    ▼
             Iniciar Sesión
                    │
                    ▼
            Resumen del Perfil
                    │
                    ▼
              Cerrar Sesión
                    │
                    ▼
             Inicio de Sesión
```

### Flujo recomendado para probar la aplicación

1. Al iniciar ScamLens se mostrará la pantalla de **Inicio de Sesión**.
2. Si aún no se tiene una cuenta, seleccionar la opción para **registrarse**.
3. Completar el formulario con:
   - Nombre.
   - Apellido.
   - Correo electrónico.
   - Contraseña.
   - Confirmación de contraseña.
4. Crear la cuenta.
5. Al finalizar correctamente el registro, la aplicación dirigirá automáticamente al **Resumen del Perfil**.
6. Verificar que la información mostrada corresponda al usuario registrado.
7. Seleccionar **Cerrar sesión** para regresar a la pantalla de Inicio de Sesión.
8. Ingresar nuevamente utilizando el **correo electrónico y contraseña** registrados.
9. Al autenticarse correctamente, la aplicación recuperará el perfil y mostrará nuevamente el **Resumen del Perfil**.

De esta manera puede comprobarse el flujo completo desarrollado durante el Sprint 1:

**Registro → Perfil → Cerrar sesión → Inicio de sesión → Perfil**

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
   - Creación de credenciales mediante **Supabase Auth** (`auth.users`).
   - Persistencia sincronizada del perfil en la tabla `public.user` en PostgreSQL mediante el repositorio de perfiles.

2. **Inicio de Sesión (Login):**
   - Validación de credenciales mediante correo electrónico y contraseña.
   - Manejo de estados de carga (`loading`), éxito (`success`) y fallo (`failure`) con mensajes de error visuales.
   - Recuperación del perfil asociado al usuario autenticado.

3. **Pantalla de Resumen del Perfil (Home / Profile Summary):**
   - Presentación de los datos asociados al usuario autenticado.
   - Visualización de la información del perfil dentro de la interfaz de ScamLens.
   - Cierre de sesión seguro (`SignOutUseCase`) y redirección a la pantalla de acceso.

---

## Arquitectura del Software

El proyecto implementa **Clean Architecture** estructurada por capas y características (*feature-based*), buscando mantener separadas las reglas de negocio, el acceso a datos y la interfaz de usuario.

```text
lib/
├── components/                  # Widgets visuales reutilizables
│   ├── error_message.dart       # Presentación de mensajes de error
│   ├── primary_button.dart      # Botón principal reutilizable
│   ├── profile_field.dart       # Presentación de atributos del perfil
│   └── scamlens_header.dart     # Cabecera visual de ScamLens
│
├── features/
│   ├── auth/                    # Autenticación y perfil
│   │   ├── domain/              # Reglas de negocio independientes
│   │   │   ├── entities/        # Entidades del dominio (AuthUser, Profile)
│   │   │   ├── repositories/    # Contratos de repositorios
│   │   │   └── usescases/       # Casos de uso (Login, Register, SignOut)
│   │   │
│   │   └── data/                # Implementación técnica
│   │       ├── datasources/     # Comunicación con Supabase
│   │       ├── models/          # Transformación de datos
│   │       └── repositories/    # Implementaciones de repositorios
│   │
│   ├── login/                   # Módulo de Inicio de Sesión
│   │   └── ui/
│   │       ├── bloc/            # Estado y eventos del Login
│   │       └── screens/         # Interfaz de Inicio de Sesión
│   │
│   ├── register/                # Módulo de Registro
│   │   └── ui/
│   │       ├── bloc/            # Estado y eventos del Registro
│   │       └── screens/         # Interfaz de Registro
│   │
│   └── home/                    # Resumen del Perfil
│       └── ui/
│           ├── bloc/            # Gestión del estado del perfil
│           └── home_screen.dart # Pantalla principal del usuario
│
├── theme/
│   └── app_theme.dart           # Paleta de colores y estilos
│
└── main.dart                    # Inicialización y composición de dependencias
```

### Gestión de Estado (BLoC Pattern)

Se utilizó la librería `flutter_bloc` para separar la lógica de presentación de las interfaces:

- **`LoginBloc`:** Gestiona el envío de credenciales, los estados de carga, éxito y error durante el inicio de sesión.
- **`RegisterBloc`:** Gestiona el formulario de registro y la creación del usuario y su perfil.
- **`ProfileBloc`:** Gestiona el estado relacionado con la pantalla de perfil.
- **Inyección de dependencias:** Los repositorios, casos de uso y BLoCs son construidos e inyectados desde el punto de entrada de la aplicación.

### Flujo de autenticación

El inicio de sesión mantiene separada la autenticación del perfil de la aplicación:

```text
LoginScreen
     │
     ▼
LoginBloc
     │
     ▼
LoginUseCase
     │
     ├── AuthRepository.signIn()
     │          │
     │          ▼
     │       AuthUser
     │
     └── ProfileRepository.getProfile(id)
                │
                ▼
             Profile
                │
                ▼
            HomeScreen
```

Durante el registro, primero se crea la identidad de autenticación y posteriormente el perfil asociado:

```text
RegisterScreen
      │
      ▼
RegisterBloc
      │
      ▼
RegisterUseCase
      │
      ├── AuthRepository.signUp()
      │          │
      │          ▼
      │       AuthUser
      │
      └── ProfileRepository.createProfile()
                 │
                 ▼
              Profile
                 │
                 ▼
             HomeScreen
```

---

## Modelo de Base de Datos (Supabase / PostgreSQL)

Las estructuras correspondientes al Sprint 1 se encuentran versionadas bajo la carpeta `supabase/migrations/`.

### 1. Tabla `public.user` — Perfil

Almacena los datos del perfil de los usuarios registrados y se encuentra vinculada con `auth.users`.

- `id` — UUID, Primary Key y referencia a `auth.users(id)`.
- `name` — VARCHAR(255), NOT NULL.
- `last_name` — VARCHAR(255), NOT NULL.
- `email` — VARCHAR(255), UNIQUE, NOT NULL.
- `active` — BOOLEAN, DEFAULT TRUE.
- `created_in` — TIMESTAMP WITH TIME ZONE, NOT NULL.

### 2. Tabla `public.device` — Dispositivos

Estructura destinada al registro de dispositivos vinculados a los usuarios:

- `id` — UUID, Primary Key.
- `user_id` — UUID, referencia a `public.user(id)`.
- `uuid_device` — VARCHAR(255), UNIQUE, NOT NULL.
- `model_device` — VARCHAR(255), NOT NULL.
- `operating_system` — VARCHAR(255), NOT NULL.
- `version_os` — VARCHAR(255), NOT NULL.
- `token_push` — TEXT.
- `last_access` — TIMESTAMP WITH TIME ZONE, NOT NULL.

### 3. Seguridad a nivel de filas (Row Level Security — RLS)

La base de datos utiliza políticas **Row Level Security (RLS)** para restringir el acceso a la información de acuerdo con el usuario autenticado.

En `public.user`, las políticas permiten que cada usuario trabaje únicamente con el perfil asociado a su propia identidad de autenticación utilizando `auth.uid()`.

---

## Requisitos y Ejecución Local

### Prerrequisitos

- Flutter SDK.
- Dart SDK.
- Google Chrome para ejecución web, o un dispositivo/emulador Android correctamente configurado.
- Git para clonar el repositorio.

### Pasos para ejecutar

1. **Clonar el repositorio:**

```bash
git clone <url-del-repositorio>
```

2. **Ingresar al proyecto Flutter:**

```bash
cd ScamLens/scamlens
```

3. **Instalar las dependencias:**

```bash
flutter pub get
```

4. **Verificar el proyecto:**

```bash
flutter analyze
```

5. **Consultar los dispositivos disponibles:**

```bash
flutter devices
```

6. **Ejecutar en Google Chrome:**

```bash
flutter run -d chrome
```

7. **O ejecutar en un dispositivo/emulador Android:**

```bash
flutter run -d <device_id>
```

Una vez iniciada la aplicación, seguir la **Guía rápida de navegación — Sprint 1** ubicada al comienzo de este documento.

---

## Identidad Visual

El diseño de ScamLens utiliza una interfaz oscura orientada a la temática de ciberseguridad:

- **Background principal:** Azul nocturno (`#080D1A`).
- **Superficie de tarjetas:** Azul marino profundo (`#111827`).
- **Bordes:** `#1E293B`.
- **Acentos:** Cian (`#00D2FF`) y verde menta (`#00E5A3`).
- **Estados de riesgo:** Verde (`#10B981`), amarillo (`#F59E0B`) y rojo (`#EF4444`).

---

## Sprint 1

El Sprint 1 establece el flujo inicial de identidad de ScamLens, permitiendo:

- Crear una cuenta.
- Almacenar el perfil asociado.
- Iniciar sesión con credenciales existentes.
- Recuperar y visualizar la información del perfil.
- Cerrar la sesión activa.

El flujo funcional entregado es:

```text
Registro
   ↓
Perfil
   ↓
Cerrar sesión
   ↓
Inicio de sesión
   ↓
Perfil
```