# IOSCONTEXTCLIENT.md — Piums Cliente iOS
> **Última actualización:** 2026-05-14
> Referencia completa para desarrolladores iOS que trabajan en el proyecto Piums Cliente.

---

## 1. Resumen del Proyecto

**Piums Cliente** es una app iOS (SwiftUI) para que clientes contraten artistas creativos. Permite buscar artistas, reservar servicios, chatear en tiempo real y gestionar pagos.

- **Bundle ID:** `io.piums.cliente` (ver Info.plist)
- **Mínimo iOS:** iOS 16+
- **Arquitectura:** MVVM + `@Observable` / `@MainActor` (Swift 6+)
- **Backend API base:** `https://client.piums.io`
- **Socket.IO:** `https://backend.piums.io`

---

## 2. Estructura de Carpetas

```
PiumsCliente/
├── App/
│   ├── AppDelegate.swift          # Firebase, Google Sign-In, APNs
│   ├── MainTabView.swift          # 5 tabs principales + deep links
│   ├── PiumsClienteApp.swift      # Entry point, validación de keys
│   ├── RootView.swift             # Auth gate: AuthFlowView vs MainTabView
│   └── SplashVideoView.swift
├── Components/
│   ├── SharedComponents.swift     # PiumsTextField, PiumsButton, ErrorBannerView, etc.
│   ├── DayButton.swift
│   └── LocationSearchField.swift
├── Core/
│   ├── Auth/
│   │   ├── AuthManager.swift      # Session management (login, logout, refresh, verify)
│   │   ├── TokenStorage.swift     # Keychain access + JWT exp check
│   │   ├── LoginRateLimiter.swift # Rate limit cliente con persistencia en UserDefaults
│   │   └── OAuthWebLogin.swift    # ASWebAuthenticationSession para FB/TikTok
│   ├── Extensions/
│   │   ├── JSONCoder+Piums.swift  # Decoder/Encoder con snakeCase e ISO 8601
│   │   ├── Color+Piums.swift      # Color(hex:), extensiones de colores de marca
│   │   ├── LocationStore.swift    # Observable para ubicación del usuario
│   │   └── LocationManager.swift  # CLLocationManager wrapper
│   ├── Models/
│   │   └── Models.swift           # TODOS los modelos Codable del proyecto
│   ├── Network/
│   │   ├── APIClient.swift        # HTTP client genérico con retry y refresh
│   │   ├── APIEndpoint.swift      # Todos los endpoints (método, path, body)
│   │   ├── AppError.swift         # Enum de errores con mensajes en español
│   │   └── NetworkSecurity.swift  # Certificate pinning SHA-256
│   └── ThemeManager.swift         # Light/dark mode con persistencia
├── Features/
│   ├── ArtistProfile/             # Vista del perfil público del artista
│   ├── Auth/                      # Login, Register, ForgotPassword, AuthFlowView
│   ├── Booking/                   # BookingFlowView (4 pasos), ArtistSearchByDateView
│   ├── Chat/                      # ChatInboxView, ChatDetailView, ChatViewModel
│   │   ├── ChatSocketManager.swift
│   │   └── ChatRealtimeStore.swift
│   ├── Coupons/                   # Vista de cupones del usuario
│   ├── Events/                    # Gestión de eventos (bodas, fiestas, etc.)
│   ├── Favorites/                 # FavoritesView + FavoritesStore (singleton)
│   ├── Home/                      # HomeView con artistas destacados
│   ├── HowItWorks/                # TourOverlayView, TutorialManager (tour interactivo)
│   ├── MyBookings/                # Lista de reservas + DeepLinkBookingView
│   ├── Notifications/             # NotificationsView + NotificationsStore
│   ├── Onboarding/                # 4 pasos: nombre, especialidades, ciudad, docs
│   ├── Payments/                  # PaymentsView, WalletView, TilopayWebView
│   ├── Profile/                   # ProfileView, NotificationPreferencesView
│   ├── Quejas/                    # Disputas: lista, detalle, crear
│   ├── Reviews/                   # Dejar reseña tras servicio completado
│   └── Search/                    # SearchView, TalentPickerView
└── PiumsClienteApp.swift
```

---

## 3. Navegación Principal

### 3.1 MainTabView — 5 tabs

| Tab | Índice | Vista | Badge |
|-----|--------|-------|-------|
| Inicio | 0 | `HomeView` | — |
| Explorar | 1 | `SearchView` | — |
| Mi Espacio | 2 | `MySpaceView` (NavigationPath bookings) | — |
| Mensajes | 3 | `ChatInboxView` | `ChatRealtimeStore.unreadCount` |
| Perfil | 4 | `ProfileView` | — |

### 3.2 Deep Links vía NotificationCenter

