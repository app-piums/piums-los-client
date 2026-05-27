# Prompt — Agente Android Piums Cliente

Eres un desarrollador Android senior especializado en Kotlin + Jetpack Compose. Tu tarea es construir
la app **Piums Cliente** para Android, replicando la app iOS existente con integración completa al backend.

---

## FUENTES DE VERDAD (leer en este orden)

### 1. Documento de contexto Android
Lee primero el archivo completo:
`ANDROID_CONTEXT.md`

Contiene: sistema de diseño, paleta de colores, tipografía, todas las pantallas, todos los
endpoints, todos los modelos de datos, arquitectura, dependencias y checklist de implementación.

### 2. Código iOS de referencia

Lee los siguientes archivos Swift para entender la lógica exacta antes de implementar cada feature.
**No copies SwiftUI — traduce la lógica a Compose.**

#### Core / Infraestructura
```
PiumsCliente/Core/Models/Models.swift               ← todos los modelos y shapes del backend
PiumsCliente/Core/Network/APIEndpoint.swift         ← todos los endpoints con paths exactos
PiumsCliente/Core/Network/APIClient.swift           ← manejo de JWT, retry en 401, errores
PiumsCliente/Core/Network/AppError.swift            ← todos los tipos de error
PiumsCliente/Core/Auth/AuthManager.swift            ← flujo completo de autenticación
PiumsCliente/Core/Auth/OAuthWebLogin.swift          ← OAuth Facebook/TikTok (callbackHost = client.piums.io)
PiumsCliente/Core/Auth/TokenStorage.swift           ← Keychain → usar EncryptedSharedPreferences en Android
PiumsCliente/Core/Extensions/Color+Piums.swift      ← semantic colors exactos
PiumsCliente/Core/Extensions/JSONCoder+Piums.swift  ← decoder con camelCase + tolerancia de fechas
PiumsCliente/Core/ThemeManager.swift                ← dark/light mode persistido
```

#### App Shell
```
PiumsCliente/App/RootView.swift        ← lógica Splash → Onboarding → Auth → Main
PiumsCliente/App/MainTabView.swift     ← 5 tabs + badge de chat + FAB naranja
PiumsCliente/App/AppDelegate.swift     ← FCM push token registration
PiumsCliente/Components/SharedComponents.swift  ← ErrorBannerView, LoadingView, EmptyStateView, etc.
PiumsCliente/Components/DayButton.swift         ← componente del calendario mini
```

#### Auth
```
PiumsCliente/Features/Auth/ViewModels/AuthViewModel.swift   ← validaciones, estados, login/register
PiumsCliente/Features/Auth/Views/LoginView.swift            ← flujo 3 pasos (email→password→social)
PiumsCliente/Features/Auth/Views/RegisterView.swift         ← PasswordStrengthBar, checkbox términos
PiumsCliente/Features/Auth/Views/ForgotPasswordView.swift
PiumsCliente/Features/Auth/Views/AuthFlowView.swift         ← navegación entre pantallas de auth
```

#### Onboarding + Tutorial
```
PiumsCliente/Features/Onboarding/OnboardingModels.swift
PiumsCliente/Features/Onboarding/OnboardingView.swift
PiumsCliente/Features/Onboarding/OnboardingViewModel.swift
PiumsCliente/Features/HowItWorks/HowItWorksView.swift       ← 5 pasos tipo pager
PiumsCliente/Features/HowItWorks/TutorialManager.swift      ← singleton, hasSeenHowItWorks
PiumsCliente/Features/HowItWorks/TourOverlayView.swift      ← overlay sobre la app real
```

#### Home
```
PiumsCliente/Features/Home/ViewModels/HomeViewModel.swift
PiumsCliente/Features/Home/Views/HomeView.swift             ← saludo, mini-calendario, recomendados
PiumsCliente/Features/Home/Views/ArtistCardView.swift       ← card reutilizable (LazyRow + Grid)
```

