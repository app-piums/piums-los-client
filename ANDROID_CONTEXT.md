# ANDROID_CONTEXT.md — Piums Cliente Android
> Referencia completa para replicar la app iOS en Android con Jetpack Compose.
> Última actualización: Abril 2026

---

## 1. VISIÓN GENERAL

**App**: Piums Cliente — marketplace de servicios creativos  
**Rol del usuario**: Cliente que busca y reserva artistas para eventos  
**Stack Android**: Kotlin + Jetpack Compose + MVVM + Hilt  
**Backend**: REST API en `https://api.piums.com` (dev: `http://localhost:3005`)  
**Auth**: JWT Bearer Token + Google Firebase OAuth

---

## 2. SISTEMA DE DISEÑO

### 2.1 Paleta de Colores

```kotlin
// ui/theme/Color.kt
val PiumsOrange       = Color(0xFFFF6B35)   // #FF6B35 — color primario de marca
val PiumsOrangeDim    = Color(0x80FF6B35)   // 50% opacidad — botón deshabilitado
val PiumsDark         = Color(0xFF1A1A1A)

// Dark Mode — equivalentes exactos de los semantic colors iOS
val PageBackground    = Color(0xFF1C1C1E)   // secondarySystemGroupedBackground
val CardBackground    = Color(0xFF2C2C2E)   // tertiarySystemGroupedBackground
val InputBackground   = Color(0xFF3A3A3C)   // systemGray6 en dark

// Light Mode
val PageBackgroundLight = Color(0xFFFFFFFF)
val CardBackgroundLight = Color(0xFFF2F2F7)
val InputBackgroundLight = Color(0xFFEFEFF4)
```

```kotlin
// ui/theme/PiumsTheme.kt
private val DarkColorScheme = darkColorScheme(
    primary        = PiumsOrange,
    background     = PageBackground,        // #1C1C1E
    surface        = CardBackground,        // #2C2C2E
    surfaceVariant = Color(0xFF3A3A3C),
    onBackground   = Color.White,
    onSurface      = Color.White,
    secondary      = Color(0xFF3A6AFF),
    outline        = Color(0xFF48484A)
)

private val LightColorScheme = lightColorScheme(
    primary        = PiumsOrange,
    background     = PageBackgroundLight,
    surface        = CardBackgroundLight,
    onBackground   = Color(0xFF1C1C1E),
    onSurface      = Color(0xFF1C1C1E),
    secondary      = Color(0xFF3A6AFF),
    outline        = Color(0xFFD1D1D6)
)

@Composable
fun PiumsTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    MaterialTheme(colorScheme = colorScheme, typography = PiumsTypography, content = content)
}
```

### 2.2 Tipografía

```kotlin
// ui/theme/Type.kt
val PiumsTypography = Typography(
    headlineLarge  = TextStyle(fontSize = 30.sp, fontWeight = FontWeight.Bold),
    headlineMedium = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.Bold),
    titleLarge     = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold),
    titleMedium    = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge      = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.Normal),
    bodyMedium     = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Normal),
    labelSmall     = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                               letterSpacing = 0.8.sp)
)
```

### 2.3 Regla de Superficies (equivalente iOS)

| Rol            | iOS                              | Android (dark)  | Android (light) |
|----------------|----------------------------------|-----------------|-----------------|
| Fondo de página | `secondarySystemGroupedBackground` | `#1C1C1E`       | `#FFFFFF`       |
| Cards / filas  | `tertiarySystemGroupedBackground`  | `#2C2C2E`       | `#F2F2F7`       |
| Inputs         | `systemGray6`                    | `#3A3A3C`       | `#EFEFF4`       |
| Nav bar        | `secondarySystemGroupedBackground` | `#1C1C1E`       | `#FFFFFF`       |

### 2.4 Shape & Spacing

```kotlin
// Radios de esquina
val radiusCard   = 14.dp   // Cards de artistas, filas de reserva
val radiusInput  = 12.dp   // Campos de texto
val radiusButton = 14.dp   // Botón principal
val radiusSheet  = 32.dp   // Bottom sheets

// Padding estándar de página
val paddingPage  = 20.dp
val paddingCard  = 16.dp
```

---

## 3. PANTALLA DE LOGIN (Referencia visual exacta)

### Diseño (replicar pixel-perfect del artista iOS)

```
┌────────────────────────────────┐
│  (fondo oscuro degradado)      │
│                                │
│         [PiumsLogo]            │  ← logo centrado, height: 44dp
│                                │
│    ┌──────────────────────┐    │
│    │  ⬤ (ícono ticket)   │    │  ← círculo doble, 110dp
│    └──────────────────────┘    │
│                                │
│    "Panel de Clientes"         │  ← title2.bold, blanco
│  "Reserva el mejor talento"    │  ← subheadline, white 50%
│                                │
├────────────────────────────────┤  ← card oscura R=32dp desliza arriba
│  ———  (drag indicator)         │
│                                │
│  Bienvenido de nuevo           │  ← headline bold
│  Accede a tu panel...          │  ← body, secondary
│                                │
│  CORREO                        │  ← caption bold, tracking
│  [nombre@ejemplo.com       ]   │  ← input R=12dp
│                                │
│  CONTRASEÑA                    │
│  [••••••••          👁]        │
│         ¿Olvidaste tu...?      │  ← naranja, trailing
│                                │
│  [    Iniciar sesión    ]       │  ← naranja R=14dp, h=54dp
│                                │
│  ─────  O CONTINUAR CON  ───── │
│                                │
│  [G Continuar con Google] [🍎] │
│                                │
│  ¿Aún no tienes cuenta?        │
│  Regístrate gratis             │  ← naranja
└────────────────────────────────┘
```