```swift
extension Notification.Name {
    static let navigateToBooking      = Notification.Name("navigateToBooking")
    static let navigateToMySpace      = Notification.Name("navigateToMySpace")
    static let navigateToProfile      = Notification.Name("navigateToProfile")
    static let navigateToConversation = Notification.Name("navigateToConversation")
    static let notificationsNeedRefresh = Notification.Name("notifications.needs.refresh")
}
```

Push payload → AppDelegate → `NotificationCenter.post` → MainTabView cambia tab y navega.

### 3.3 AppStorage / UserDefaults Keys

| Clave | Tipo | Propósito |
|-------|------|----------|
| `hasSeenHowItWorks` | @AppStorage | Sheet "Cómo funciona" en primer lanzamiento |
| `hasSeenTour` | @AppStorage | Tour interactivo: mostrar solo una vez |
| `hasSeenOnboarding` | @AppStorage | Saltar onboarding en reinicios |
| `piums_color_scheme` | UserDefaults | Preferencia light/dark del usuario |
| `piums.currentUser` | UserDefaults | Cache JSON del AuthUser (sesión offline) |
| `identityVerificationSubmitted` | UserDefaults | Usuario subió docs de identidad |
| `identityVerificationApproved` | UserDefaults | Backend aprobó identidad |
| `rl.lock.{email}` | UserDefaults | Timestamp de bloqueo rate limit por email |

---

## 4. Sistema de Autenticación

### 4.1 AuthManager (`Core/Auth/AuthManager.swift`)

`@Observable @MainActor` singleton. Gestiona sesión completa.

```swift
var currentUser: AuthUser?
var isAuthenticated: Bool { currentUser != nil }
```

**Métodos públicos:**
- `login(email:password:)` → `POST /api/auth/login`
- `register(name:email:password:)` → `POST /api/auth/register/client`
- `loginWithGoogle()` → Google Sign-In → Firebase → `POST /api/auth/firebase`
- `loginWithApple()` → ASAuthorization → Firebase → `POST /api/auth/firebase`
- `loginWithFacebook()` → OAuthWebLogin → `POST /api/auth/facebook`
- `loginWithTikTok()` → OAuthWebLogin → `POST /api/auth/tiktok`
- `forgotPassword(email:)` — mínimo 600ms de respuesta (anti-timing)
- `logout()` — limpia Keychain + UserDefaults + Google Sign-Out
- `refreshIfNeeded()` → `POST /api/auth/refresh`

**Inicio de sesión persistente (`loadFromStorage`):**
1. Restaura `currentUser` desde cache UserDefaults (sin red, instantáneo)
2. Si no hay refreshToken → limpia sesión
3. Si access token expirado → `refreshIfNeeded()`
4. `verify()` en background → `GET /api/auth/me`
   - Solo cierra sesión si recibe explícitamente `.unauthorized`
   - Errores de red, timeout, 5xx → mantiene sesión activa

### 4.2 TokenStorage (`Core/Auth/TokenStorage.swift`)

Keychain. Nunca UserDefaults.

| Clave Keychain | Acceso |
|---------------|--------|
| `piums.access_token` | `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` |
| `piums.refresh_token` | `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` |

```swift
var isAccessTokenExpired: Bool  // exp claim + margen 30s
var accessTokenExpiry: Date?
static func looksLikeJWT(_ token: String) -> Bool  // valida estructura 3 partes
```

### 4.3 Flujo Social — Google y Apple

```
Google Sign-In
    └── GIDSignIn.sharedInstance.signIn()
         └── idToken + accessToken
              └── GoogleAuthProvider.credential()
                   └── Auth.auth().signIn()    ← Firebase
                        └── getIDToken()
                             └── POST /api/auth/firebase  → AuthResponse (JWT Piums)

Apple Sign In
    └── ASAuthorizationController
         └── ASAuthorizationAppleIDCredential
              └── OAuthProvider.appleCredential()
                   └── Auth.auth().signIn()    ← Firebase
                        └── getIDToken()
                             └── POST /api/auth/firebase  → AuthResponse
```

### 4.4 Flujo Social — Facebook y TikTok

```
OAuthWebLogin (ASWebAuthenticationSession)
    └── GET /api/auth/facebook?state={nonce}
         └── Backend (Passport.js) → redirect
              └── https://piums.com/auth/callback?token=JWT&provider=facebook
                   └── Extract ?token= → TokenStorage → verify()
```

CSRF: nonce aleatorio en `?state=`. El backend debe reenviar `state` en el callback. Si no lo hace, se loguea advertencia en DEBUG pero el login prosigue.

### 4.5 LoginRateLimiter (`Core/Auth/LoginRateLimiter.swift`)

Protección cliente contra fuerza bruta, persiste en UserDefaults.

| Intentos fallidos | Bloqueo |
|:-----------------:|---------|
| 3–4 | Advertencia: "X intentos restantes" |
| 5–9 | 5 minutos |
| 10+ | 15 minutos |

