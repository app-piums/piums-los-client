# Piums iOS — App Cliente

App móvil nativa para iOS que permite a los clientes descubrir, buscar y contratar artistas callejeros en Latinoamérica.

> Parte del ecosistema **Piums** — marketplace de artistas.

---

## Stack tecnológico

| Tecnología | Versión |
|---|---|
| Lenguaje | Swift 5.9+ |
| UI Framework | SwiftUI |
| Arquitectura | MVVM + Clean Architecture |
| iOS mínimo | iOS 17 |
| Xcode | 16+ |
| Networking | URLSession nativo + `async/await` |
| Autenticación | JWT (Keychain) + Firebase Auth |
| Pagos | Stripe iOS SDK |
| Push Notifications | APNs + Firebase Cloud Messaging |

---

## Estructura del proyecto

```
PiumsCliente/
├── App/
│   ├── PiumsClienteApp.swift     ← @main entry point
│   ├── AppDelegate.swift         ← APNs setup
│   ├── RootView.swift            ← Auth gate (login vs tabs)
│   └── MainTabView.swift         ← 5 tabs principales
│
├── Core/
│   ├── Network/
│   │   ├── APIClient.swift       ← async/await + retry 401
│   │   ├── APIEndpoint.swift     ← todos los endpoints del backend
│   │   └── AppError.swift        ← errores tipados
│   ├── Auth/
│   │   ├── AuthManager.swift     ← @Observable, singleton
│   │   └── TokenStorage.swift    ← Keychain (nunca UserDefaults)
│   ├── Models/
│   │   └── Models.swift          ← Artist, Booking, Review, etc.
│   └── Extensions/
│       ├── Color+Piums.swift     ← piumsOrange, piumsDark
│       └── JSONCoder+Piums.swift ← snake_case + ISO8601
│
├── Features/
│   ├── Auth/          ← Login, Register, ForgotPassword
│   ├── Home/          ← Lista artistas + chips por categoría
│   ├── Search/        ← Búsqueda + filtros
│   ├── ArtistProfile/ ← Perfil, servicios, reseñas
│   ├── Booking/       ← Wizard 3 pasos
│   ├── MyBookings/    ← Historial + detalle
│   ├── Reviews/       ← Dejar reseña post-servicio
│   ├── Quejas/        ← Disputas
│   ├── Profile/       ← Editar perfil, logout
│   └── Notifications/ ← Centro de notificaciones
│
└── Components/
    └── SharedComponents.swift    ← PiumsButton, PiumsTextField, etc.
```

---

## Setup local

### 1. Clonar el repositorio

```bash
git clone https://github.com/app-piums/piums-los-client.git
cd piums-los-client
open PiumsCliente.xcodeproj
```

### 2. Configurar variables de entorno

Crear los archivos de configuración (**no se incluyen en el repo por seguridad**):

```bash
# PiumsCliente/Resources/Debug.xcconfig
API_BASE_URL = http://localhost:3000
FIREBASE_PROJECT_ID = piums-dev
STRIPE_PUBLISHABLE_KEY = pk_test_REPLACE_ME

# PiumsCliente/Resources/Release.xcconfig
API_BASE_URL = https://piums.com
FIREBASE_PROJECT_ID = piums-prod
STRIPE_PUBLISHABLE_KEY = pk_live_REPLACE_ME
```

Asignarlos en Xcode: **Project → Info → Configurations → Debug / Release**.

### 3. Correr en simulador

```bash
# Desde Xcode
⌘R

# Desde terminal
xcodebuild build \
  -scheme PiumsCliente \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### 4. Levantar el backend local (opcional)

```bash
# Desde el repo piums-platform
cd infra/docker
docker compose -f docker-compose.dev.yml up -d
```

> Sin backend, todos los flujos funcionan con **mock data** incluida en cada ViewModel.

---

## Arquitectura

### MVVM + Clean Architecture

```
View  ──→  ViewModel (@Observable)  ──→  Repository / APIClient
 ↑                                              ↓
 └──────────── Estado reactivo ←───── Models (Codable)
```

- **Views**: solo UI, sin lógica de negocio
- **ViewModels**: `@Observable`, `@MainActor`, estado + acciones
- **APIClient**: genérico, maneja refresh de tokens automáticamente en 401
- **TokenStorage**: Keychain, nunca UserDefaults

### Ejemplo ViewModel

```swift
@Observable
@MainActor
final class HomeViewModel {
    var artists: [Artist] = []
    var isLoading = false