```kotlin
// screens/auth/LoginScreen.kt
@Composable
fun LoginScreen(viewModel: AuthViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsState()
    var animateIn by remember { mutableStateOf(false) }
    // Pulso infinito para orbes de luz ambiental
    val infiniteTransition = rememberInfiniteTransition(label = "glow")
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.10f, targetValue = 0.20f,
        animationSpec = infiniteRepeatable(
            animation = tween(3200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ), label = "glowAlpha"
    )

    LaunchedEffect(Unit) { animateIn = true }

    Box(modifier = Modifier.fillMaxSize()) {
        LoginBackground(animateIn = animateIn, glowAlpha = glowAlpha)

        val offsetY by animateDpAsState(
            targetValue = if (animateIn) 0.dp else 600.dp,
            animationSpec = spring(dampingRatio = 0.85f, stiffness = 190f),
            label = "sheet"
        )
        Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.Bottom) {
            LoginSheet(
                modifier = Modifier.offset(y = offsetY),
                uiState = uiState,
                onLoginClick = { viewModel.login() },
                onGoogleClick = { viewModel.loginWithGoogle() },
                onForgotClick = { /* navigate */ },
                onRegisterClick = { /* navigate */ }
            )
        }
    }
}

@Composable
private fun LoginBackground(animateIn: Boolean, glowAlpha: Float) {
    Box(modifier = Modifier.fillMaxSize()) {

        // Gradiente base — cálido oscuro marrón/negro, igual que app de artistas
        Box(modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF0F0A08),  // marrón muy oscuro arriba
                        Color(0xFF170E09),  // marrón ligeramente más cálido
                        Color(0xFF0F0A08)   // igual abajo
                    )
                )
            )
        )

        // Glow naranja central detrás del ícono — produce el tono marrón cálido
        Box(modifier = Modifier
            .size(320.dp)
            .align(Alignment.TopCenter)
            .offset(y = (-80).dp)
            .blur(80.dp)
            .background(PiumsOrange.copy(alpha = glowAlpha), CircleShape)
        )
        // Glow naranja sutil abajo
        Box(modifier = Modifier
            .size(220.dp)
            .align(Alignment.TopCenter)
            .offset(x = 60.dp, y = 100.dp)
            .blur(70.dp)
            .background(PiumsOrange.copy(alpha = glowAlpha * 0.4f), CircleShape)
        )

        // Contenido superior centrado
        val logoAlpha by animateFloatAsState(if (animateIn) 1f else 0f,
            animationSpec = tween(500, delayMillis = 50), label = "logo")
        val iconScale by animateFloatAsState(if (animateIn) 1f else 0.5f,
            animationSpec = spring(dampingRatio = 0.68f, stiffness = 220f), label = "icon")
        val textAlpha by animateFloatAsState(if (animateIn) 1f else 0f,
            animationSpec = tween(600, delayMillis = 220), label = "text")

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(top = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Logo
            Image(
                painter = painterResource(R.drawable.piums_logo),
                contentDescription = null,
                modifier = Modifier.height(38.dp).alpha(logoAlpha)
            )

            Spacer(Modifier.height(32.dp))

            // Ícono — círculo marrón cálido oscuro + ícono naranja (igual que artistas)
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .scale(iconScale)
                    .alpha(iconScale)
            ) {
                // Halo glow naranja difuso detrás
                Box(Modifier
                    .size(130.dp)
                    .blur(18.dp)
                    .background(PiumsOrange.copy(alpha = glowAlpha), CircleShape)
                )
                // Círculo principal — marrón cálido oscuro (#381E0F)
                Box(Modifier
                    .size(100.dp)
                    .background(Color(0xFF381E0F), CircleShape)
                )
                Icon(
                    Icons.Default.ConfirmationNumber, null,
                    tint = PiumsOrange,
                    modifier = Modifier.size(36.dp)
                )
            }

            Spacer(Modifier.height(24.dp))

            // Título con glow sutil
            Text(
                "Panel de Clientes",
                style = MaterialTheme.typography.headlineSmall,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.alpha(textAlpha)
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "Reserva el mejor talento\npara tu evento",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(0.45f),
                textAlign = TextAlign.Center,
                lineHeight = 20.sp,
                modifier = Modifier.alpha(textAlpha)
            )
        }
    }
}

@Composable
private fun LoginSheet(
    modifier: Modifier = Modifier,
    uiState: AuthUiState,
    onLoginClick: () -> Unit,
    onGoogleClick: () -> Unit,
    onForgotClick: () -> Unit,
    onRegisterClick: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }

    val isEmpty = email.isBlank() || password.isBlank()

    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 0.dp,
        border = BorderStroke(
            width = 1.dp,
            brush = Brush.verticalGradient(
                listOf(PiumsOrange.copy(0.35f), Color.Transparent),
                endY = 200f
            )
        )
    ) {
        Column {
            // Handle
            Box(Modifier.fillMaxWidth().padding(top = 14.dp), Alignment.Center) {
                Box(Modifier.size(width = 36.dp, height = 4.dp)
                    .background(Color.White.copy(0.18f), RoundedCornerShape(2.dp)))
            }
            Spacer(Modifier.height(28.dp))

            LazyColumn(
                contentPadding = PaddingValues(horizontal = 26.dp, bottom = 50.dp),
                verticalArrangement = Arrangement.spacedBy(28.dp)
            ) {
                item {
                    Text("Bienvenido de nuevo",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(6.dp))
                    Text("Accede a tu panel de control.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(0.5f))
                }
                item {
                    // Campo Email
                    PiumsAuthField(
                        label = "CORREO",
                        value = email,
                        onValueChange = { email = it },
                        placeholder = "nombre@ejemplo.com",
                        isFocused = emailFocused,
                        onFocusChange = { emailFocused = it },
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Email,
                            imeAction = ImeAction.Next
                        )
                    )
                    Spacer(Modifier.height(14.dp))
                    // Campo Password
                    PiumsAuthField(
                        label = "CONTRASEÑA",
                        value = password,
                        onValueChange = { password = it },
                        placeholder = "••••••••",
                        isFocused = passwordFocused,
                        onFocusChange = { passwordFocused = it },
                        isPassword = true,
                        showPassword = showPassword,
                        onTogglePassword = { showPassword = !showPassword },
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Done
                        ),
                        onDone = onLoginClick
                    )
                    Spacer(Modifier.height(4.dp))
                    Box(Modifier.fillMaxWidth(), Alignment.CenterEnd) {
                        TextButton(onClick = onForgotClick) {
                            Text("¿Olvidaste tu contraseña?",
                                color = PiumsOrange,
                                style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
                if (uiState.error != null) {
                    item { ErrorBanner(uiState.error) }
                }
                item {
                    // Botón login con gradiente y sombra naranja
                    val gradient = if (isEmpty)
                        SolidColor(PiumsOrange.copy(0.45f))
                    else
                        Brush.linearGradient(listOf(PiumsOrange, Color(0xFF FF8438)))
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(54.dp)
                            .shadow(if (isEmpty) 0.dp else 14.dp, RoundedCornerShape(14.dp),
                                ambientColor = PiumsOrange, spotColor = PiumsOrange)
                            .background(gradient, RoundedCornerShape(14.dp))
                            .clickable(enabled = !isEmpty && !uiState.isLoading) { onLoginClick() },
                        contentAlignment = Alignment.Center
                    ) {
                        if (uiState.isLoading) {
                            Row(verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                CircularProgressIndicator(color = Color.White,
                                    modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                                Text("Iniciando sesión…", color = Color.White,
                                    fontWeight = FontWeight.Bold)
                            }
                        } else {
                            Text("Iniciar sesión", color = Color.White, fontWeight = FontWeight.Bold)
                        }
                    }
                }
                item {
                    // Divisor
                    Row(verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Divider(Modifier.weight(1f), color = Color.Gray.copy(0.2f))
                        Text("O CONTINUAR CON", style = MaterialTheme.typography.labelSmall,
                            color = Color.Gray, letterSpacing = 0.8.sp)
                        Divider(Modifier.weight(1f), color = Color.Gray.copy(0.2f))
                    }
                }
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        // Google
                        Surface(
                            modifier = Modifier.weight(1f).height(52.dp),
                            shape = RoundedCornerShape(13.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            onClick = onGoogleClick
                        ) {
                            Row(Modifier.padding(horizontal = 16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.Center) {
                                Box(Modifier.size(30.dp)
                                    .background(Color.Gray.copy(0.2f), RoundedCornerShape(7.dp)),
                                    Alignment.Center) {
                                    Text("G", fontWeight = FontWeight.Bold,
                                        color = Color(0xFF4285F4), fontSize = 15.sp)
                                }
                                Spacer(Modifier.width(10.dp))
                                Text("Continuar con Google",
                                    style = MaterialTheme.typography.labelLarge)
                            }
                        }
                        // Apple
                        Surface(
                            modifier = Modifier.size(52.dp),
                            shape = RoundedCornerShape(13.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            onClick = { /* próximamente */ }
                        ) {
                            Box(Modifier.fillMaxSize(), Alignment.Center) {
                                Icon(Icons.Default.Apple, null)
                            }
                        }
                    }
                }
                item {
                    Row(Modifier.fillMaxWidth(), Arrangement.Center) {
                        Text("¿Aún no tienes cuenta? ",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(0.5f))
                        Text("Regístrate gratis",
                            style = MaterialTheme.typography.bodySmall,
                            color = PiumsOrange, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clickable { onRegisterClick() })
                    }
                }
            }
        }
    }
}

// Campo reutilizable con borde naranja al enfocar
@Composable
fun PiumsAuthField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    isFocused: Boolean,
    onFocusChange: (Boolean) -> Unit,
    isPassword: Boolean = false,
    showPassword: Boolean = false,
    onTogglePassword: (() -> Unit)? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    onDone: (() -> Unit)? = null
) {
    val borderColor by animateColorAsState(
        if (isFocused) PiumsOrange.copy(0.7f) else Color.Transparent,
        animationSpec = tween(200), label = "border"
    )
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Text(label, style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(0.5f))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(13.dp))
                .border(1.5.dp, borderColor, RoundedCornerShape(13.dp))
                .padding(horizontal = 16.dp, vertical = 15.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val visual = if (isPassword && !showPassword) PasswordVisualTransformation()
                         else VisualTransformation.None
            BasicTextField(
                value = value, onValueChange = onValueChange,
                modifier = Modifier.weight(1f).onFocusChanged { onFocusChange(it.isFocused) },
                visualTransformation = visual,
                keyboardOptions = keyboardOptions,
                keyboardActions = KeyboardActions(onDone = { onDone?.invoke() }),
                textStyle = MaterialTheme.typography.bodyLarge.copy(
                    color = MaterialTheme.colorScheme.onSurface
                ),
                decorationBox = { inner ->
                    if (value.isEmpty()) Text(placeholder,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface.copy(0.35f))
                    inner()
                }
            )
            if (isPassword && onTogglePassword != null) {
                IconButton(onClick = onTogglePassword, modifier = Modifier.size(24.dp)) {
                    Icon(
                        if (showPassword) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                        null,
                        tint = if (isFocused) PiumsOrange.copy(0.8f)
                               else MaterialTheme.colorScheme.onSurface.copy(0.4f)
                    )
                }
            }
        }
    }
}
```