```swift
LoginRateLimiter.shared.shouldBlock(email:) → String?  // nil = puede intentar
LoginRateLimiter.shared.recordFailure(email:)
LoginRateLimiter.shared.reset(email:)           // tras login exitoso
LoginRateLimiter.shared.lockedUntil(email:) → Date?  // para countdown live
LoginRateLimiter.countdownMessage(seconds:) → String  // "Demasiados intentos. Espera 5 min."
```

**AuthViewModel** inicia `Task` de countdown que actualiza `errorMessage` cada segundo hasta que expire.

---

## 5. Networking

### 5.1 APIClient (`Core/Network/APIClient.swift`)

```swift
APIClient.request<T: Decodable>(_ endpoint: APIEndpoint, retryOnUnauthorized: Bool = true) async throws -> T
APIClient.uploadMultipart<T: Decodable>(_ endpoint:, imageData:, filename:, mimeType:) async throws -> T
```

**Lógica interna:**
- Refresh proactivo si `isAccessTokenExpired` antes de enviar request auth
- Header `Authorization: Bearer {token}` + `X-Request-ID: UUID()`
- Si 401 + `retryOnUnauthorized`: refresh → reintento único
- Si 429: parsea `Retry-After` header → mensaje `LoginRateLimiter.countdownMessage`
- Si 5xx: `throw AppError.serverError` (mensaje genérico, nunca mensaje técnico del backend)
- `default`: `"Error inesperado. Intenta de nuevo."`

**URLSession:** configurado con `CertificatePinningDelegate` (ver §5.3).

### 5.2 AppError (`Core/Network/AppError.swift`)

```swift
enum AppError: LocalizedError, Equatable {
    case network(URLError)
    case http(statusCode: Int, message: String)
    case decoding(Error)
    case unauthorized     // 401 — token inválido o expirado
    case notFound         // 404
    case serverError      // 5xx
    case unknown(Error)
}
```

**Mensajes por URLError:**

| URLError.Code | Mensaje usuario |
|--------------|-----------------|
| `.timedOut` | "La solicitud tardó demasiado. Intenta de nuevo." |
| `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed` | "Sin conexión a internet" |
| `.cannotConnectToHost`, `.cannotFindHost`, `.dnsLookupFailed` | "No se puede conectar al servidor" |
| `.secureConnectionFailed`, `.serverCertificateUntrusted` | "Error de seguridad en la conexión" |
| otros | "Error de red. Intenta de nuevo." |

### 5.3 Certificate Pinning (`Core/Network/NetworkSecurity.swift`)

SHA-256 (DER, Base64) para:
- `client.piums.io` y `backend.piums.io`
- Leaf cert (vence 2026-07-21): `bXcinqCEgWfTR8vYpEctiYO9Tq7YLAfUtvWLZJKvNhI=`
- Let's Encrypt E8 Intermediate: `g2JP0zjI2bAjwYpny3qcBRnaQ9EXdbTGy9rUXD2ZfFI=`

Pinning desactivado en DEBUG para Charles Proxy / simulador.

**Rotación de certificado:**
```bash
echo | openssl s_client -connect client.piums.io:443 2>/dev/null \
  | openssl x509 -outform der | openssl dgst -sha256 -binary | base64
```

### 5.4 JSON Strategy (`Core/Extensions/JSONCoder+Piums.swift`)

```swift
JSONDecoder.piums  // keyDecodingStrategy = .convertFromSnakeCase, dateDecodingStrategy = .iso8601
JSONEncoder.piums  // keyEncodingStrategy = .convertToSnakeCase, dateEncodingStrategy = .iso8601
```

Backend usa snake_case → Swift usa camelCase automático. Fechas en ISO 8601 (con y sin fracciones de segundo).

---

## 6. Todos los Endpoints

### Auth

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `login(email, password)` | POST | `/api/auth/login` | No |
| `registerClient(name, email, password)` | POST | `/api/auth/register/client` | No |
| `firebaseAuth(token)` | POST | `/api/auth/firebase` | No |
| `refreshToken(token)` | POST | `/api/auth/refresh` | No |
| `logout` | POST | `/api/auth/logout` | Sí |
| `getMe` | GET | `/api/auth/me` | No* |
| `forgotPassword(email)` | POST | `/api/auth/forgot-password` | No |
| `completeOnboarding` | PATCH | `/api/auth/complete-onboarding` | Sí |

*`getMe` envía token si está disponible, pero no lanza error si no hay.

### Búsqueda y Artistas

| Endpoint | Método | Path |
|----------|--------|------|
| `searchArtists(q, page, limit, specialty, city, minPrice, maxPrice, minRating, isVerified, sortBy, sortOrder)` | GET | `/api/search/artists` |
| `smartSearch(q, city, lat, lng, page, limit, ...)` | GET | `/api/search/smart` |
| `getArtist(id)` | GET | `/api/artists/{id}` |
| `getArtistPortfolio(id)` | GET | `/api/artists/{id}/portfolio` |

