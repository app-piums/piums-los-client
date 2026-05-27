# 🎯 AGENT.md - Guía de Replicación para Piums Cliente iOS

> **Guía completa para replicar la aplicación Piums Cliente en otras plataformas y crear la app de artistas**

---

## 📱 **Información General del Proyecto**

### **Aplicación**: Piums Cliente iOS
- **Plataforma**: iOS (SwiftUI)
- **Tipo**: Marketplace de servicios creativos (Cliente)
- **Target iOS**: 15.0+
- **Arquitectura**: MVVM + Observable
- **Backend**: Microservicios REST API

### **Repositorios**
- **iOS Cliente**: `https://github.com/app-piums/piums-los-client.git`
- **Backend Platform**: `https://github.com/app-piums/piums-platform.git`
- **Web Cliente**: Disponible en el repositorio de platform

---

## 🏗️ **Arquitectura y Estructura**

### **Patrón Arquitectónico**
```
MVVM + Observable + Dependency Injection

├── Views (SwiftUI)
├── ViewModels (@Observable)
├── Models (Codable)
├── Services (API, Auth, Storage)
└── Core (Extensions, Network, Utils)
```

### **Estructura de Carpetas**
```
PiumsCliente/
├── App/                          # Configuración de app
│   ├── MainTabView.swift        # Navegación principal (5 tabs)
│   ├── RootView.swift           # Router principal + Splash
│   └── AppDelegate.swift        # Configuración iOS
├── Core/
│   ├── Auth/                    # Autenticación y tokens
│   ├── Network/                 # APIClient + Endpoints
│   ├── Models/                  # Modelos de datos
│   └── Extensions/              # Color+Piums, Formatters
├── Features/                    # Módulos por funcionalidad
│   ├── Auth/                   # Login, Register, Forgot
│   ├── Onboarding/             # Intro de 3 pasos
│   ├── Home/                   # Dashboard + Artistas
│   ├── Search/                 # Búsqueda + SmartSearch
│   ├── Booking/                # Flujo de reserva (3 pasos)
│   ├── MyBookings/             # Historial reservas
│   ├── Events/                 # Gestión de eventos
│   ├── Favorites/              # Artistas favoritos
│   ├── Chat/                   # Mensajería (WebSocket)
│   ├── Notifications/          # Centro notificaciones
│   ├── Profile/                # Perfil de usuario
│   ├── Quejas/                # Sistema de disputas
│   └── Payments/               # Historial pagos
├── Components/                 # Componentes reutilizables
└── Assets.xcassets/           # Recursos gráficos
    ├── PiumsLogo.imageset/    # Logo oficial
    └── [Colors]               # Palette de colores
```

---

## 🎨 **Diseño y UI/UX**

### **Sistema de Colores (Piums Palette)**
```swift
// Colores principales
Color.piumsOrange     → #FF6B35 (Primary Brand)
Color.piumsBlue       → #1EAEDB (Secondary/Accent)

// Backgrounds
Color.piumsBackground          → Adaptive dark/light
Color.piumsBackgroundElevated  → Cards/Modals
Color.piumsBackgroundSecondary → Secondary areas

// Text & UI
Color.piumsLabel               → Primary text
Color.piumsLabelSecondary      → Secondary text
Color.piumsSeparator           → Lines/Borders
```

### **Componentes UI Reutilizables**
- **PiumsButton**: Botón principal con loading states
- **ErrorBannerView / SuccessBannerView**: Mensajes de estado
- **LoadingView**: Estado de carga global
- **EmptyStateView**: Estados vacíos con ilustraciones
- **StarRatingView**: Rating de artistas
- **FilterChip**: Chips de filtros removibles

### **Navegación**
**MainTabView (5 tabs):**
1. **Inicio**: Dashboard + calendario + artistas sugeridos
2. **Explorar**: Búsqueda + filtros + SmartSearch
3. **Mi Espacio**: Reservas + Eventos + Favoritos (tabs internos)
4. **Mensajes**: Chat + conversaciones + badge contador
5. **Perfil**: Usuario + configuración + logout

---

## 🌐 **Backend Integration**