### Reglas críticas del botón de login

```kotlin
// Botón: gradiente naranja cuando activo, semitransparente cuando vacío, sombra naranja
val isEmpty = email.isBlank() || password.isBlank()
val gradient = if (isEmpty)
    SolidColor(PiumsOrange.copy(alpha = 0.45f))
else
    Brush.linearGradient(listOf(PiumsOrange, Color(0xFFFF8438)))

// Sombra naranja solo cuando habilitado:
Modifier.shadow(if (isEmpty) 0.dp else 14.dp, RoundedCornerShape(14.dp),
    ambientColor = PiumsOrange, spotColor = PiumsOrange)
```

### RegisterScreen

Mismo fondo/estilo que LoginScreen (dark, glow naranja, card oscura). Campos: Nombre, Email, Contraseña (con show/hide), Confirmar contraseña (borde rojo si no coincide). Extras:

- **PasswordStrengthBar**: 5 cápsulas de colores (rojo→verde) según complejidad (longitud ≥8/12, mayúscula, número, símbolo). Aparece al escribir la contraseña.
- **Checkbox términos**: obligatorio antes de enviar. Borde naranja al marcar. Texto: "Acepto los **Términos y condiciones** y la **Política de privacidad** de Piums."
- **Botón "Crear cuenta"**: deshabilitado si algún campo vacío o términos no aceptados (opacity 35%).
- `POST /api/auth/register/client` body: `{nombre, email, password}`
- Al completar, el backend devuelve `AuthResponse` con token → login automático.

---

## 4. NAVEGACIÓN PRINCIPAL

### Bottom Navigation (5 tabs — igual que iOS)