### Catálogo y Servicios

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `listServices(artistId)` | GET | `/api/catalog/services?artistId=` | No |
| `getService(id)` | GET | `/api/catalog/services/{id}` | No |
| `calculatePrice(payload)` | POST | `/api/catalog/pricing/calculate` | Sí |

### Reservas

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `createBooking(payload)` | POST | `/api/bookings` | Sí |
| `listMyBookings(status, page)` | GET | `/api/bookings?page=&limit=20` | Sí |
| `getBooking(id)` | GET | `/api/bookings/{id}` | Sí |
| `cancelBooking(id)` | POST | `/api/bookings/{id}/cancel` | Sí |
| `rescheduleBooking(id, payload)` | PATCH | `/api/bookings/{id}/reschedule` | Sí |
| `getAvailableSlots(artistId, date)` | GET | `/api/availability/time-slots` | Sí |
| `getArtistCalendar(artistId, year, month)` | GET | `/api/availability/calendar` | Sí |
| `reportNoShow(bookingId, reason)` | POST | `/api/bookings/{bookingId}/no-show` | Sí |

### Reseñas

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `listReviews(artistId, page)` | GET | `/api/reviews?artistId=&page=&limit=10` | No |
| `createReview(payload)` | POST | `/api/reviews` | Sí |

### Notificaciones

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `listNotifications(page)` | GET | `/api/notifications?page=&limit=20` | Sí |
| `markNotificationsRead(ids)` | POST | `/api/notifications/read` | Sí |
| `registerPushToken(token, platform)` | POST | `/api/notifications/push-token` | Sí |
| `getNotifPreferences` | GET | `/api/notifications/preferences` | Sí |
| `updateNotifPreferences(payload)` | PUT | `/api/notifications/preferences` | Sí |

### Perfil y Usuario

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `updateMyProfile(payload)` | PATCH | `/api/auth/profile` | Sí |
| `changePassword(current, new)` | POST | `/api/auth/change-password` | Sí |
| `uploadAvatar` | POST | `/api/users/me/avatar` (multipart) | Sí |
| `deleteAccount(userId)` | DELETE | `/api/users/{userId}` | Sí |
| `uploadDocument(folder)` | POST | `/api/users/documents/upload?folder={front\|back\|selfie}` | Sí |

### Favoritos

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `listFavorites(page, entityType)` | GET | `/api/users/me/favorites?page=&limit=50&entityType=` | Sí |
| `addFavorite(entityType, entityId, notes?)` | POST | `/api/users/me/favorites` | Sí |
| `deleteFavorite(id)` | DELETE | `/api/users/me/favorites/{id}` | Sí |
| `checkFavorite(entityType, entityId)` | GET | `/api/users/me/favorites/check` | Sí |

> **Nota quirk:** `listFavorites` devuelve `{ favorites, pagination }` — no `{ data }`.
> `addFavorite` devuelve `{ favorite: {...} }` — no el objeto directamente.

### Pagos

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `createPaymentIntent(bookingId, ...)` | POST | `/api/payments/checkout` | Sí |
| `confirmTilopayRedirect(bookingId, responseCode, ...)` | POST | `/api/payments/tilopay/confirm` | Sí |
| `getMyCredits` | GET | `/api/payments/credits/me` | Sí |
| `listPayments(page)` | GET | `/api/payments/payments?page=&limit=20` | Sí |
| `getPayment(id)` | GET | `/api/payments/payments/{id}` | Sí |
| `listPaymentMethods` | GET | `/api/payments/methods` | Sí |
| `deletePaymentMethod(id)` | DELETE | `/api/payments/methods/{id}` | Sí |
| `setDefaultPaymentMethod(id)` | PATCH | `/api/payments/methods/{id}/default` | Sí |
| `addPaymentMethod(stripePaymentMethodId, setAsDefault)` | POST | `/api/payments/methods` | Sí |

### Chat

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `listConversations(page)` | GET | `/api/chat/conversations?page=&limit=20` | Sí |
| `getConversation(id)` | GET | `/api/chat/conversations/{id}` | Sí |
| `createConversation(artistId)` | POST | `/api/chat/conversations` | Sí |
| `markConversationRead(id)` | PATCH | `/api/chat/conversations/{id}/read` | Sí |
| `listMessages(conversationId, page)` | GET | `/api/chat/messages/{conversationId}?page=&limit=50` | Sí |
| `sendMessage(conversationId, content)` | POST | `/api/chat/messages` | Sí |
| `unreadCount` | GET | `/api/chat/messages/unread-count` | Sí |

### Disputas

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `listMyDisputes` | GET | `/api/disputes/me` | Sí |
| `createDispute(payload)` | POST | `/api/disputes` | Sí |
| `getDispute(id)` | GET | `/api/disputes/{id}` | Sí |
| `addDisputeMessage(id, message)` | POST | `/api/disputes/{id}/messages` | Sí |

### Cupones

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `getMyCoupons` | GET | `/api/coupons/my` | Sí |
| `validateCoupon(payload)` | POST | `/api/coupons/validate` | Sí |