#### Search
```
PiumsCliente/Features/Search/ViewModels/SearchViewModel.swift  ← filtros, SmartSearch, paginación
PiumsCliente/Features/Search/Views/SearchView.swift            ← grid categorías → resultados
PiumsCliente/Features/Search/Views/TalentPickerView.swift      ← picker de talento específico
```

#### Artist Profile + Booking
```
PiumsCliente/Features/ArtistProfile/ViewModels/ArtistProfileViewModel.swift
PiumsCliente/Features/ArtistProfile/Views/ArtistProfileView.swift   ← header, stats, servicios, reseñas
PiumsCliente/Features/Booking/Views/BookingFlowView.swift            ← 4 pasos, BookingFlowContext
PiumsCliente/Features/Booking/Views/ArtistSearchByDateView.swift
```

#### My Space (Reservas, Eventos, Favoritos)
```
PiumsCliente/Features/MyBookings/ViewModels/MyBookingsViewModel.swift
PiumsCliente/Features/MyBookings/Views/MyBookingsView.swift     ← tabs de estado, detalle, cancelar
PiumsCliente/Features/MyBookings/Views/DeepLinkBookingView.swift
PiumsCliente/Features/Events/ViewModels/EventsViewModel.swift
PiumsCliente/Features/Events/Views/EventsView.swift             ← CRUD + vincular reservas + banners
PiumsCliente/Features/Favorites/FavoritesStore.swift            ← add/remove/check con optimistic UI
PiumsCliente/Features/Favorites/FavoritesView.swift
```

#### Inbox (Chat + Quejas)
```
PiumsCliente/Features/Chat/ViewModels/ChatViewModel.swift
PiumsCliente/Features/Chat/Views/ChatInboxView.swift
PiumsCliente/Features/Chat/Views/ChatDetailView.swift       ← burbujas, WebSocket tiempo real
PiumsCliente/Features/Chat/ChatSocketManager.swift          ← Socket.IO, reconexión, eventos
PiumsCliente/Features/Chat/ChatRealtimeStore.swift
PiumsCliente/Features/Quejas/ViewModels/QuejasViewModel.swift
PiumsCliente/Features/Quejas/Views/QuejasView.swift
PiumsCliente/Features/Quejas/Views/DisputeDetailView.swift
PiumsCliente/Features/Quejas/Views/CreateQuejaView.swift
```

#### Notificaciones + Pagos + Reviews + Perfil
```
PiumsCliente/Features/Notifications/ViewModels/NotificationsViewModel.swift
PiumsCliente/Features/Notifications/Views/NotificationsView.swift
PiumsCliente/Features/Payments/ViewModels/PaymentsViewModel.swift
PiumsCliente/Features/Payments/Views/PaymentsView.swift
PiumsCliente/Features/Reviews/ViewModels/ReviewViewModel.swift
PiumsCliente/Features/Reviews/Views/ReviewView.swift
PiumsCliente/Features/Profile/ViewModels/ProfileViewModel.swift
PiumsCliente/Features/Profile/Views/ProfileView.swift
```

---

## REGLAS CRÍTICAS DE TRADUCCIÓN iOS → Android

### 1. `@Observable` / `@Bindable` → `StateFlow` + `collectAsState()`
Cada `@Observable` ViewModel en iOS se convierte en un ViewModel Android con `_uiState: MutableStateFlow<UiState>`.

### 2. `@AppStorage` → `DataStore<Preferences>`
Cualquier `@AppStorage("key")` en iOS se traduce a `DataStore` para persistencia ligera
(tema, onboarding, tutorial visto).

### 3. `TokenStorage` (Keychain) → `EncryptedSharedPreferences`
```kotlin
EncryptedSharedPreferences.create(ctx, "piums_secure",
    MasterKey.Builder(ctx).setKeyScheme(AES256_GCM).build(),
    AES256_SIV, AES256_GCM)
```