```kotlin
// navigation/Screen.kt
sealed class Screen(val route: String, val label: String, val icon: ImageVector) {
    object Home     : Screen("home",      "Inicio",     Icons.Filled.Home)
    object Search   : Screen("search",    "Explorar",   Icons.Filled.Search)
    object MySpace  : Screen("my_space",  "Mi Espacio", Icons.Filled.GridView)
    object Inbox    : Screen("inbox",     "Mensajes",   Icons.Filled.Message)
    object Profile  : Screen("profile",   "Perfil",     Icons.Filled.Person)
}
```

```kotlin
// Tint del tab seleccionado = PiumsOrange
// FAB naranja flotante encima del tab bar (igual que iOS)
```

---

## 5. FEATURES Y PANTALLAS

### 5.1 Onboarding (3 pasos — mostrar solo primera vez)

| Paso | Contenido iOS | Android equivalente |
|------|--------------|---------------------|
| 1 | Bienvenida + logo + animación | `AnimatedVisibility` + Pager |
| 2 | Selección de intereses (chips) | `FlowRow` con `FilterChip` |
| 3 | Refinamiento + finalización | Confirmación + `POST /api/auth/complete-onboarding` |

- Guardar `hasSeenOnboarding` en `DataStore<Preferences>`

### 5.1b Tutorial "¿Cómo funciona Piums?"

Pantalla con 5 pasos tipo pager (BottomSheet o FullScreen). Se muestra automáticamente la primera vez que el usuario entra a la app principal (0.8s delay). También accesible desde Perfil → Ayuda.

| Paso | Ícono (MD) | Título | Descripción |
|------|-----------|--------|-------------|
| 1 | `Search` | Explora el talento | Busca artistas por especialidad, ciudad y precio. Filtra por disponibilidad y calificación. |
| 2 | `CalendarMonth` | Elige tu fecha | Selecciona día y hora. Verás la disponibilidad en tiempo real. |
| 3 | `VerifiedUser` | Reserva en segundos | Envía tu solicitud. El artista la confirmará a la brevedad. |
| 4 | `Forum` | Chatea y coordina | Habla directamente con el artista para afinar los detalles. |
| 5 | `Star` | Disfruta y califica | Al finalizar, comparte tu opinión para ayudar a otros usuarios. |

- Guardar `hasSeenHowItWorks` en `DataStore<Preferences>`
- Botón "Siguiente →" / "¡Empezar ahora!" en el último paso
- Botón "Omitir tutorial" en pasos 1-4
- Barra de progreso naranja + dots animados

### 5.2 Home

```
Saludo "Hola, {nombre} 👋"  
Mini-calendario horizontal (reservas = dots naranjas)  
Sección "Recomendados" — horizontal LazyRow de ArtistCard  
PromoBanner naranja  
```

- Datos: `GET /api/auth/me` (nombre) + `GET /api/bookings?page=1` (fechas para calendario)
- Pull-to-refresh con `SwipeRefresh` (Accompanist)

### 5.3 Search & Discovery

**Estado inicial** — Grid de categorías (3 columnas):
```
Música | DJ | Fotografía | Baile | Maquillaje | Tatuajes
Iluminación | Bodas | Quinceañeras | Corporativo | Barbería | Shows
```

**Búsqueda activa** — Grid 2 columnas de `ArtistCard`

**SmartSearch**: usar `GET /api/search/smart?q=&lat=&lng=` si el usuario da permisos de ubicación

**Filtros sheet** (BottomSheet):
- Especialidad (chips)
- Rango precio (RangeSlider)
- Rating mínimo (chips: Todos, 3.0★, 3.5★, 4.0★, 4.5★, 5.0★)
- Ciudad (chips)
- Solo verificados (Switch)
- Ordenar por (RadioGroup)

### 5.4 Perfil de Artista

```
Header: avatar + nombre + ciudad + verificado ✓
Stats bar: Rating | Reseñas | Verificado
Bio text
Lista de servicios (seleccionable → highlight naranja)
Lista de reseñas
Galería horizontal (portfolio)
FAB "Contratar" sticky al fondo → abre BookingFlow
```

- `GET /api/artists/{id}` (profile completo — solo disponible en detalle)
- `GET /api/catalog/services?artistId={id}`
- `GET /api/reviews?artistId={id}&page=1`
- `GET /api/artists/{id}/portfolio`

### 5.5 Booking Flow (4 pasos en BottomSheet / pantalla)

```
Paso 1 → Servicio (ya viene seleccionado desde ArtistProfile)
Paso 2 → Fecha: calendario + slots de tiempo
          GET /api/availability/calendar?artistId=&year=&month=
          GET /api/availability/time-slots?artistId=&date=
Paso 3 → Detalles: ubicación, notas, ¿multi-día?
          POST /api/catalog/pricing/calculate → muestra precio dinámico
Paso 4 → Resumen + confirmar
          POST /api/bookings
```

**Cálculo de precio dinámico**:
```json
POST /api/catalog/pricing/calculate
{
  "serviceId": "xxx",
  "scheduledDate": "2026-05-10T15:00:00.000Z",
  "duration": 60,
  "locationLat": 14.64,
  "locationLng": -90.51,
  "numDays": 1
}
→ { totalCents, breakdown: { baseCents, travelCents } }
```

### 5.6 Mi Espacio (3 tabs internos)

**Tab Reservas**:
- Filtro horizontal: Todas | Pendiente | Confirmada | Completada | Cancelada
- `GET /api/bookings?status=&page=`
- Swipe-to-cancel en reservas PENDING/CONFIRMED

**Detalle de Reserva**:
- Hero de estado (ícono circular + color según estado)
- Código de reserva (monospaced, fondo naranja 8%)
- Cards: Información, Resumen de pago, Notas, Acciones
- Acciones: Agregar al calendario, Compartir, Dejar reseña (si completed), Abrir queja

**Tab Eventos**:
- CRUD: `GET/POST/PATCH/DELETE /api/events`
- Vincular reservas existentes: `POST /api/events/{eventId}/bookings/{bookingId}`
- Mostrar total del evento = suma de reservas

**Tab Favoritos**:
- `GET /api/users/me/favorites?entityType=ARTIST`
- Add: `POST /api/users/me/favorites`
- Remove: `DELETE /api/users/me/favorites/{id}`

### 5.7 Inbox (2 tabs internos)