### Eventos

| Endpoint | Método | Path | Auth |
|----------|--------|------|------|
| `listEvents` | GET | `/api/events` | Sí |
| `createEvent(payload)` | POST | `/api/events` | Sí |
| `getEvent(id)` | GET | `/api/events/{id}` | Sí |
| `updateEvent(id, payload)` | PATCH | `/api/events/{id}` | Sí |
| `deleteEvent(id)` | DELETE | `/api/events/{id}` | Sí |
| `addBookingToEvent(eventId, bookingId)` | POST | `/api/events/{eventId}/bookings/{bookingId}` | Sí |

---

## 7. Modelos de Datos

### 7.1 Autenticación

```swift
struct AuthUser: Codable, Identifiable {
    let id: String
    let email: String
    let nombre: String          // no "name"
    let role: String            // "cliente" | "artista" | "admin"
    let avatar: String?
    let emailVerified: Bool
    let status: String          // "ACTIVE" | "BANNED" | "SUSPENDED"
    let isVerified: Bool        // identidad verificada
    let documentType: String?
    let documentFrontUrl: String?
    let documentSelfieUrl: String?
}
```

### 7.2 Artistas y Búsqueda

```swift
struct Artist: Codable, Identifiable {
    let id: String
    let name: String
    let bio: String?
    let city: String?
    let state: String?
    let country: String?
    let averageRating: Double?
    let totalReviews: Int
    let totalBookings: Int
    let hourlyRateMin: Int?     // centavos
    let hourlyRateMax: Int?
    let mainServicePrice: Int?  // centavos
    let mainServiceName: String?
    let isVerified: Bool
    let isActive: Bool
    let isAvailable: Bool
    let specialties: [String]
    let avatar: String?
    let coverUrl: String?       // coverPhoto del backend
    let instagram: String?
    let website: String?
    // ... más campos
}

struct SmartArtist: Codable {   // Hereda campos de Artist + matchedService + score
    // ... todos los campos de Artist
    let matchedService: MatchedService?
    let score: Double?
}

struct MatchedService: Codable {
    let id: String
    let name: String
    let price: Int?             // centavos
    let currency: String
    let pricingType: String     // "FIXED" | "HOURLY" | "PACKAGE"
    let isExactMatch: Bool
}
```

### 7.3 Servicios

```swift
struct ArtistService: Codable, Identifiable {
    let id: String
    let artistId: String
    let name: String
    let description: String?
    let pricingType: String     // "FIXED" | "HOURLY" | "PACKAGE"
    let basePrice: Int          // centavos
    let currency: String
    let durationMin: Int?       // minutos
    let durationMax: Int?
    let status: String          // "ACTIVE" | "INACTIVE"
    let isAvailable: Bool
    let isFeatured: Bool
    let addons: [ServiceAddon]
    let thumbnail: String?
    let tags: [String]
    let isMainService: Bool
}

struct ServiceAddon: Codable, Identifiable {
    let id: String
    let serviceId: String
    let name: String
    let description: String?
    let price: Int              // centavos
    let isRequired: Bool
    let isOptional: Bool
    let isDefault: Bool
    let order: Int
}
```

### 7.4 Reservas

```swift
enum BookingStatus: String, Codable {
    case pending, confirmed, paymentPending, paymentCompleted
    case inProgress, delivered
    case disputeOpen, disputeResolved
    case completed
    case rescheduled, reschedulePendingArtist, reschedulePendingClient
    case cancelledClient, cancelledArtist, rejected, noShow
    case unknown
}

enum PaymentStatus: String, Codable {
    case pending, completed
    case anticipoPaid, depositPaid    // aliases
    case chargingRemaining, fullyPaid
    case frozen
    case partiallyRefunded, refunded, failed
    case unknown
}

struct Booking: Codable, Identifiable {
    let id: String
    let code: String
    let status: BookingStatus
    let paymentStatus: PaymentStatus
    let totalPrice: Int             // centavos
    let scheduledDate: String       // "YYYY-MM-DD"
    let scheduledTime: String?      // "HH:MM"
    let durationMinutes: Int?
    let notes: String?
    let location: String?
    let eventId: String?
    let eventType: String?
    let anticipoRequired: Bool
    let anticipoAmount: Int?        // centavos
    let currency: String
    let artist: BookingParticipant?
    let client: BookingParticipant?
    // ... más campos
}
```

### 7.5 Chat

```swift
struct Conversation: Codable, Identifiable {
    let id: String
    // Quirk: backend envía participant1Id/participant2Id
    let userId: String          // mapeado de participant1Id
    let artistId: String        // mapeado de participant2Id
    let bookingId: String?
    let status: String
    let lastMessageAt: Date?
    let lastMessageContent: String?  // mapeado de lastMessagePreview
    let unreadCount: Int
    let clientName: String?
    let clientAvatar: String?
}

struct ChatMessage: Codable, Identifiable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let type: String            // "TEXT"
    let status: String          // "SENT" | "DELIVERED" | "READ"
    let readAt: Date?
    let createdAt: Date
    var read: Bool { readAt != nil }
}
```