### **Base URLs**
- **Desarrollo**: `http://localhost:3005` (API Gateway)
- **Producción**: `https://api.piums.com`

### **Servicios del Backend**
| Servicio | Puerto | Prefijo API | Responsabilidad |
|----------|--------|-------------|-----------------|
| **API Gateway** | 3005 → 3000 | `/api/*` | Enrutamiento central |
| **Auth Service** | 4001 | `/api/auth` | Autenticación, JWT, OAuth |
| **Users Service** | 4002 | `/api/users` | Perfiles, favoritos |
| **Artists Service** | 4003 | `/api/artists` | Datos de artistas |
| **Catalog Service** | 4004 | `/api/catalog` | Servicios, precios |
| **Booking Service** | 4008 | `/api/bookings, /api/events` | Reservas, eventos |
| **Payments Service** | 4005 | `/api/payments` | Pagos, Stripe |
| **Reviews Service** | 4006 | `/api/reviews` | Reseñas, ratings |
| **Search Service** | 4009 | `/api/search` | Búsquedas, SmartSearch |
| **Notifications Service** | 4007 | `/api/notifications` | Notificaciones, push |
| **Chat Service** | 4010 | `/api/chat` | WebSocket, mensajería |

### **Autenticación**
```typescript
// Login response
{
  "token": "JWT_ACCESS_TOKEN",
  "refreshToken": "REFRESH_TOKEN", 
  "user": { id, email, nombre, role: "CLIENT" },
  "redirectUrl": "/dashboard" // Para web
}

// Headers requeridos
Authorization: Bearer JWT_ACCESS_TOKEN
Content-Type: application/json
```

---

## 📋 **Funcionalidades Core**

### **1. Autenticación**
- ✅ **Login**: Email + password con ojito mostrar/ocultar
- ✅ **Google OAuth**: Integración Firebase Auth
- ✅ **Registro**: Nombre, email, password, confirmación
- ✅ **Forgot Password**: Email recovery
- ✅ **JWT Management**: Auto-refresh, secure storage

### **2. Onboarding (3 pasos)**
- ✅ **Paso 1**: Bienvenida + branding
- ✅ **Paso 2**: Selección de intereses creativos
- ✅ **Paso 3**: Refinamiento de gustos + finalización

### **3. Home Dashboard**
- ✅ **Calendario**: Reservas próximas con dots
- ✅ **Artistas sugeridos**: Carrusel horizontal
- ✅ **Quick actions**: Accesos rápidos
- ✅ **Promo banners**: Contenido promocional

### **4. Search & Discovery**
- ✅ **Búsqueda manual**: Filtros por categoría, precio, ubicación
- ✅ **SmartSearch**: Búsqueda inteligente por ubicación + fecha
- ✅ **Filtros avanzados**: Rating, verificados, ordenamiento
- ✅ **Categorías**: Predefinidas (Música, Fotografía, DJ, etc.)

### **5. Booking Flow (3 pasos)**
```
Paso 1: Servicio → Selección del servicio del artista
Paso 2: Fecha → Calendario + slots de tiempo disponibles  
Paso 3: Detalles → Ubicación, notas, cálculo precio
Paso 4: Resumen → Confirmación final + pago
```
- ✅ **Cálculo dinámico**: Precio base + viáticos + días extra
- ✅ **Disponibilidad real**: Slots desde backend
- ✅ **Geolocalización**: Cálculo automático distancia
- ✅ **Vinculación eventos**: Reservas asociadas a eventos

### **6. My Space (3 tabs internos)**
**Reservas**:
- ✅ Estados: Todas, Pendiente, Confirmada, Completada, etc.
- ✅ Detalle completo con timeline de estados
- ✅ Acciones: Cancelar, crear queja, reseña

**Eventos**:
- ✅ CRUD completo de eventos
- ✅ **Agregar reservas existentes** al evento
- ✅ **Crear nuevas reservas** vinculadas al evento
- ✅ Compartir evento, exportar calendario

**Favoritos**:
- ✅ Lista de artistas favoritos
- ✅ Add/remove desde perfiles de artistas
- ✅ Acceso rápido para nueva reserva