**Tab Mensajes**:
- Lista conversaciones: `GET /api/chat/conversations?page=`
- Chat detalle: `GET /api/chat/messages/{conversationId}?page=`
- WebSocket: `ws://api.piums.com/api/chat/ws` con JWT
- Badge counter en tab bar
- Mensajes propios: fondo naranja | recibidos: `CardBackground`

**Tab Quejas**:
- Lista: `GET /api/disputes/me`
- Detalle: `GET /api/disputes/{id}` (incluye messages)
- Crear: `POST /api/disputes`
- Responder: `POST /api/disputes/{id}/messages`

### 5.8 Perfil

```
Section Avatar + nombre + email + badge "Cliente"
Section Cuenta: Editar perfil | Cambiar contraseña | Mis pagos
Section Apariencia: Toggle dark/light mode
Section Ayuda: ¿Cómo funciona Piums? | Mis quejas | Términos | Privacidad | Soporte
Section Cerrar sesión (destructivo)
```

- PATCH `/api/auth/profile` — actualizar nombre
- POST `/api/auth/change-password`
- Guardar preferencia de tema en `DataStore`

### 5.9 Notificaciones

- `GET /api/notifications?page=` (paginado)
- `POST /api/notifications/read` body: `{ "notificationIds": ["id1"] }`
- Registro FCM token: `POST /api/notifications/push-token` body: `{ "token": "fcm_token", "platform": "android" }`
- Filas: no leídas = fondo naranja 5% + borde naranja 20% | leídas = `CardBackground`

---

## 6. MODELOS DE DATOS (Kotlin)

```kotlin
// data/models/User.kt
data class AuthUser(
    val id: String,
    val email: String,
    val nombre: String?,
    val role: String,      // "cliente"
    val avatar: String?
)

// data/models/Artist.kt
data class Artist(
    val id: String,
    val name: String,
    val bio: String?,
    val city: String?,
    val state: String?,
    val country: String?,
    val averageRating: Double?,
    val totalReviews: Int,
    val totalBookings: Int,
    val mainServicePrice: Int?,
    val mainServiceName: String?,
    val isVerified: Boolean,
    val isActive: Boolean,
    val isAvailable: Boolean,
    val specialties: List<String>?,
    val baseLocationLat: Double?,
    val baseLocationLng: Double?
) {
    val artistName: String get() = name
    val rating: Double? get() = averageRating
}

// data/models/ArtistService.kt
data class ArtistService(
    val id: String,
    val artistId: String,
    val name: String,
    val description: String?,
    val pricingType: String?,   // "FIXED" | "HOURLY" | "PACKAGE"
    val basePrice: Int,
    val currency: String,
    val durationMin: Int?,
    val durationMax: Int?,
    val status: String?,
    val isAvailable: Boolean?,
    val isMainService: Boolean?,
    val whatIsIncluded: List<String>?
) {
    val price: Int get() = basePrice
    val duration: Int get() = durationMin ?: 60
}

// data/models/Booking.kt
data class Booking(
    val id: String,
    val code: String?,
    val clientId: String,
    val artistId: String,
    val serviceId: String,
    val status: BookingStatus,
    val paymentStatus: PaymentStatus,
    val totalPrice: Int,
    val scheduledDate: String,
    val scheduledTime: String?,
    val duration: Int?,
    val notes: String?,
    val location: String?,
    val eventId: String?,
    val createdAt: String
)

enum class BookingStatus(val raw: String, val displayName: String) {
    PENDING("PENDING", "Pendiente"),
    CONFIRMED("CONFIRMED", "Confirmada"),
    PAYMENT_PENDING("PAYMENT_PENDING", "Pago pendiente"),
    PAYMENT_COMPLETED("PAYMENT_COMPLETED", "Pago completado"),
    IN_PROGRESS("IN_PROGRESS", "En progreso"),
    COMPLETED("COMPLETED", "Completada"),
    RESCHEDULED("RESCHEDULED", "Reprogramada"),
    CANCELLED_CLIENT("CANCELLED_CLIENT", "Cancelada por ti"),
    CANCELLED_ARTIST("CANCELLED_ARTIST", "Cancelada por artista"),
    REJECTED("REJECTED", "Rechazada"),
    NO_SHOW("NO_SHOW", "No se presentó");

    companion object {
        fun from(raw: String) = values().firstOrNull { it.raw == raw } ?: PENDING
    }
}

// data/models/Event.kt
data class EventSummary(
    val id: String,
    val code: String,
    val clientId: String,
    val name: String,
    val description: String?,
    val location: String?,
    val notes: String?,
    val eventDate: String?,
    val status: EventStatus,
    val createdAt: String,
    val bookings: List<EventBooking>?
)

enum class EventStatus(val raw: String) {
    DRAFT("DRAFT"), ACTIVE("ACTIVE"), CANCELLED("CANCELLED");
    companion object { fun from(raw: String) = values().first { it.raw == raw } }
}

// data/models/Dispute.kt
data class Dispute(
    val id: String,
    val bookingId: String,
    val reportedBy: String,
    val disputeType: String,
    val subject: String,
    val description: String,
    val status: DisputeStatus,
    val priority: Int?,
    val createdAt: String,
    val messages: List<DisputeMessage>?
)

enum class DisputeStatus(val raw: String, val displayName: String) {
    OPEN("OPEN", "Abierta"),
    IN_REVIEW("IN_REVIEW", "En revisión"),
    AWAITING_INFO("AWAITING_INFO", "Esperando info"),
    RESOLVED("RESOLVED", "Resuelta"),
    CLOSED("CLOSED", "Cerrada"),
    ESCALATED("ESCALATED", "Escalada");
    companion object { fun from(raw: String) = values().firstOrNull { it.raw == raw } ?: OPEN }
}

// data/models/Chat.kt
data class Conversation(
    val id: String,
    val userId: String,
    val artistId: String,
    val bookingId: String?,
    val status: String,
    val lastMessageAt: String?,
    val unreadCount: Int?,
    val createdAt: String
)

data class ChatMessage(
    val id: String,
    val conversationId: String,
    val senderId: String,
    val senderType: String,  // "client" | "artist"
    val content: String,
    val type: String,        // "text"
    val read: Boolean,
    val createdAt: String
)

// data/models/Notification.kt
data class PiumsNotification(
    val id: String,
    val title: String,
    val message: String,
    val type: String,        // "BOOKING_CONFIRMED" | "PAYMENT_COMPLETED" | etc.
    val readAt: String?,
    val createdAt: String
) {
    val isRead: Boolean get() = readAt != null
}
```