### 7.6 Pagos

```swift
struct PaymentIntent: Codable, Identifiable {
    let id: String
    let providerRef: String?
    let redirectUrl: String?    // Tilopay
    let clientSecret: String?   // Stripe
    let provider: String        // "TILOPAY" | "STRIPE"
    let status: String          // "CREATED" | "REQUIRES_ACTION" | "SUCCEEDED" | "FAILED"
    var isTilopay: Bool { provider == "TILOPAY" }
}

struct PaymentMethod: Codable, Identifiable {
    let id: String
    let provider: String        // "STRIPE" | "TILOPAY"
    let type: String            // "card"
    let cardBrand: String?
    let cardLast4: String?
    let cardExpMonth: Int?
    let cardExpYear: Int?
    let isDefault: Bool
    var brandLabel: String      // computed
    var expiryLabel: String     // computed
}
```

### 7.7 Flujo de Reserva (BookingFlowContext)

```swift
class BookingFlowContext: ObservableObject {
    var artist: Artist
    var service: ArtistService
    var selectedDate: Date?
    var selectedSlot: TimeSlot?
    var isMultiDay: Bool
    var numDays: Int
    var location: String?
    var locationLat: Double?
    var locationLng: Double?
    var clientNotes: String
    var priceQuote: PriceQuote?
    var eventId: String?
    var eventType: EventType?
    var selectedAddons: [String]   // addon IDs

    var scheduledDateISO: String   // computed: "YYYY-MM-DD"
    var durationMinutes: Int       // computed desde service
}
```

### 7.8 Precio / Cotización

```swift
struct PriceQuote: Codable {
    let serviceId: String
    let currency: String
    let items: [PriceQuoteItem]
    let subtotalCents: Int
    let totalCents: Int
    let breakdown: PriceQuoteBreakdown
    let totalInUnits: Double     // totalCents / 100
    let baseInUnits: Double
    let travelInUnits: Double
    let hasTravel: Bool
}

// Todos los precios en centavos (Int). Formatear con:
// extension Int { var piumsFormatted: String }  // 250000 → "$ 2,500.00"
```

---

## 8. Chat en Tiempo Real (Socket.IO)

### 8.1 ChatSocketManager (`Features/Chat/ChatSocketManager.swift`)

**Conexión:**
```swift
URL: CHAT_SOCKET_URL (plist) ?? "https://backend.piums.io"
Auth: ["token": accessToken]
Reconnect: 10 intentos, espera inicial 3s, máx 30s
```

**Eventos emitidos (Client → Server):**
```
conversation:join    { conversationId: String }
conversation:leave   { conversationId: String }
conversation:read    { conversationId: String }
message:send         { conversationId: String, content: String, type: "TEXT" }
```

**Eventos recibidos (Server → Client):**
```
message:received    → ChatMessage
message:sent        → ChatMessage (echo del mensaje propio)
message:read        → { messageId: String }
unread:count        → { unreadCount: Int }
message:error       → { message: String } | { error: String }
```

### 8.2 Notificaciones internas del socket

```swift
extension Notification.Name {
    static let chatMessageReceived      = "chat.message.received"
    static let chatMessageRead          = "chat.message.read"
    static let chatUnreadCountUpdated   = "chat.unread.count.updated"
    static let chatMessageError         = "chat.message.error"
    static let chatSocketReconnected    = "chat.socket.reconnected"
}
```

### 8.3 ChatViewModel (`Features/Chat/ViewModels/ChatViewModel.swift`)

**Quirk importante:** Si llega un mensaje de una conversación desconocida (nueva), `handleIncoming` dispara `loadConversations()` para refrescar el inbox. Sin esto, conversaciones nuevas de artistas no aparecen.

```swift
private func handleIncoming(_ msg: ChatMessage) {
    if currentConversationId == msg.conversationId,
       !messages.contains(where: { $0.id == msg.id }) {
        messages.append(msg)
    }
    if let idx = conversations.firstIndex(where: { $0.id == msg.conversationId }) {
        // actualizar preview existente
    } else {
        // conversación nueva → refrescar inbox
        Task { await loadConversations() }
    }
}
```

**Observers limpiados en `deinit`:**
```swift
nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
deinit {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
}
```

### 8.4 ChatRealtimeStore (`Features/Chat/ChatRealtimeStore.swift`)

Singleton observable. Mantiene `unreadCount: Int` para el badge del tab. Auto-conecta socket al lanzar la app.

---

## 9. Flujo de Pago

### 9.1 Lógica de ruteo

```
POST /api/payments/checkout → PaymentIntentWrapper
    ├── provider == "STRIPE" → clientSecret → Stripe SDK nativo
    └── provider == "TILOPAY" → redirectUrl → TilopayWebView (WKWebView)
```