### **7. Chat & Notifications**
- ✅ **WebSocket**: Tiempo real
- ✅ **Badge counters**: Mensajes no leídos
- ✅ **Push notifications**: iOS nativas
- ✅ **Conversaciones**: Por reserva/artista

### **8. Disputes (Quejas)**
- ✅ **Crear disputa**: Por reserva con tipos predefinidos
- ✅ **Chat interno**: Mensajería con staff
- ✅ **Estados**: Abierta, En revisión, Resuelta
- ✅ **Prioridades**: Visual según urgencia

---

## 🔗 **APIs y Endpoints Clave**

### **Authentication**
```http
POST /api/auth/login
POST /api/auth/register  
POST /api/auth/forgot-password
POST /api/auth/refresh-token
GET  /api/auth/me
```

### **Search & Artists**
```http
GET  /api/search/artists?q=&page=&limit=&specialty=&city=&minPrice=&maxPrice=
GET  /api/search/smart?q=&limit=&lat=&lng=  # SmartSearch (query params)
GET  /api/artists/{id}
GET  /api/artists/{id}/portfolio
```

### **Bookings & Events**
```http
POST /api/bookings                        # Crear reserva
GET  /api/bookings?status=&page=          # Mis reservas
GET  /api/bookings/{id}                   # Detalle reserva
POST /api/bookings/{id}/cancel            # Cancelar

GET  /api/events                          # Mis eventos  
POST /api/events                          # Crear evento
POST /api/events/{eventId}/bookings/{bookingId}  # Vincular reserva a evento
```

### **Availability & Pricing**
```http
GET  /api/availability/time-slots?artistId=&date=     # Slots disponibles
GET  /api/availability/calendar?artistId=&year=&month= # Calendar view
POST /api/catalog/pricing/calculate                   # Calcular precio
```

### **Favorites & Reviews**
```http
GET  /api/users/me/favorites?entityType=ARTIST
POST /api/users/me/favorites              # Add favorite
DELETE /api/users/me/favorites/{id}       # Remove favorite

POST /api/reviews                         # Crear reseña
GET  /api/reviews?artistId=&page=         # Listar reseñas
```

### **Chat & Notifications**
```http
GET  /api/chat/conversations?page=
GET  /api/chat/conversations/{id}
POST /api/chat/conversations/{id}/messages
WebSocket: /api/chat/ws                   # Real-time

GET  /api/notifications?page=
POST /api/notifications/read              # Mark as read
POST /api/notifications/push-token        # Register device
```

### **Disputes**
```http
GET  /api/disputes/me                     # Mis disputas
POST /api/disputes                        # Crear disputa  
GET  /api/disputes/{id}                   # Detalle
POST /api/disputes/{id}/messages          # Agregar mensaje
```

---

## 📊 **Modelos de Datos Principales**

### **User (Cliente)**
```swift
struct User: Codable {
    let id: String
    let email: String  
    let nombre: String
    let telefono: String?
    let avatar: String?
    let role: String // "CLIENT"
    let isVerified: Bool
    let createdAt: String
}
```

### **Artist**
```swift
struct Artist: Codable {
    let id: String
    let artistName: String
    let bio: String?
    let avatar: String?
    let city: String?
    let category: ArtistCategory // MUSICO, FOTOGRAFO, DJ...
    let specialties: [String]?
    let rating: Double?
    let reviewCount: Int
    let isVerified: Bool
    let isAvailable: Bool
    let portfolio: [PortfolioItem]?
    let services: [ArtistService]?
}
```

### **Booking**
```swift
struct Booking: Codable {
    let id: String
    let code: String? // "PIU-2026-000001"
    let clientId: String
    let artistId: String  
    let serviceId: String
    let status: BookingStatus
    let paymentStatus: PaymentStatus
    let totalPrice: Int // Centavos
    let scheduledDate: String // ISO 8601
    let scheduledTime: String? // "14:00"
    let duration: Int? // Minutos
    let location: String?
    let notes: String?
    let eventId: String? // Vinculación a evento
    let createdAt: String
}
```