---

## 7. API ENDPOINTS COMPLETOS

### Base URL
```
DEV:  http://localhost:3005
PROD: https://api.piums.com

Headers siempre:
  Content-Type: application/json
  Authorization: Bearer {JWT}   ← solo en endpoints requiresAuth=true
```

### Auth (no requieren token excepto los marcados)
```
POST /api/auth/login                   body: {email, password}
POST /api/auth/register/client         body: {nombre, email, password}
POST /api/auth/firebase                body: {idToken, role: "cliente"}
POST /api/auth/refresh                 body: {refreshToken}
POST /api/auth/logout                  [auth]
GET  /api/auth/me                      [auth]
POST /api/auth/forgot-password         body: {email}
PATCH /api/auth/profile                [auth] body: {nombre}
POST /api/auth/change-password         [auth] body: {currentPassword, newPassword}
POST /api/auth/complete-onboarding     [auth]
```

### Artists & Search
```
GET /api/search/artists?page=1&limit=20&q=&specialty=&city=&minPrice=&maxPrice=&minRating=&isVerified=&sortBy=&sortOrder=
GET /api/search/smart?q=&page=1&limit=20&lat=&lng=&city=&specialty=&minPrice=&maxPrice=&minRating=&isVerified=
GET /api/artists/{id}
GET /api/artists/{id}/portfolio
GET /api/catalog/services?artistId={id}
```

### Availability & Pricing
```
GET  /api/availability/time-slots?artistId={id}&date=2026-05-10
GET  /api/availability/calendar?artistId={id}&year=2026&month=5
POST /api/catalog/pricing/calculate
     body: {serviceId, scheduledDate (ISO), duration, locationLat, locationLng, numDays}
```

### Bookings
```
POST /api/bookings                              [auth] body: ver abajo
GET  /api/bookings?page=1&limit=20&status=      [auth]
GET  /api/bookings/{id}                         [auth]
POST /api/bookings/{id}/cancel                  [auth]
```

**Create booking body**:
```json
{
  "artistId": "xxx",
  "serviceId": "yyy",
  "scheduledDate": "2026-05-10T15:00:00.000Z",
  "duration": 60,
  "location": "Salón XYZ",
  "locationLat": 14.64,
  "locationLng": -90.51,
  "notes": "...",
  "numDays": 1,
  "eventId": null
}
```

### Events
```
GET    /api/events                              [auth]
POST   /api/events                             [auth] body: {name, eventDate, location, notes, description}
PATCH  /api/events/{id}                        [auth] body: {name, eventDate, location, notes, description}
DELETE /api/events/{id}                        [auth]
POST   /api/events/{eventId}/bookings/{bookingId}  [auth]
```

### Favorites
```
GET    /api/users/me/favorites?page=1&limit=50&entityType=ARTIST   [auth]
POST   /api/users/me/favorites                 [auth] body: {entityType: "ARTIST", entityId, notes}
DELETE /api/users/me/favorites/{id}            [auth]
GET    /api/users/me/favorites/check?entityType=ARTIST&entityId=   [auth]
```

### Reviews
```
GET  /api/reviews?artistId={id}&page=1&limit=10
POST /api/reviews   [auth] body: {artistId, bookingId, rating (1-5), comment}
```

### Payments
```
POST /api/payments/intent   [auth] body: {bookingId}
GET  /api/payments?page=1   [auth]
GET  /api/payments/{id}     [auth]
```

### Disputes
```
GET  /api/disputes/me         [auth]
POST /api/disputes            [auth] body: {bookingId, disputeType, subject, description}
GET  /api/disputes/{id}       [auth]
POST /api/disputes/{id}/messages  [auth] body: {message}
```

### Chat
```
GET   /api/chat/conversations?page=1&limit=20         [auth]
GET   /api/chat/conversations/{id}                    [auth]
PATCH /api/chat/conversations/{id}/read               [auth]
GET   /api/chat/messages/{conversationId}?page=1&limit=50  [auth]
POST  /api/chat/messages  [auth] body: {conversationId, content, type: "text"}
GET   /api/chat/messages/unread-count                 [auth]
WS    /api/chat/ws  + header Authorization: Bearer {JWT}
```

### Notifications
```
GET  /api/notifications?page=1&limit=20               [auth]
POST /api/notifications/read   [auth] body: {notificationIds: ["id1", "id2"]}
POST /api/notifications/push-token  [auth] body: {token, platform: "android"}
```

---

## 8. COMPONENTES REUTILIZABLES (Compose)

```kotlin
// PiumsButton.kt
@Composable
fun PiumsButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false
) {
    Button(
        onClick = onClick,
        enabled = enabled && !isLoading,
        colors = ButtonDefaults.buttonColors(
            containerColor = PiumsOrange,
            disabledContainerColor = PiumsOrange.copy(alpha = 0.5f)
        ),
        shape = RoundedCornerShape(14.dp),
        modifier = modifier.fillMaxWidth().height(54.dp)
    ) {
        if (isLoading) {
            CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
            Spacer(Modifier.width(8.dp))
        }
        Text(if (isLoading) "Cargando..." else text, fontWeight = FontWeight.Bold)
    }
}

// PiumsCard.kt — equivalente a los .background(tertiarySystemGroupedBackground)
@Composable
fun PiumsCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
        content = content
    )
}

// PiumsTextField.kt
@Composable
fun PiumsTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    placeholder: String,
    modifier: Modifier = Modifier,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    trailingIcon: @Composable (() -> Unit)? = null,
    visualTransformation: VisualTransformation = VisualTransformation.None
) {
    Column(modifier = modifier) {
        Text(label, style = MaterialTheme.typography.labelSmall,
             color = MaterialTheme.colorScheme.onSurface.copy(0.6f))
        Spacer(Modifier.height(6.dp))
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            keyboardOptions = keyboardOptions,
            visualTransformation = visualTransformation,
            decorationBox = { inner ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(Modifier.weight(1f)) {
                        if (value.isEmpty()) Text(placeholder, color = Color.Gray)
                        inner()
                    }
                    trailingIcon?.invoke()
                }
            }
        )
    }
}

// PiumsStatusBadge.kt — equivalente a las Capsule() con color de estado
@Composable
fun PiumsStatusBadge(text: String, color: Color) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelSmall,
        color = color,
        modifier = Modifier
            .clip(CircleShape)
            .background(color.copy(alpha = 0.12f))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    )
}

// ArtistCard.kt — card vertical (Home recomendados)
@Composable
fun ArtistCard(artist: Artist, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .width(160.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surface)
            .clickable(onClick = onClick)
    ) {
        // Cover gradient + iniciales
        Box(modifier = Modifier.fillMaxWidth().height(120.dp)
                .background(piumsGradientForArtist(artist.id))) {
            // TOP RATED badge si rating >= 4.8
            // Avatar iniciales superpuesto
        }
        Column(Modifier.padding(horizontal = 6.dp, vertical = 4.dp)) {
            Spacer(Modifier.height(18.dp)) // space for overlapping avatar
            Text(artist.artistName, style = MaterialTheme.typography.titleMedium,
                 maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text("${artist.specialties?.firstOrNull() ?: "Artista"} · ${artist.city ?: ""}",
                 style = MaterialTheme.typography.bodyMedium,
                 color = MaterialTheme.colorScheme.onSurface.copy(0.6f),
                 maxLines = 1)
            artist.mainServicePrice?.let {
                Text(it.piumsFormatted(), color = PiumsOrange,
                     style = MaterialTheme.typography.labelSmall,
                     fontWeight = FontWeight.Bold)
            }
        }
    }
}
```