### 9.2 Tilopay (WKWebView)

- `TilopayWebView` carga `redirectUrl` en WKWebView
- Intercepta URL de callback (`piums.com/...` o parámetros en la URL)
- Extrae `responseCode`, `orderNumber`, `amount`, `orderHash`
- Llama `POST /api/payments/tilopay/confirm` para confirmar al backend

### 9.3 Anticipo (depósito parcial)

Si `booking.anticipoRequired == true`:
- Solo se cobra `anticipoAmount` primero
- El resto se cobra al completar el servicio
- `PaymentStatus.anticipoPaid` indica que el anticipo fue pagado

### 9.4 Wallet / Métodos de Pago

- Lista tarjetas guardadas vía `GET /api/payments/methods`
- Tarjeta predeterminada usada automáticamente en el checkout
- Puede agregar nuevas tarjetas (Stripe), eliminar o cambiar default

---

## 10. Push Notifications (APNs)

### 10.1 Registro

```swift
// AppDelegate.swift
UNUserNotificationCenter.current().requestAuthorization()
application.registerForRemoteNotifications()
// → didRegisterForRemoteNotificationsWithDeviceToken
// → POST /api/notifications/push-token { token: hexString, platform: "ios" }
```

### 10.2 Payload y Deep Links

| Campo en payload | Acción |
|----------------|--------|
| `conversationId` o `chatId` | `.navigateToConversation` → Tab Mensajes |
| `bookingId` | `.navigateToBooking` → Tab Mi Espacio → detalle |
| `badge` | Actualiza badge del app icon |

**Silenciosas (`content-available: 1`):** Procesadas en background sin mostrar banner.

### 10.3 NotificationsStore

Mantiene badge de campana en ProfileView. Escucha `.notificationsNeedRefresh`. Sin endpoint de conteo dedicado: fetch primera página y cuenta `isRead == false`.

---

## 11. Flujo de Reserva (4 Pasos)

### BookingFlowView

```
Paso 1: Selección de fecha
    → GET /api/availability/calendar → ocupados/bloqueados
    → GET /api/availability/time-slots → slots disponibles

Paso 2: Detalles (ubicación, notas, addons)
    → POST /api/catalog/pricing/calculate → PriceQuote (con viaje si hay lat/lng)

Paso 3: Confirmación y resumen de precio
    → desglose: baseCents + addonsCents + travelCents - discountsCents

Paso 4: Pago
    → POST /api/bookings → Booking
    → POST /api/payments/checkout → PaymentIntent
    → Stripe o Tilopay según provider
```

---

## 12. Tour Interactivo (TutorialManager)

```swift
// TutorialManager.swift — @MainActor singleton
@AppStorage("hasSeenTour") private var hasSeenTour = false

func startIfFirstTime() {
    guard !hasSeenTour else { return }
    hasSeenTour = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.start() }
}
```

**TourOverlayView:**
- 6 pasos cubriendo los 5 tabs + búsqueda por fecha/lugar
- Swipe izquierda/derecha (`DragGesture(minimumDistance: 40)`)
- Animación direccional (`AnyTransition.asymmetric`) — no `.id()` en el contenedor exterior
- `stepDirection: StepDirection` (.forward / .backward) determina el edge de entrada/salida

---

## 13. Onboarding (4 Pasos)

Mostrado solo en primer login (`@AppStorage("hasSeenOnboarding")`):

1. **Nombre** — confirmar o editar nombre del usuario
2. **Especialidades** — seleccionar gustos artísticos (múltiple)
3. **Ciudad** — ubicación preferida
4. **Verificación de identidad** — subir documento (frente, selfie) vía `uploadDocument(folder:)` → `PATCH /api/auth/complete-onboarding`

---

## 14. Design System

### 14.1 Colores (`Core/Extensions/Color+Piums.swift`)

```swift
Color.piumsOrange   // naranja primario de marca
Color.piumsDark     // #1A1A1A fondo oscuro
Color(hex: "#FF6B35")  // inicializador hex disponible
```

Soporta modo oscuro / claro con `ThemeManager`.

### 14.2 Componentes (`Components/SharedComponents.swift`)

| Componente | Uso |
|-----------|-----|
| `PiumsTextField` | Campo de texto con ícono opcional |
| `PiumsSecureField` | Campo de contraseña con toggle visibilidad |
| `PiumsButton` | Botón primario/secundario/destructivo |
| `ErrorBannerView` | Banner de error (slide desde abajo) |
| `SuccessBannerView` | Banner de éxito |
| `LoadingView` | Indicador de progreso |
| `LocationDeniedBanner` | Prompt para habilitar ubicación |

### 14.3 Formateo de Precios

```swift
// Todos los precios almacenados como Int en centavos
extension Int {
    var piumsFormatted: String  // 250000 → "$ 2,500.00"
}
```

---

## 15. ViewModels — Resumen