    func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let res: PaginatedResponse<Artist> = try await APIClient.request(
                .listArtists(page: 1, limit: 20, category: nil, cityId: nil, q: nil)
            )
            artists = res.data
        } catch {
            artists = Artist.mockList // fallback mock
        }
    }
}
```

---

## Flujos MVP implementados

| Feature | Estado | Mock data |
|---|---|---|
| Auth — Login | ✅ | — |
| Auth — Registro | ✅ | — |
| Auth — Recuperar contraseña | ✅ | — |
| Home — Lista artistas + categorías | ✅ | ✅ |
| Search — Búsqueda + filtros | ✅ | ✅ |
| ArtistProfile — Perfil + servicios + reseñas | ✅ | ✅ |
| Booking — Wizard fecha/hora → detalles → confirmación | ✅ | ✅ |
| MyBookings — Historial + cancelación | ✅ | ✅ |
| Reviews — Dejar reseña con estrellas | ✅ | ✅ |
| Profile — Editar perfil + cambiar contraseña + logout | ✅ | — |
| Notifications — Lista + mark as read | ✅ | ✅ |

---

## Backend — Servicios consumidos

| Servicio | Prefijo API |
|---|---|
| auth-service | `/api/auth` |
| users-service | `/api/users` |
| artists-service | `/api/artists` |
| catalog-service | `/api/catalog` |
| booking-service | `/api/bookings` |
| payments-service | `/api/payments` |
| reviews-service | `/api/reviews` |
| search-service | `/api/search` |
| notifications-service | `/api/notifications` |

**Base URL**: `http://localhost:3000` (dev) / `https://piums.com` (prod)

---

## Brand & Diseño

| Token | Valor |
|---|---|
| Color primario | `#FF6A00` (naranja Piums) |
| Color secundario | `#1A1A1A` |
| Corner radius cards | `12pt` |
| Corner radius botones CTA | `24pt` |
| Fuente | SF Pro (sistema) |

Dark Mode soportado desde el inicio.

---

## Convenciones de código

- `async/await` siempre — nunca completion handlers
- `@MainActor` en todo ViewModel y código que toque UI
- Tokens solo en Keychain — nunca `UserDefaults`
- Sin force unwrap (`!`) sin comentario justificado
- Todas las strings visibles en `Localizable.strings`
- `#Preview` en todas las vistas

---

## Flujo de ramas

```
main        ← producción (protegida)
develop     ← integración / staging
feature/*   ← nuevas funcionalidades
fix/*       ← corrección de bugs
release/*   ← preparación App Store
```

### Convención de commits

```
feat: agregar pantalla de perfil del artista
fix: corregir token refresh en interceptor
chore: actualizar dependencias SPM
style: aplicar colores de brand en HomeView
test: agregar tests de BookingRepository
```

---

## Dependencias (Swift Package Manager)

```swift
// A agregar en Xcode → File → Add Package Dependencies
https://github.com/onevcat/Kingfisher          // imágenes asíncronas
https://github.com/firebase/firebase-ios-sdk   // Auth + Messaging
https://github.com/stripe/stripe-ios           // pagos
```

---

## Checklist antes de subir a App Store

```
☐ Bundle ID registrado: com.piums.client
☐ App Store Connect — app creada
☐ Release.xcconfig con claves de producción (nunca en git)
☐ GoogleService-Info.plist configurado (nunca en git)
☐ Sign in with Apple — Capability habilitada
☐ Push Notifications — Capability habilitada + APNs en Firebase
☐ Privacy manifest (PrivacyInfo.xcprivacy) declarado
☐ NSCameraUsageDescription en Info.plist
☐ Versión y build incrementados
☐ Probado en iPhone SE (pantalla pequeña)
☐ Probado en modo accesibilidad (Dynamic Type)
☐ xcodebuild archive sin warnings críticos
☐ TestFlight build probado antes de publicar
```

---

## Repositorios relacionados

| Repo | Descripción |
|---|---|
| [`piums-platform`](https://github.com/app-piums/piums-platform) | Monorepo backend + web (microservicios Node.js) |
| [`piums-los-client`](https://github.com/app-piums/piums-los-client) | Este repo — App iOS Cliente |

---

**Piums** · Marketplace de artistas en Latinoamérica