---

## 9. ARQUITECTURA ANDROID

```
app/src/main/java/com/piums/cliente/
├── MainActivity.kt                 ← Single Activity, NavHost
├── di/
│   ├── NetworkModule.kt            ← Retrofit + OkHttp + Hilt
│   └── RepositoryModule.kt
├── data/
│   ├── remote/
│   │   ├── PiumsApiService.kt      ← todas las llamadas Retrofit
│   │   ├── AuthInterceptor.kt      ← agrega Bearer token automáticamente
│   │   └── dto/                    ← DTOs de respuesta
│   ├── local/
│   │   ├── TokenStorage.kt         ← EncryptedSharedPreferences
│   │   └── PiumsDataStore.kt       ← DataStore (tema, onboarding)
│   └── repository/
│       ├── AuthRepository.kt
│       ├── ArtistRepository.kt
│       ├── BookingRepository.kt
│       ├── EventRepository.kt
│       ├── ChatRepository.kt
│       └── NotificationRepository.kt
├── domain/
│   └── models/                     ← modelos de dominio (ver sección 6)
├── ui/
│   ├── theme/
│   │   ├── Color.kt
│   │   ├── Type.kt
│   │   └── PiumsTheme.kt
│   ├── components/                 ← componentes reutilizables (sección 8)
│   └── screens/
│       ├── auth/                   ← Login, Register, ForgotPassword
│       ├── onboarding/
│       ├── home/
│       ├── search/
│       ├── artist_profile/
│       ├── booking/
│       ├── my_space/               ← tabs: Reservas, Eventos, Favoritos
│       ├── inbox/                  ← tabs: Mensajes, Quejas
│       ├── profile/
│       └── notifications/
└── utils/
    ├── PiumsFormatter.kt           ← formatPrice, formatDate
    └── WebSocketManager.kt         ← chat en tiempo real
```

### Networking Retrofit

```kotlin
// di/NetworkModule.kt
@Module @InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides @Singleton
    fun provideOkHttp(tokenStorage: TokenStorage): OkHttpClient =
        OkHttpClient.Builder()
            .addInterceptor(AuthInterceptor(tokenStorage))
            .addInterceptor(HttpLoggingInterceptor().apply { level = BODY })
            .build()

    @Provides @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit =
        Retrofit.Builder()
            .baseUrl("https://api.piums.com")
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
}

// data/remote/AuthInterceptor.kt
class AuthInterceptor(private val tokenStorage: TokenStorage) : Interceptor {
    override fun intercept(chain: Chain): Response {
        val token = tokenStorage.getToken() ?: return chain.proceed(chain.request())
        val req = chain.request().newBuilder()
            .addHeader("Authorization", "Bearer $token")
            .build()
        return chain.proceed(req)
    }
}
```

### Token Storage

```kotlin
// data/local/TokenStorage.kt
class TokenStorage @Inject constructor(@ApplicationContext ctx: Context) {
    private val prefs = EncryptedSharedPreferences.create(
        ctx, "piums_secure", MasterKey.Builder(ctx).setKeyScheme(AES256_GCM).build(),
        AES256_SIV, AES256_GCM
    )
    fun saveToken(token: String) = prefs.edit().putString("jwt", token).apply()
    fun getToken(): String? = prefs.getString("jwt", null)
    fun saveRefreshToken(t: String) = prefs.edit().putString("refresh", t).apply()
    fun getRefreshToken(): String? = prefs.getString("refresh", null)
    fun clear() = prefs.edit().clear().apply()
}
```

---

## 10. FORMATO DE PRECIOS

```kotlin
// utils/PiumsFormatter.kt
fun Int.piumsFormatted(): String {
    // Backend envía precios en unidades GTQ (no centavos para montos de reserva)
    // Ejemplo: 15000 = Q150.00 (verificar con backend)
    return "Q${String.format("%,.2f", this / 100.0)}"
}
```

---

## 11. WEBSOCKET (Chat)

```kotlin
// utils/WebSocketManager.kt
class WebSocketManager @Inject constructor(private val tokenStorage: TokenStorage) {
    private val client = OkHttpClient()
    private var ws: WebSocket? = null

    fun connect(onMessage: (String) -> Unit) {
        val token = tokenStorage.getToken() ?: return
        val req = Request.Builder()
            .url("wss://api.piums.com/api/chat/ws")
            .addHeader("Authorization", "Bearer $token")
            .build()
        ws = client.newWebSocket(req, object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, text: String) = onMessage(text)
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                // reconectar con backoff exponencial
            }
        })
    }

    fun send(message: String) = ws?.send(message)
    fun disconnect() = ws?.close(1000, null)
}
```

---

## 12. DEPENDENCIAS (build.gradle.kts)