### **Event**
```swift
struct EventSummary: Codable {
    let id: String
    let code: String // "PIUE-2026-000001"
    let clientId: String
    let name: String
    let description: String?
    let location: String?
    let eventDate: String?
    let status: EventStatus // ACTIVE, CANCELLED, DRAFT
    let bookings: [EventBooking]?
    let createdAt: String
}
```

### **Estados de Reserva**
```swift
enum BookingStatus: String {
    case pending = "PENDING"
    case confirmed = "CONFIRMED" 
    case paymentPending = "PAYMENT_PENDING"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelledClient = "CANCELLED_CLIENT"
    case cancelledArtist = "CANCELLED_ARTIST"
    case rejected = "REJECTED"
}
```

---

## 🚀 **Guías de Replicación**

## 📱 **Para Android (Kotlin/Compose)**

### **Dependencias Clave**
```kotlin
// Networking
implementation "com.squareup.retrofit2:retrofit:2.9.0"
implementation "com.squareup.okhttp3:logging-interceptor:4.11.0"
implementation "org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.1"

// UI
implementation "androidx.compose.ui:ui:$compose_version"
implementation "androidx.navigation:navigation-compose:2.7.1" 
implementation "androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0"

// Auth & Storage
implementation "androidx.security:security-crypto:1.1.0-alpha06"
implementation "com.google.android.gms:play-services-auth:20.7.0"

// Image Loading
implementation "io.coil-kt:coil-compose:2.4.0"

// WebSocket
implementation "com.squareup.okhttp3:okhttp:4.11.0"

// Maps & Location
implementation "com.google.android.gms:play-services-maps:18.1.0"
implementation "com.google.android.gms:play-services-location:21.0.1"
```

### **Estructura Android**
```
app/src/main/java/com/piums/client/android/
├── MainActivity.kt                    # Single Activity
├── navigation/                        # Navigation Compose
│   ├── PiumsNavGraph.kt
│   └── Screen.kt
├── ui/
│   ├── theme/                        # Colors, Typography, Theme
│   │   ├── Color.kt                  # Piums palette
│   │   └── PiumsTheme.kt
│   ├── components/                   # Reusable components  
│   │   ├── PiumsButton.kt
│   │   ├── PiumsTextField.kt
│   │   └── LoadingView.kt
│   └── screens/                      # Features screens
│       ├── auth/                     # Login, Register, Forgot
│       ├── onboarding/               # 3-step intro
│       ├── home/                     # Dashboard
│       ├── search/                   # Search & filters
│       ├── booking/                  # Booking flow
│       ├── my_space/                 # Bookings, Events, Favorites
│       ├── chat/                     # Messages
│       ├── notifications/            # Notifications center
│       ├── profile/                  # User profile
│       └── disputes/                 # Quejas system
├── data/
│   ├── remote/                       # API clients
│   │   ├── PiumsApiService.kt
│   │   ├── AuthApiService.kt  
│   │   └── dto/                      # Data Transfer Objects
│   ├── local/                        # Local storage
│   │   ├── TokenStorage.kt
│   │   └── UserPreferences.kt
│   └── repository/                   # Repository pattern
│       ├── AuthRepository.kt
│       ├── BookingRepository.kt
│       └── ArtistRepository.kt
├── domain/
│   ├── models/                       # Domain models
│   │   ├── User.kt
│   │   ├── Artist.kt  
│   │   ├── Booking.kt
│   │   └── Event.kt
│   └── usecase/                      # Business logic
│       ├── AuthUseCase.kt
│       └── BookingUseCase.kt
└── utils/
    ├── Constants.kt
    ├── DateUtils.kt
    └── NetworkUtils.kt
```

### **Colores Android (colors.xml)**
```xml
<resources>
    <!-- Piums Brand Colors -->
    <color name="piums_orange">#FF6B35</color>
    <color name="piums_blue">#1EAEDB</color>
    
    <!-- Light Theme -->
    <color name="piums_background_light">#FFFFFF</color>
    <color name="piums_background_elevated_light">#F8F9FA</color>
    <color name="piums_label_light">#1C1C1E</color>
    
    <!-- Dark Theme -->
    <color name="piums_background_dark">#000000</color>
    <color name="piums_background_elevated_dark">#1C1C1E</color>
    <color name="piums_label_dark">#FFFFFF</color>
</resources>
```