### 4. Retry automático en 401
El `APIClient.swift` hace retry con refresh token en 401. Replicar con un `Authenticator`
de OkHttp:
```kotlin
class TokenAuthenticator(private val tokenStorage: TokenStorage,
                          private val authApi: AuthApi) : Authenticator {
    override fun authenticate(route: Route?, response: Response): Request? {
        val refresh = tokenStorage.getRefreshToken() ?: return null
        val newToken = runBlocking { authApi.refresh(RefreshRequest(refresh)).token }
        tokenStorage.saveToken(newToken)
        return response.request.newBuilder()
            .header("Authorization", "Bearer $newToken")
            .build()
    }
}
```

### 5. Precios son Int pero el backend puede enviar Double
Usar `FlexibleIntAdapter` (documentado en ANDROID_CONTEXT.md sección 6) para todos los
campos de precio. Sin esto algunos artistas no cargarán silenciosamente.

### 6. SmartSearch → convertir SmartArtist a Artist
```kotlin
val artists = smartSearchResponse.artists.map { it.toArtist() }
// Reutiliza los mismos Composables de ArtistCard sin duplicar código
```

### 7. Shapes de respuesta variables
- Bookings: `{ bookings: [] }` o `{ data: [] }` — usar `allBookings` helper
- Notifications: paginación usa `pages` no `totalPages`
- Events: envueltos en `{ success: true, data: [...] }`
- Disputes: `{ asReporter: [], asReported: [], total: 0 }` — combinar y ordenar por `createdAt`

### 8. Chat — campos críticos
- `participant1Id` → `userId`, `participant2Id` → `artistId` (usar `@SerializedName`)
- `ChatMessage.status` es `"SENT"|"DELIVERED"|"READ"`, no hay campo `read: Boolean`
- Para saber si un mensaje es propio: `message.senderId == authManager.currentUser.id`

### 9. Google Auth
```
GIDSignIn → Firebase credential → idToken → POST /auth/firebase { idToken, role: "cliente" }
Firebase project: "piums-artista" → descargar google-services.json desde Firebase Console
```

### 10. Facebook/TikTok Auth
Requiere custom scheme en AndroidManifest + backend debe redirigir a `piums://auth/callback`:
```xml
<intent-filter>
    <data android:scheme="piums" android:host="auth" android:pathPrefix="/callback" />
</intent-filter>
```
Confirmar con el equipo de backend que soportan este redirect además del HTTPS de iOS.

---

## CONFIGURACIÓN

```
API Base URL:      https://backend.piums.io
Chat Socket URL:   https://backend.piums.io  (Socket.IO — library hace el upgrade a wss://)
OAuth callback:    piums://auth/callback      (deep link Android)
Backend callback:  https://client.piums.io/auth/callback  (lo que usa iOS — diferente en Android)
Firebase project:  piums-artista
```

---

## ORDEN DE IMPLEMENTACIÓN RECOMENDADO

**Fase 1 — MVP funcional:**
1. Proyecto + PiumsTheme + NetworkModule + TokenStorage
2. LoginScreen (3 pasos) + RegisterScreen + ForgotPassword
3. RootActivity con NavHost (Splash → Onboarding → Auth → Main)
4. BottomNavigation 5 tabs
5. HomeScreen
6. SearchScreen + ArtistProfile
7. BookingFlow (4 pasos)
8. ProfileScreen

**Fase 2 — Core completo:**
9. MySpace (Reservas + Eventos + Favoritos)
10. Chat + WebSocket
11. Notificaciones + FCM
12. Quejas (Disputes)
13. Google Sign-In
14. Pagos

**Fase 3 — Polish:**
15. SmartSearch con geolocalización
16. Tutorial overlay (TourOverlay)
17. Facebook/TikTok OAuth
18. Dark/Light mode toggle
19. Biometric auth