| ViewModel | Observables clave | Métodos clave |
|-----------|-------------------|---------------|
| `AuthViewModel` | email, password, name, activeScreen | login(), register(), loginWithGoogle/Apple/Facebook/TikTok(), forgotPassword() |
| `HomeViewModel` | artists, firstName, nextBooking | loadInitial(), refreshIfStale() |
| `SearchViewModel` | query, results, smartResults, filters | search(), loadNext(), clearFilters() |
| `ArtistProfileViewModel` | artist, services, reviews, portfolio | loadAll(), addToFavorites() |
| `MyBookingsViewModel` | bookings, selectedStatus | loadInitial(), cancelBooking() |
| `ChatViewModel` | conversations, messages, currentConversationId | loadConversations(), sendMessage(), createOrOpenConversation() |
| `NotificationsViewModel` | notifications, unreadCount | loadInitial(), markAsRead(), markAllRead() |
| `PaymentsViewModel` | payments, credits | loadInitial(), loadCredits() |
| `ProfileViewModel` | user, editName/Email, passwords | saveProfile(), changePassword(), deleteAccount(), logout() |
| `EventsViewModel` | events | loadEvents(), createEvent(), updateEvent(), deleteEvent() |
| `QuejasViewModel` | disputes | loadInitial() |
| `ReviewViewModel` | rating, comment, isSuccess | submitReview() |

---

## 16. Configuración / Info.plist

| Clave | Valor / Descripción |
|-------|---------------------|
| `API_BASE_URL` | `https://client.piums.io` (default si no está en plist) |
| `CHAT_SOCKET_URL` | `https://backend.piums.io` |
| `STRIPE_PUBLISHABLE_KEY` | Validado en startup — falla hard si es placeholder |
| `NSLocationWhenInUseUsageDescription` | "Piums usa tu ubicación para mostrarte artistas cerca de ti..." |
| `NSPhotoLibraryUsageDescription` | "Selecciona una foto de tu galería para personalizar tu perfil..." |
| `UIBackgroundModes` | `remote-notifications` |
| `CFBundleURLSchemes` | `com.googleusercontent.apps.967320828042-...` (Google OAuth) |
| `NSAppTransportSecurity.NSAllowsArbitraryLoads` | `false` (solo HTTPS) |

---

## 17. Quirks y Notas Importantes del Backend

1. **`scheduledDate`** — debe enviarse como ISO 8601 completo (`"2026-06-15T00:00:00.000Z"`), no como `"YYYY-MM-DD"`.

2. **Favoritos** — `GET /api/users/me/favorites` devuelve `{ favorites, pagination }` (no `{ data }`). `POST` devuelve `{ favorite: {...} }`.

3. **Conversaciones** — `participant1Id`/`participant2Id` en lugar de `userId`/`artistId`. `lastMessagePreview` en lugar de `lastMessageContent`.

4. **Validación de errores** — el backend devuelve `{ message, errors: [{ field, message }] }`. `APIClient` construye mensaje completo incluyendo campos.

5. **`getMe`** — `GET /api/auth/me` no requiere auth en el endpoint pero devuelve datos del usuario autenticado. Si hay token se envía.

6. **Anticipo** — `booking.anticipoRequired` indica si se cobra solo el depósito. `anticipoAmount` en centavos. Estado `anticipoPaid` en `PaymentStatus`.

7. **`refreshToken`** — `POST /api/auth/refresh` — nunca enviar header `Authorization`.

8. **Lazy provisioning** — `getUserByAuthId` en users-service crea perfil automáticamente si no existe (afecta a cuentas nuevas de social login).

9. **Tilopay modal** — se muestra como `.sheet` en iOS, no como push navigation.

10. **`unread:count`** socket event — puede venir como `{ unreadCount }` o directamente como `Int` dependiendo de la versión del backend. Manejar ambos.

11. **Tarifas en centavos** — TODOS los campos de precio en el backend son centavos (`Int`). Nunca confundir con dólares.

---

## 18. Patrones y Convenciones

1. **State Management:** `@Observable @MainActor final class ViewModel`
2. **Networking:** `APIClient.request<T: Decodable>(_:)` — siempre genérico
3. **Errores:** Capturar como `AppError`, mostrar `localizedDescription` (español)
4. **Paginación:** campos `page`, `limit`, `totalPages`, `hasMore` / `total`
5. **Precios:** `Int` centavos en modelos; `.piumsFormatted` para mostrar
6. **Fechas:** ISO 8601 con `JSONDecoder.piums`; `Date` en Swift
7. **IDs:** `String` (UUIDs del backend)
8. **Cross-feature navigation:** `NotificationCenter.post(name:)` → observer en `MainTabView`
9. **Singletons observables:** `AuthManager.shared`, `FavoritesStore.shared`, `ChatRealtimeStore.shared`, `LoginRateLimiter.shared`
10. **ErrorBanner en vistas:** usar `.safeAreaInset(edge: .bottom)` con `ErrorBannerView` + animación spring