---

## 🎨 **Para App de Artistas**

### **Diferencias Funcionales**

**🔄 Funcionalidades Exclusivas de Artistas:**
1. **Dashboard de Performance**
   - Estadísticas de reservas (ingresos, ratings)
   - Calendario de disponibilidad
   - Métricas de conversión

2. **Gestión de Servicios**
   - CRUD de servicios ofrecidos
   - Precios dinámicos y promociones
   - Portfolio multimedia (fotos/videos)

3. **Calendar Management**
   - Bloquear fechas no disponibles
   - Configurar horarios de trabajo
   - Gestión de slots de tiempo

4. **Booking Management**
   - Aceptar/rechazar reservas pendientes
   - Modificar detalles de reservas
   - Comunicación con clientes

5. **Financial Dashboard**
   - Ingresos y proyecciones
   - Historial de pagos
   - Reportes fiscales

### **Flujos Diferentes**

**Onboarding Artistas (5 pasos):**
1. **Bienvenida**: Introducción a la plataforma
2. **Perfil**: Nombre artístico, categoría, ubicación
3. **Servicios**: Configurar servicios y precios
4. **Portfolio**: Subir fotos/videos de trabajos
5. **Verificación**: Documentos y revisión

**Booking Flow (Para Artistas):**
1. **Notificación**: Nueva reserva pendiente
2. **Revisión**: Detalles del evento y cliente
3. **Decisión**: Aceptar/rechazar/negociar
4. **Confirmación**: Detalles finales y preparación

### **APIs Adicionales para Artistas**

```http
# Artist Management
GET  /api/artists/me                          # Mi perfil de artista
PUT  /api/artists/me                          # Actualizar perfil
POST /api/artists/me/services                 # Crear servicio
PUT  /api/artists/me/services/{id}            # Actualizar servicio
DELETE /api/artists/me/services/{id}          # Eliminar servicio

# Portfolio Management  
POST /api/artists/me/portfolio                # Subir media
DELETE /api/artists/me/portfolio/{id}         # Eliminar media

# Availability Management
GET  /api/availability/me                     # Mi disponibilidad
POST /api/availability/me/blocked-dates       # Bloquear fechas
DELETE /api/availability/me/blocked-dates/{id} # Desbloquear

# Booking Management (Artist side)
GET  /api/bookings/incoming                   # Reservas pendientes
POST /api/bookings/{id}/accept                # Aceptar reserva
POST /api/bookings/{id}/reject                # Rechazar reserva
POST /api/bookings/{id}/modify                # Proponer cambios

# Analytics & Reports
GET  /api/analytics/me/dashboard              # Métricas principales
GET  /api/analytics/me/earnings?period=       # Ingresos por período
GET  /api/analytics/me/bookings-stats         # Estadísticas reservas
```

### **Modelos Adicionales - App Artistas**

```swift
// Perfil completo de artista
struct ArtistProfile: Codable {
    let id: String
    let artistName: String
    let realName: String
    let bio: String
    let category: ArtistCategory
    let specialties: [String]
    let city: String
    let avatar: String?
    let coverPhoto: String?
    let isVerified: Bool
    let rating: Double
    let reviewCount: Int
    let joinedAt: String
    let earnings: ArtistEarnings
    let availability: AvailabilitySettings
}

// Configuración de disponibilidad
struct AvailabilitySettings: Codable {
    let workingHours: [DaySchedule]
    let blockedDates: [String]
    let advanceBookingDays: Int
    let autoAccept: Bool
    let minNoticeHours: Int
}

// Analytics del artista
struct ArtistAnalytics: Codable {
    let totalBookings: Int
    let completedBookings: Int
    let totalEarnings: Int
    let currentMonthEarnings: Int
    let averageRating: Double
    let profileViews: Int
    let conversionRate: Double
    let upcomingBookings: Int
}
```

---

## 🔧 **Configuración de Desarrollo**