```kotlin
dependencies {
    // Compose
    implementation(platform("androidx.compose:compose-bom:2024.04.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.navigation:navigation-compose:2.7.7")

    // Lifecycle & ViewModel
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")

    // Hilt
    implementation("com.google.dagger:hilt-android:2.51")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")
    kapt("com.google.dagger:hilt-compiler:2.51")

    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

    // Storage
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Images
    implementation("io.coil-kt:coil-compose:2.6.0")

    // Google Auth
    implementation("com.google.android.gms:play-services-auth:21.1.0")
    implementation("com.google.firebase:firebase-auth:22.3.1")

    // Pull-to-refresh
    implementation("com.google.accompanist:accompanist-swiperefresh:0.34.0")

    // Maps & Location
    implementation("com.google.android.gms:play-services-location:21.2.0")
}
```

---

## 13. CHECKLIST DE IMPLEMENTACIÓN

### Fase 1 — MVP
- [ ] Proyecto Android + Compose + Hilt configurado
- [ ] PiumsTheme (colores, tipografía, dark/light)
- [ ] NetworkModule + AuthInterceptor + TokenStorage
- [ ] LoginScreen (igual al diseño de referencia)
- [ ] RegisterScreen
- [ ] RootActivity con NavHost (Splash → Onboarding → Auth → Main)
- [ ] BottomNavigation con 5 tabs
- [ ] HomeScreen (saludo + calendario + artistas sugeridos)
- [ ] SearchScreen con categorías y búsqueda
- [ ] ArtistProfileScreen
- [ ] BookingFlow (4 pasos)
- [ ] ProfileScreen

### Fase 2 — Core
- [ ] MySpaceScreen (Reservas + Eventos + Favoritos)
- [ ] BookingDetail con acciones
- [ ] ChatInbox + ChatDetail + WebSocket
- [ ] NotificationsScreen + FCM push tokens
- [ ] FavoritesSystem (add/remove/check)
- [ ] ReviewsScreen

### Fase 3 — Advanced
- [ ] SmartSearch con geolocalización
- [ ] EventsSystem (CRUD + vincular reservas)
- [ ] DisputesSystem
- [ ] Google Pay
- [ ] Biometric auth
- [ ] Adaptive icons

---

> **Notas críticas**:
> 1. El backend devuelve precios como `Int` pero algunas respuestas los mezclan con `Double`. Usar un TypeAdapter tolerante en Gson (igual que el `decodeFlexibleInt` de iOS).
> 2. El campo de artistas en Search es `name`, no `artistName`. En el detalle de artista el shape puede ser diferente.
> 3. Disputes responde `{ asReporter: [], asReported: [], total: 0 }` — combinar y ordenar por `createdAt` DESC.
> 4. Chat WebSocket envía eventos JSON — parsear tipo de evento antes de procesar.
> 5. El `role` en el token Firebase debe ser `"cliente"` (minúscula).

---

## 14. FIXES CRÍTICOS APLICADOS EN iOS (Abril 2026) — Replicar en Android

### 14.1 Modelo de Conversación — Campo mapping incorrecto

El backend (Prisma) usa `participant1Id` / `participant2Id`, NO `userId` / `artistId`.
Si se deserializa con los nombres incorrectos, la lista de conversaciones queda vacía silenciosamente.

```kotlin
// data/remote/dto/ConversationDto.kt
data class ConversationDto(
    val id: String,
    @SerializedName("participant1Id") val userId: String,    // ← clave real del backend
    @SerializedName("participant2Id") val artistId: String,  // ← clave real del backend
    val bookingId: String?,
    val status: String,
    val lastMessageAt: String?,
    val unreadCount: Int = 0,
    val messages: List<ChatMessageDto> = emptyList()
)
```

### 14.2 Modelo de ChatMessage — Campo `status` en lugar de `read`

El backend envía `status: "SENT" | "DELIVERED" | "READ"` — no envía `read: Boolean` ni `senderType`.
Para determinar si un mensaje es propio, comparar `senderId` con el `currentUserId` del usuario autenticado.

```kotlin
data class ChatMessageDto(
    val id: String,
    val conversationId: String,
    val senderId: String,
    val content: String,
    val status: String,   // "SENT" | "DELIVERED" | "READ"
    val createdAt: String
) {
    val isRead: Boolean get() = status == "READ"
}

// En el ViewModel o Composable:
val isOwn = message.senderId == authManager.currentUserId
```

### 14.3 No usar datos mock como fallback

Los ViewModels de ArtistProfile, BookingFlow y Search deben mostrar error real cuando la API falla — nunca datos inventados.

```kotlin
// INCORRECTO — oculta errores reales
} catch (e: Exception) {
    _services.value = ArtistService.mockList()  // ← ELIMINAR
}

// CORRECTO
} catch (e: Exception) {
    _errorMessage.value = e.toUserMessage()
}
```

### 14.4 Tutorial interactivo (TourOverlay)

El tour interactivo debe funcionar como overlay sobre la app real (no una pantalla separada):
- `TutorialManager` singleton con `isActive`, `currentStep`, `currentTabTarget`
- Overlay semitransparente con backdrop (`#8C000000`), flecha apuntando al tab activo
- 6 pasos que auto-navegan al tab correcto al avanzar
- Botones: atrás / siguiente / cerrar (✕) / "Ir a [Sección]"
- `AppStorage("hasSeenHowItWorks")` evita que reaparezca automáticamente

### 14.5 SuccessBannerView / ErrorBannerView en EventsView

Al vincular una reserva a un evento, mostrar banner no-intrusivo en la parte superior (no dialog):
- Éxito: fondo verde oscuro, texto "Reserva vinculada al evento correctamente", auto-dismiss 3s
- Error: fondo rojo oscuro con mensaje de error de la API
- Implementar como `Snackbar` personalizado o `AnimatedVisibility` en `safeAreaInset` superior

### 14.6 TalentPickerView conectado a SearchFiltersSheet

El picker de talentos específicos ya existe en iOS y está conectado a los filtros de búsqueda:
- Filtro "Talento específico" abre `TalentPickerView` (lista de talentos del backend)
- Al seleccionar un talento: chip activo aparece en la barra, se limpia la especialidad
- El chip tiene botón ✕ para limpiar el filtro
- `clearFilters()` también limpia `selectedTalentId` y `selectedTalentLabel`