### **Variables de Entorno**
```bash
# Backend URLs
PIUMS_API_BASE_URL=http://localhost:3005          # Desarrollo
PIUMS_API_BASE_URL=https://api.piums.com          # Producción

# External Services
GOOGLE_CLIENT_ID=your_google_client_id
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_key
FIREBASE_CONFIG=path_to_firebase_config

# Feature Flags
ENABLE_CHAT=true
ENABLE_PUSH_NOTIFICATIONS=true
ENABLE_GOOGLE_AUTH=true
ENABLE_APPLE_AUTH=false
```

### **Secrets y Keys**
```bash
# iOS
GoogleService-Info.plist              # Firebase config
GOOGLE_OAUTH_CLIENT_ID               # Google Sign-In  
APPLE_TEAM_ID                        # Apple Developer

# Android
google-services.json                 # Firebase config
GOOGLE_OAUTH_CLIENT_ID              # Google Sign-In
PLAY_STORE_KEYSTORE                 # Release signing

# Compartidos
STRIPE_PUBLISHABLE_KEY              # Payments
MAPBOX_ACCESS_TOKEN                 # Maps (si se usa)
```

---

## 📋 **Checklist de Implementación**

### **✅ Core Features (Obligatorias)**
- [ ] Sistema de autenticación (Email + Google)
- [ ] Onboarding adaptado al tipo de usuario
- [ ] Navegación principal (Bottom Navigation)
- [ ] Búsqueda y filtros de artistas/clientes
- [ ] Booking flow completo
- [ ] Chat en tiempo real
- [ ] Notificaciones push
- [ ] Sistema de favoritos
- [ ] Perfil de usuario
- [ ] Dark/Light mode support

### **✅ Advanced Features (Recomendadas)**  
- [ ] SmartSearch con geolocalización
- [ ] Sistema de eventos (solo clientes)
- [ ] Calendario de disponibilidad (solo artistas)
- [ ] Sistema de disputas/quejas
- [ ] Analytics dashboard (solo artistas)
- [ ] Payment integration (Stripe)
- [ ] Reviews y ratings
- [ ] Compartir contenido

### **✅ Platform Specific**
**iOS:**
- [ ] Widget de próximas reservas
- [ ] Siri Shortcuts para acciones comunes
- [ ] Apple Pay integration
- [ ] Face ID/Touch ID para auth

**Android:**
- [ ] Adaptive icons
- [ ] Notification channels
- [ ] Google Pay integration
- [ ] Biometric authentication

---

## 🎯 **Notas de Implementación**

### **Prioridades por Fase**

**Fase 1 - MVP (4-6 semanas)**
1. Auth + Onboarding
2. Navegación básica
3. Búsqueda simple
4. Booking flow básico
5. Perfil de usuario

**Fase 2 - Core Features (6-8 semanas)**  
1. Chat implementado
2. Notificaciones push
3. Favoritos system
4. Reviews y ratings
5. Payment integration

**Fase 3 - Advanced (4-6 semanas)**
1. SmartSearch + Geolocation
2. Eventos system (clientes)
3. Analytics (artistas)  
4. Sistema de disputas
5. Optimizaciones performance

### **Consideraciones Técnicas**

1. **State Management**
   - iOS: `@Observable` + SwiftUI
   - Android: `ViewModel` + StateFlow + Compose

2. **Networking**
   - JWT auto-refresh implementado
   - Error handling consistente
   - Offline capability (opcional)

3. **Real-time Features**
   - WebSocket para chat
   - Server-Sent Events para notificaciones
   - Background sync para mensajes

4. **Performance**
   - Image caching (Kingfisher/Coil)
   - Pagination en todas las listas
   - Lazy loading de contenido

---

## 📞 **Contacto y Soporte**

**Para preguntas técnicas o aclaraciones sobre la implementación:**
- Revisar el código fuente en el repositorio
- Consultar la documentación del backend en `/piums-platform`
- Los endpoints están documentados en el código (`APIEndpoint.swift`)

---

**📅 Última actualización**: Abril 13, 2026  
**🔄 Versión**: 1.0.0  
**👨‍💻 Maintainer**: Piums Development Team

---

> **💡 Tip**: Este documento debe actualizarse cada vez que se agreguen nuevas funcionalidades o cambios significativos en la arquitectura.