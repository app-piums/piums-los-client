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

### Flujo de 3 pasos — `LoginStep`

La card central cambia de contenido según el paso con animación spring. Los 3 pasos son:
- **Paso 1 — email**: campo email + botón "Continuar →" + botón colapsado para social
- **Paso 2 — password**: flecha back + email en header + campo contraseña + "Iniciar sesión"
- **Paso 3 — social**: 3 botones sociales (Google, Facebook, TikTok) + link a email/password

```
┌────────────────────────────────┐
│  (fondo oscuro degradado)      │
│                                │
├────────────────────────────────┤  ← card R=28dp, desliza desde abajo (57% alto pantalla)
│         [PiumsLogo]            │  ← logo, height: 210dp (sin ícono ticket)
│  "¡Bienvenido a Piums!"        │  ← headline bold, blanco
│  "El artista perfecto para     │  ← body, white 50%
│   tu próximo evento"           │
│  ——— (drag indicator)          │
│                                │
│  PASO 1 (email):               │
│  Bienvenido de nuevo           │
│  CORREO ELECTRÓNICO            │
│  [nombre@ejemplo.com       ]   │
│  [    Continuar →    ]         │  ← naranja, deshabilitado si email inválido
│  ── ● ──                       │  ← divider con punto central
│  [Continúa con Google, FB o TT]│  ← botón al paso social
│  ¿Aún no tienes cuenta?        │
│                                │
│  PASO 2 (password):            │
│  ← (circle) · correo@...       │  ← back orange circle + email
│  CONTRASEÑA                    │
│  [••••••••          👁]        │
│  [    Iniciar sesión    ]       │
│            ¿Olvidaste tu...?   │
│  ¿Aún no tienes cuenta?        │
│                                │
│  PASO 3 (social):              │
│  Ingresar o crear cuenta con:  │
│  [G  Continuar con Google    ] │
│  [f  Continuar con Facebook  ] │
│  [♪  Continuar con TikTok    ] │
│  ── ● ──                       │
│  [Continúa con correo y pass ] │
│  ¿Aún no tienes cuenta?        │
│  términos y política           │
└────────────────────────────────┘
```

```kotlin
// screens/auth/LoginScreen.kt

enum class LoginStep { EMAIL, PASSWORD, SOCIAL }

@Composable
fun LoginScreen(viewModel: AuthViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsState()
    var animateIn by remember { mutableStateOf(false) }
    var loginStep by remember { mutableStateOf(LoginStep.EMAIL) }
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
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Bottom) {
            LoginSheet(
                modifier = Modifier.offset(y = offsetY),
                loginStep = loginStep,
                uiState = uiState,
                onStepChange = { loginStep = it },
                onLoginClick = { viewModel.login() },
                onGoogleClick = { viewModel.loginWithGoogle() },
                onFacebookClick = { viewModel.loginWithFacebook() },
                onTikTokClick = { viewModel.loginWithTikTok() },
                onForgotClick = { /* navigate */ },
                onRegisterClick = { /* navigate */ }
            )
        }
    }
}

@Composable
private fun LoginSheet(
    modifier: Modifier = Modifier,
    loginStep: LoginStep,
    uiState: AuthUiState,
    onStepChange: (LoginStep) -> Unit,
    onLoginClick: () -> Unit,
    onGoogleClick: () -> Unit,
    onFacebookClick: () -> Unit,
    onTikTokClick: () -> Unit,
    onForgotClick: () -> Unit,
    onRegisterClick: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }

    fun isValidEmail(e: String) = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+\$").matches(e)

    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 0.dp
    ) {
        Column {
            // Drag indicator
            Box(Modifier.fillMaxWidth().padding(top = 14.dp), Alignment.Center) {
                Box(Modifier.size(width = 36.dp, height = 4.dp)
                    .background(Color.White.copy(0.18f), RoundedCornerShape(2.dp)))
            }
            Spacer(Modifier.height(24.dp))

            // Contenido animado entre pasos
            AnimatedContent(
                targetState = loginStep,
                transitionSpec = {
                    val slideIn = when (targetState) {
                        LoginStep.EMAIL   -> slideInHorizontally { -it }
                        LoginStep.PASSWORD -> slideInHorizontally { it }
                        LoginStep.SOCIAL  -> slideInHorizontally { it }
                    }
                    val slideOut = when (initialState) {
                        LoginStep.EMAIL   -> slideOutHorizontally { -it }
                        LoginStep.PASSWORD -> slideOutHorizontally { it }
                        LoginStep.SOCIAL  -> slideOutHorizontally { it }
                    }
                    (slideIn + fadeIn(tween(220))) togetherWith (slideOut + fadeOut(tween(180)))
                },
                modifier = Modifier.padding(horizontal = 26.dp),
                label = "loginStep"
            ) { step ->
                when (step) {

                    // ── Paso 1: Email ──────────────────────────────────────
                    LoginStep.EMAIL -> Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
                        Text("Bienvenido de nuevo",
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold)

                        PiumsAuthField(label = "CORREO ELECTRÓNICO", value = email,
                            onValueChange = { email = it },
                            placeholder = "nombre@ejemplo.com",
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Email,
                                imeAction = ImeAction.Next),
                            onDone = { if (isValidEmail(email)) onStepChange(LoginStep.PASSWORD) })

                        uiState.error?.let { ErrorBanner(it) }

                        // Botón Continuar — deshabilitado si email inválido
                        ContinueButton(
                            title = "Continuar",
                            enabled = isValidEmail(email),
                            onClick = { onStepChange(LoginStep.PASSWORD) }
                        )

                        PiumsDivider()

                        // Botón colapsado social
                        OutlinedAuthButton(
                            text = "Continúa con Google, Facebook o TikTok",
                            onClick = { onStepChange(LoginStep.SOCIAL) }
                        )

                        RegisterLink(onRegisterClick)
                        Spacer(Modifier.height(26.dp))
                    }

                    // ── Paso 2: Contraseña ─────────────────────────────────
                    LoginStep.PASSWORD -> Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
                        // Header: back + email
                        Row(verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            IconButton(
                                onClick = { onStepChange(LoginStep.EMAIL) },
                                modifier = Modifier
                                    .size(36.dp)
                                    .background(MaterialTheme.colorScheme.surfaceVariant, CircleShape)
                            ) {
                                Icon(Icons.Default.ArrowBack, null,
                                    tint = PiumsOrange, modifier = Modifier.size(18.dp))
                            }
                            Column {
                                Text("Bienvenido", style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurface.copy(0.5f))
                                Text(email, style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1, overflow = TextOverflow.MiddleEllipsis)
                            }
                        }

                        PiumsAuthField(label = "CONTRASEÑA", value = password,
                            onValueChange = { password = it },
                            placeholder = "••••••••",
                            isPassword = true, showPassword = showPassword,
                            onTogglePassword = { showPassword = !showPassword },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Password,
                                imeAction = ImeAction.Done),
                            onDone = onLoginClick)

                        uiState.error?.let { ErrorBanner(it) }

                        // Botón login
                        LoginButton(isLoading = uiState.isLoading,
                            enabled = password.isNotBlank(),
                            onClick = onLoginClick)

                        Box(Modifier.fillMaxWidth(), Alignment.CenterEnd) {
                            TextButton(onClick = onForgotClick) {
                                Text("¿Olvidaste tu contraseña?",
                                    color = PiumsOrange,
                                    style = MaterialTheme.typography.labelMedium)
                            }
                        }

                        RegisterLink(onRegisterClick)
                        Spacer(Modifier.height(26.dp))
                    }

                    // ── Paso 3: Social ─────────────────────────────────────
                    LoginStep.SOCIAL -> Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                        Text("Ingresar o crear cuenta con:",
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold)

                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            SocialSignInButton(provider = SocialProvider.GOOGLE,
                                onClick = onGoogleClick, enabled = !uiState.isLoading)
                            SocialSignInButton(provider = SocialProvider.FACEBOOK,
                                onClick = onFacebookClick, enabled = !uiState.isLoading)
                            SocialSignInButton(provider = SocialProvider.TIKTOK,
                                onClick = onTikTokClick, enabled = !uiState.isLoading)
                        }

                        uiState.error?.let { ErrorBanner(it) }

                        PiumsDivider()

                        OutlinedAuthButton(
                            text = "Continúa con correo y contraseña",
                            onClick = { onStepChange(LoginStep.EMAIL) }
                        )

                        RegisterLink(onRegisterClick)

                        // Términos
                        Text(
                            buildAnnotatedString {
                                append("Al crear una cuenta en Piums, aceptas los ")
                                withStyle(SpanStyle(color = PiumsOrange,
                                    fontWeight = FontWeight.Medium)) {
                                    append("Términos de Servicio")
                                }
                                append(" y ")
                                withStyle(SpanStyle(color = PiumsOrange,
                                    fontWeight = FontWeight.Medium)) {
                                    append("Política de Privacidad.")
                                }
                            },
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(0.45f)
                        )

                        Spacer(Modifier.height(26.dp))
                    }
                }
            }
        }
    }
}

// ── Divider con punto central ──────────────────────────────────────────────

@Composable
fun PiumsDivider() {
    Row(verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        HorizontalDivider(Modifier.weight(1f), color = Color.White.copy(0.12f))
        Box(Modifier.size(5.dp).background(Color.White.copy(0.20f), CircleShape))
        HorizontalDivider(Modifier.weight(1f), color = Color.White.copy(0.12f))
    }
}

// ── Botón social (full-width, icono a la izquierda, texto centrado-izquierdo, Spacer) ──

enum class SocialProvider(val label: String) {
    GOOGLE("Google"), FACEBOOK("Facebook"), TIKTOK("TikTok")
}

@Composable
fun SocialSignInButton(provider: SocialProvider, onClick: () -> Unit, enabled: Boolean = true) {
    Button(
        onClick = onClick,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
            disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(0.5f)
        ),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, Color.White.copy(0.12f)),
        modifier = Modifier.fillMaxWidth().height(52.dp),
        contentPadding = PaddingValues(horizontal = 16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            SocialProviderIcon(provider)
            Text("Continuar con ${provider.label}",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.weight(1f))
        }
    }
}

@Composable
fun SocialProviderIcon(provider: SocialProvider) {
    when (provider) {
        SocialProvider.GOOGLE -> Box(
            Modifier.size(26.dp).background(Color.White, CircleShape),
            Alignment.Center
        ) {
            Text("G", fontWeight = FontWeight.Bold,
                color = Color(0xFF4285F4), fontSize = 15.sp)
        }
        SocialProvider.FACEBOOK -> Box(
            Modifier.size(26.dp).background(Color(0xFF3A5999), CircleShape),
            Alignment.Center
        ) {
            Text("f", fontWeight = FontWeight.Bold,
                color = Color.White, fontSize = 16.sp)
        }
        SocialProvider.TIKTOK -> Box(
            Modifier.size(26.dp).background(Color.Black, CircleShape),
            Alignment.Center
        ) {
            Icon(Icons.Default.MusicNote, null,
                tint = Color.White, modifier = Modifier.size(14.dp))
        }
    }
}

// ── Botón contorno (para social colapsado y back-to-email) ─────────────────

@Composable
fun OutlinedAuthButton(text: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        ),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, Color.White.copy(0.10f)),
        modifier = Modifier.fillMaxWidth().height(52.dp)
    ) {
        Text(text, style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(0.85f))
    }
}

// ── Botón Continuar (con gradiente, deshabilitado si !enabled) ────────────

@Composable
fun ContinueButton(title: String, enabled: Boolean, onClick: () -> Unit) {
    val gradient = if (enabled)
        Brush.linearGradient(listOf(Color(0xFFD96120), Color(0xFFB84712)))
    else
        SolidColor(PiumsOrange.copy(0.40f))
    Box(
        Modifier.fillMaxWidth().height(54.dp)
            .background(gradient, RoundedCornerShape(14.dp))
            .clickable(enabled = enabled, onClick = onClick),
        Alignment.Center
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically) {
            Text(title, color = Color.White, fontWeight = FontWeight.Bold)
            Icon(Icons.Default.ArrowForward, null,
                tint = Color.White, modifier = Modifier.size(16.dp))
        }
    }
}

// ── Botón Iniciar sesión ───────────────────────────────────────────────────

@Composable
fun LoginButton(isLoading: Boolean, enabled: Boolean, onClick: () -> Unit) {
    val gradient = if (enabled)
        Brush.linearGradient(listOf(Color(0xFFD96120), Color(0xFFB84712)))
    else
        SolidColor(PiumsOrange.copy(0.40f))
    Box(
        Modifier.fillMaxWidth().height(54.dp)
            .background(gradient, RoundedCornerShape(14.dp))
            .clickable(enabled = enabled && !isLoading, onClick = onClick),
        Alignment.Center
    ) {
        if (isLoading) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(color = Color.White,
                    modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                Text("Iniciando sesión…", color = Color.White, fontWeight = FontWeight.Bold)
            }
        } else {
            Text("Iniciar sesión", color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}

// ── Link de registro ──────────────────────────────────────────────────────

@Composable
fun RegisterLink(onRegisterClick: () -> Unit) {
    Row(Modifier.fillMaxWidth(), Arrangement.Center) {
        Text("¿Aún no tienes cuenta? ",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(0.5f))
        Text("Regístrate gratis",
            style = MaterialTheme.typography.bodySmall,
            color = PiumsOrange, fontWeight = FontWeight.SemiBold,
            modifier = Modifier.clickable(onClick = onRegisterClick))
    }
}
```

### Campo de auth reutilizable

```kotlin
@Composable
fun PiumsAuthField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    isPassword: Boolean = false,
    showPassword: Boolean = false,
    onTogglePassword: (() -> Unit)? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    onDone: (() -> Unit)? = null
) {
    var isFocused by remember { mutableStateOf(false) }
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
            BasicTextField(
                value = value, onValueChange = onValueChange,
                modifier = Modifier.weight(1f).onFocusChanged { isFocused = it.isFocused },
                visualTransformation = if (isPassword && !showPassword)
                    PasswordVisualTransformation() else VisualTransformation.None,
                keyboardOptions = keyboardOptions,
                keyboardActions = KeyboardActions(onDone = { onDone?.invoke() }),
                textStyle = MaterialTheme.typography.bodyLarge.copy(
                    color = MaterialTheme.colorScheme.onSurface),
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
// Backend devuelve _id e id — usar "id". avatar puede ser URL de Google completa.
data class AuthUser(
    val id: String,
    val email: String,
    val nombre: String?,           // null en cuentas nuevas de Google
    val role: String,              // "cliente"
    val avatar: String?,           // URL Google: lh3.googleusercontent.com/...=s400-c
    val emailVerified: Boolean = false,
    val status: String = "ACTIVE"  // "ACTIVE" | "BANNED" | "SUSPENDED"
) {
    val displayName: String get() = nombre ?: email
    val isActive: Boolean get() = status == "ACTIVE"
}

// ── CRÍTICO: el backend envía precios como Int O Double sin consistencia ────────
// Registrar este TypeAdapter en Gson antes de construir Retrofit:
//
// object FlexibleIntAdapter : TypeAdapter<Int?>() {
//     override fun write(out: JsonWriter, value: Int?) { ... }
//     override fun read(input: JsonReader): Int? {
//         return when (input.peek()) {
//             JsonToken.NULL   -> { input.nextNull(); null }
//             JsonToken.NUMBER -> { val raw = input.nextString(); raw.toIntOrNull() ?: raw.toDoubleOrNull()?.toInt() }
//             else -> { input.skipValue(); null }
//         }
//     }
// }
// GsonBuilder()
//     .registerTypeAdapter(Int::class.java, FlexibleIntAdapter)
//     .registerTypeAdapter(Int?::class.java, FlexibleIntAdapter)
//     .create()
// ────────────────────────────────────────────────────────────────────────────────

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
    val hourlyRateMin: Int?,       // puede venir como Double del backend
    val hourlyRateMax: Int?,
    val mainServicePrice: Int?,
    val mainServiceName: String?,
    val isVerified: Boolean,
    val isActive: Boolean,
    val isAvailable: Boolean,
    val servicesCount: Int = 0,
    val serviceIds: List<String>?,
    val serviceTitles: List<String>?,
    val specialties: List<String>?,
    val createdAt: String?,
    val baseLocationLat: Double?,
    val baseLocationLng: Double?
) {
    val artistName: String get() = name
    val rating: Double? get() = averageRating
    val basePrice: Int? get() = mainServicePrice
}

// SmartSearch → usa SmartArtist (incluye matchedService + score de relevancia)
data class MatchedService(
    val id: String,
    val name: String,
    val price: Int,           // puede venir como Double — usar FlexibleIntAdapter
    val currency: String,
    val pricingType: String?,
    val isExactMatch: Boolean?
)

data class SmartArtist(
    val id: String,
    val name: String,
    val bio: String?,
    val city: String?,
    val state: String?,
    val country: String?,
    val averageRating: Double?,
    val totalReviews: Int,
    val totalBookings: Int,
    val hourlyRateMin: Int?,
    val hourlyRateMax: Int?,
    val mainServicePrice: Int?,
    val mainServiceName: String?,
    val isVerified: Boolean,
    val isActive: Boolean,
    val isAvailable: Boolean,
    val servicesCount: Int = 0,
    val serviceIds: List<String>?,
    val serviceTitles: List<String>?,
    val specialties: List<String>?,
    val matchedService: MatchedService?,
    val score: Double?,
    val createdAt: String?,
    val baseLocationLat: Double?,
    val baseLocationLng: Double?
) {
    fun toArtist() = Artist(
        id = id, name = name, bio = bio, city = city, state = state, country = country,
        averageRating = averageRating, totalReviews = totalReviews, totalBookings = totalBookings,
        hourlyRateMin = hourlyRateMin, hourlyRateMax = hourlyRateMax,
        mainServicePrice = matchedService?.price ?: mainServicePrice,
        mainServiceName = matchedService?.name ?: mainServiceName,
        isVerified = isVerified, isActive = isActive, isAvailable = isAvailable,
        servicesCount = servicesCount, serviceIds = serviceIds, serviceTitles = serviceTitles,
        specialties = specialties, createdAt = createdAt,
        baseLocationLat = baseLocationLat, baseLocationLng = baseLocationLng
    )
}

data class SearchArtistsResponse(val artists: List<Artist>, val pagination: SearchPagination)
data class SmartSearchResponse(
    val artists: List<SmartArtist>,
    val expandedTerms: List<String>?,
    val pagination: SearchPagination?
)
data class SearchPagination(val page: Int, val limit: Int, val total: Int, val totalPages: Int) {
    val hasMore: Boolean get() = page < totalPages
}

// data/models/ArtistService.kt
data class ArtistService(
    val id: String,
    val artistId: String,
    val name: String,
    val description: String?,
    val pricingType: String?,    // "FIXED" | "HOURLY" | "PACKAGE"
    val basePrice: Int,
    val currency: String,
    val durationMin: Int?,
    val durationMax: Int?,
    val status: String?,         // "ACTIVE" | "INACTIVE"
    val isAvailable: Boolean?,
    val isFeatured: Boolean?,
    val isMainService: Boolean?,
    val whatIsIncluded: List<String>?,
    val thumbnail: String?,
    val tags: List<String>?,
    val createdAt: String?
) {
    val price: Int get() = basePrice
    val duration: Int get() = durationMin ?: 60
    val isActive: Boolean get() = status == "ACTIVE"
}

data class CatalogServicesResponse(val services: List<ArtistService>)

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
    val updatedAt: String?,
    val bookings: List<EventBooking>?
)

// Las respuestas de eventos vienen envueltas en { success, data }
data class EventsResponse(val success: Boolean, val data: List<EventSummary>)
data class EventResponse(val success: Boolean, val data: EventSummary)

data class EventBooking(
    val id: String,
    val code: String?,
    val artistId: String,
    val serviceId: String,
    val scheduledDate: String,
    val status: BookingStatus,
    val totalPrice: Int,
    val currency: String?
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
    val reportedAgainst: String?,
    val disputeType: String,
    val subject: String,
    val description: String,
    val status: DisputeStatus,
    val priority: Int?,
    val resolution: String?,
    val resolutionNotes: String?,
    val refundAmount: Double?,
    val createdAt: String,
    val updatedAt: String?,
    val messages: List<DisputeMessage>?
)

// El endpoint GET /api/disputes/me devuelve:
// { asReporter: [...], asReported: [...], total: 0 }
data class DisputesResponse(
    val asReporter: List<Dispute>,
    val asReported: List<Dispute>,
    val total: Int
) {
    val allDisputes: List<Dispute> get() =
        (asReporter + asReported).sortedByDescending { it.createdAt }
}

data class DisputeMessage(
    val id: String,
    val disputeId: String,
    val senderId: String,
    val senderType: String,     // "client" | "artist" | "admin"
    val message: String,
    val isStatusUpdate: Boolean?,
    val oldStatus: String?,
    val newStatus: String?,
    val createdAt: String
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
// CRÍTICO: el backend usa participant1Id / participant2Id, NO userId / artistId
data class Conversation(
    @SerializedName("participant1Id") val userId: String,
    @SerializedName("participant2Id") val artistId: String,
    val id: String,
    val bookingId: String?,
    val status: String,
    val lastMessageAt: String?,
    val unreadCount: Int?,
    val createdAt: String,
    val updatedAt: String,
    val messages: List<ChatMessage>?
)

// CRÍTICO: el backend envía status: "SENT"|"DELIVERED"|"READ", NO un campo read: Boolean
// Para saber si un mensaje es propio: comparar senderId con el currentUserId del usuario autenticado
data class ChatMessage(
    val id: String,
    val conversationId: String,
    val senderId: String,
    val content: String,
    val type: String,        // "text"
    val status: String,      // "SENT" | "DELIVERED" | "READ"
    val readAt: String?,
    val createdAt: String,
    val updatedAt: String?
) {
    val isRead: Boolean get() = status == "READ"
}

data class ConversationsResponse(
    val conversations: List<Conversation>,
    val total: Int,
    val page: Int,
    val totalPages: Int
)
data class MessagesResponse(val messages: List<ChatMessage>, val total: Int, val page: Int, val totalPages: Int)
data class UnreadCountResponse(val unreadCount: Int)

// data/models/Notification.kt
data class PiumsNotification(
    val id: String,
    val title: String,
    val message: String,     // el backend usa "message" NO "body"
    val type: String,        // "BOOKING_CONFIRMED" | "PAYMENT_COMPLETED" | etc.
    val readAt: String?,     // null = no leída
    val data: NotificationData?,
    val createdAt: String
) {
    val isRead: Boolean get() = readAt != null
}

data class NotificationData(
    val bookingId: String?,
    val artistId: String?,
    val reviewId: String?,
    val rating: Int?,
    val disputeId: String?,
    val amount: Double?
)

// CRÍTICO: la paginación de notificaciones usa "pages" NO "totalPages"
data class NotificationsResponse(
    val notifications: List<PiumsNotification>,
    val pagination: NotificationsPagination
) {
    data class NotificationsPagination(
        val page: Int,
        val limit: Int,
        val total: Int,
        val pages: Int          // ← "pages", NO "totalPages"
    ) {
        val hasMore: Boolean get() = page < pages
    }
}

// data/models/Booking.kt — Respuesta puede venir en dos shapes:
data class BookingsResponse(
    val bookings: List<Booking>?,   // shape principal
    val data: List<Booking>?,       // shape alternativo que puede devolver el backend
    val pagination: SearchPagination?,
    val total: Int?,
    val page: Int?,
    val totalPages: Int?
) {
    val allBookings: List<Booking> get() =
        if (!bookings.isNullOrEmpty()) bookings else data ?: emptyList()
}

// data/models/Review.kt
data class Review(
    val id: String,
    val artistId: String,
    val clientId: String,
    val bookingId: String,
    val rating: Int,
    val comment: String?,
    val createdAt: String,
    val clientName: String?,
    val clientAvatar: String?
)

// Respuesta puede venir como { reviews: [] } o { data: [] }
data class ReviewsResponse(
    val reviews: List<Review>?,
    val data: List<Review>?,
    val pagination: SearchPagination?
) {
    val allReviews: List<Review> get() =
        if (!reviews.isNullOrEmpty()) reviews else data ?: emptyList()
}

// data/models/Favorites.kt
data class FavoriteRecord(
    val id: String,
    val entityType: String,  // "ARTIST"
    val entityId: String,
    val notes: String?,
    val createdAt: String,
    val deletedAt: String?
)

data class FavoritesResponse(val data: List<FavoriteRecord>, val total: Int, val page: Int, val totalPages: Int)
data class FavoriteCheckResponse(val isFavorite: Boolean, val favoriteId: String?)

// data/models/BookingFlow.kt — Modelos para el flujo de reserva
data class TimeSlot(
    val time: String,       // "09:00"
    val available: Boolean,
    val startTime: String?, // ISO
    val endTime: String?    // ISO
)

data class TimeSlotsResponse(val artistId: String?, val date: String?, val slots: List<TimeSlot>)

data class ArtistCalendar(
    val artistId: String?,
    val year: Int?,
    val month: Int?,
    val occupiedDates: List<String>,  // ["2026-04-07", ...]
    val blockedDates: List<String>
)

data class PriceQuoteItem(
    val type: String,             // "BASE" | "ADDON" | "TRAVEL"
    val name: String,
    val qty: Int?,
    val unitPriceCents: Int?,
    val totalPriceCents: Int
)

data class PriceQuoteBreakdown(
    val baseCents: Int,
    val addonsCents: Int,
    val travelCents: Int,
    val discountsCents: Int?
)

data class PriceQuote(
    val serviceId: String?,
    val currency: String,
    val items: List<PriceQuoteItem>,
    val subtotalCents: Int,
    val totalCents: Int,
    val breakdown: PriceQuoteBreakdown?
) {
    val totalInUnits: Double get() = totalCents / 100.0
    val hasTravel: Boolean get() = (breakdown?.travelCents ?: 0) > 0
}

// data/models/ArtistCategory.kt — categorías locales para UI (no vienen del backend en search)
enum class ArtistCategory(val raw: String, val displayName: String, val icon: String) {
    MUSICO("MUSICO", "Músico", "music.note"),
    BAILARIN("BAILARIN", "Bailarín", "figure.dance"),
    FOTOGRAFO("FOTOGRAFO", "Fotógrafo", "camera"),
    VIDEOGRAFO("VIDEOGRAFO", "Videógrafo", "video"),
    DISENADOR("DISENADOR", "Diseñador", "paintbrush"),
    ESCRITOR("ESCRITOR", "Escritor", "pencil"),
    ANIMADOR("ANIMADOR", "Animador", "face.smiling"),
    MAGO("MAGO", "Mago", "wand.and.stars"),
    ACROBATA("ACROBATA", "Acróbata", "figure.gymnastics"),
    ACTOR("ACTOR", "Actor", "theatermasks"),
    COMEDIANTE("COMEDIANTE", "Comediante", "mic"),
    ARTE_PLASTICO("ARTE_PLASTICO", "Arte Plástico", "paintpalette"),
    DJ("DJ", "DJ", "headphones"),
    CHEF("CHEF", "Chef", "fork.knife"),
    YOGA("YOGA", "Yoga", "figure.mind.and.body")
}
```

---

## 7. API ENDPOINTS COMPLETOS

### Base URL
```
DEV:  https://backend.piums.io   (Cloudflare tunnel — misma URL dev y prod por ahora)
PROD: https://backend.piums.io

OAuth callback host (Facebook/TikTok): client.piums.io

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
    → SearchArtistsResponse { artists: List<Artist>, pagination }

GET /api/search/smart?q=&page=1&limit=20&lat=&lng=&city=&specialty=&minPrice=&maxPrice=&minRating=&isVerified=
    → SmartSearchResponse { artists: List<SmartArtist>, expandedTerms, pagination }
    Usar .toArtist() para convertir SmartArtist → Artist y reutilizar los mismos Composables

GET /api/artists/{id}
GET /api/artists/{id}/portfolio
GET /api/catalog/services?artistId={id}   → CatalogServicesResponse { services: List<ArtistService> }
GET /api/catalog/services/{id}            → ArtistService directamente
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
POST /api/payments/payment-intents          [auth] body: {bookingId}
GET  /api/payments/payments?page=1&limit=20 [auth]
GET  /api/payments/payments/{id}            [auth]
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

### 14.7 Splash con Video — ExoPlayer (Media3)

La pantalla splash cambió de un logo estático con `ProgressView` a un video animado (`PiumsSplash.mp4`).
iOS usa `AVPlayer` a 2x velocidad con `resizeAspect`. Android equivalente con Media3 ExoPlayer:

```kotlin
// screens/splash/SplashScreen.kt
@Composable
fun SplashVideoScreen(onFinished: () -> Unit) {
    val context = LocalContext.current
    val player = remember {
        ExoPlayer.Builder(context).build().apply {
            val uri = Uri.parse("android.resource://${context.packageName}/raw/piums_splash")
            if (context.resources.getIdentifier("piums_splash", "raw", context.packageName) != 0) {
                setMediaItem(MediaItem.fromUri(uri))
                prepare()
                playbackParameters = PlaybackParameters(2f)  // 2x speed — igual que iOS
                play()
            } else {
                // fallback si no existe el video: esperar 1.5s
            }
        }
    }
    DisposableEffect(player) {
        val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_ENDED) onFinished()
            }
        }
        player.addListener(listener)
        onDispose {
            player.removeListener(listener)
            player.release()
        }
    }
    AndroidView(
        factory = { PlayerView(it).apply { this.player = player; useController = false; resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT } },
        modifier = Modifier.fillMaxSize().background(Color.Black)
    )
    LaunchedEffect(Unit) {
        // fallback por si el video no existe o falla
        delay(3000)
        onFinished()
    }
}
```

**Dependencia adicional**:
```kotlin
implementation("androidx.media3:media3-exoplayer:1.3.1")
implementation("androidx.media3:media3-ui:1.3.1")
```

El archivo de video va en `res/raw/piums_splash.mp4`.
`RootActivity`: mostrar `SplashVideoScreen` mientras `isLoading = true`; al terminar el video → `isLoading = false` con animación.

### 14.8 Fix de Disponibilidad en ArtistSearchByDate

Artistas sin calendario registrado en el backend deben considerarse **disponibles** (no bloqueados).

```kotlin
// INCORRECTO — podría crashear con NPE o marcar disponible erróneamente
val available = artistCal == null || (!artistCal!!.occupiedDates.contains(dateStr) && ...)

// CORRECTO
val available = if (artistCal != null) {
    !artistCal.occupiedDates.contains(dateStr) && !artistCal.blockedDates.contains(dateStr)
} else {
    true  // sin calendario = sin restricciones = disponible
}
```

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

---

## 15. AUTENTICACIÓN SOCIAL (Google, Facebook, TikTok)

### 15.1 AuthResponse — campos completos del backend

El backend devuelve `refreshToken` en **todos** los flujos (email, Google). El campo `isNewUser`
indica si es la primera vez que el usuario se registra (útil para mostrar onboarding).

```kotlin
data class AuthResponse(
    val token: String,
    val refreshToken: String,
    val user: AuthUser,
    val isNewUser: Boolean = false   // true si es registro nuevo por Google/social
)

// El backend devuelve AMBOS _id e id para compatibilidad. Usar "id".
data class AuthUser(
    val id: String,
    @SerializedName("_id") val mongoId: String? = null,  // alias — ignorar, usar id
    val email: String,
    val nombre: String?,         // puede ser null en cuentas nuevas
    val role: String,            // "cliente" | "artista"
    val avatar: String?,         // URL completa de Google (lh3.googleusercontent.com)
    val emailVerified: Boolean = false,
    val status: String = "ACTIVE"  // "ACTIVE" | "BANNED" | "SUSPENDED"
) {
    val displayName: String get() = nombre ?: email
    val isActive: Boolean get() = status == "ACTIVE"
}
```

### 15.2 Google Login — Firebase idToken

El flujo es: **GoogleSignIn SDK → Firebase idToken → POST /auth/firebase**

```kotlin
// data/repository/AuthRepository.kt
suspend fun loginWithGoogle(context: Context): AuthResponse {
    val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
        .requestIdToken(context.getString(R.string.default_web_client_id))
        .requestEmail()
        .build()
    val account = GoogleSignIn.getSignedInAccountFromIntent(/* intent */).await()
    val credential = GoogleAuthProvider.getCredential(account.idToken, null)
    val result = FirebaseAuth.getInstance().signInWithCredential(credential).await()
    val idToken = result.user?.getIdToken(false)?.await()?.token
        ?: throw Exception("No se obtuvo idToken de Firebase")
    return apiService.firebaseAuth(FirebaseAuthRequest(idToken = idToken, role = "cliente"))
}
```

**Firebase Project**: `piums-artista` (compartido con la app de artista)
- `BUNDLE_ID` iOS: `PIUMS.PiumsCliente`
- `APPLICATION_ID` Android: agregar la app Android en Firebase Console del proyecto `piums-artista`
- `google-services.json`: descargar desde Firebase Console → proyecto `piums-artista` → app Android

```kotlin
// build.gradle.kts (app)
apply(plugin = "com.google.gms.google-services")

// strings.xml — se llena automáticamente con google-services.json
// <string name="default_web_client_id">967320828042-...</string>
```

El body que se manda al backend:
```json
POST /auth/firebase
{ "idToken": "eyJhbGc...", "role": "cliente" }
```

**Verificación en el backend**: El backend usa la **Google Identity Toolkit REST API**
(`https://identitytoolkit.googleapis.com/v1/accounts:lookup`) con `FIREBASE_API_KEY`
— no usa Firebase Admin SDK. La verificación es criptográficamente equivalente.
`FIREBASE_API_KEY` es la clave pública del proyecto `piums-artista`.

**Errores controlados del endpoint:**
- `400` → `idToken` faltante o `role` inválido (valores permitidos: `"cliente"`, `"artista"`)
- `401` → token de Google inválido o expirado
- `403` → cuenta `BANNED` o `SUSPENDED`

### 15.3 Facebook y TikTok — OAuth via Custom Tab + Deep Link

**Diferencia clave con iOS**: iOS 17.4+ usa `ASWebAuthenticationSession.Callback.https` que intercepta
redirects HTTPS sin backend changes. Android NO tiene esta capacidad nativa — necesita un
**custom scheme** registrado en el AndroidManifest para capturar el callback.

**Flujo Android**:
1. App abre `CustomTabsIntent` con `https://api.piums.com/api/auth/facebook`
2. Backend Passport.js ejecuta OAuth con Facebook/TikTok
3. Backend redirige a `piums://auth/callback?token=JWT` (custom scheme)
4. Android intercepta el intent en `MainActivity`
5. App extrae `?token=JWT` y llama a `GET /api/auth/me`

**Requerimiento de backend**: el backend debe soportar redirect al custom scheme `piums://auth/callback`
además del HTTPS redirect que usa iOS. Confirmar con el equipo de backend antes de implementar.

```xml
<!-- AndroidManifest.xml -->
<activity android:name=".MainActivity" ...>
    <intent-filter android:autoVerify="false">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="piums" android:host="auth" android:pathPrefix="/callback" />
    </intent-filter>
</activity>
```

```kotlin
// utils/SocialAuthManager.kt
class SocialAuthManager @Inject constructor(
    private val tokenStorage: TokenStorage,
    private val apiService: PiumsApiService
) {
    fun launchFacebookAuth(context: Context) {
        val url = "https://api.piums.com/api/auth/facebook"
        CustomTabsIntent.Builder().build().launchUrl(context, Uri.parse(url))
    }

    fun launchTikTokAuth(context: Context) {
        val url = "https://api.piums.com/api/auth/tiktok"
        CustomTabsIntent.Builder().build().launchUrl(context, Uri.parse(url))
    }

    // Llamar desde MainActivity.onNewIntent o desde el NavHost
    suspend fun handleCallback(uri: Uri): AuthUser? {
        val error = uri.getQueryParameter("error")
        if (error != null) throw Exception(describeOAuthError(error))

        val token = uri.getQueryParameter("token")
            ?: throw Exception("No se recibió token")

        tokenStorage.saveToken(token)
        return apiService.getMe().user   // GET /api/auth/me
    }

    private fun describeOAuthError(code: String) = when (code) {
        "facebook_auth_failed"  -> "Error al autenticar con Facebook"
        "tiktok_auth_failed"    -> "Error al autenticar con TikTok"
        "tiktok_not_configured" -> "TikTok no está configurado en el servidor"
        "tiktok_denied"         -> "Acceso denegado por TikTok"
        else                    -> "Error de autenticación"
    }
}
```

```kotlin
// MainActivity.kt — interceptar el deep link
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    intent.data?.let { uri ->
        if (uri.scheme == "piums" && uri.host == "auth") {
            // Emitir al ViewModel o al NavController
            authViewModel.handleOAuthCallback(uri)
        }
    }
}
```

### 15.4 AuthViewModel — métodos sociales

```kotlin
// ui/screens/auth/AuthViewModel.kt
fun loginWithGoogle() {
    viewModelScope.launch {
        _uiState.update { it.copy(isLoading = true, error = null) }
        try {
            // ver sección 15.2 — launcher de Google Sign-In
            _uiState.update { it.copy(isLoading = false) }
        } catch (e: Exception) {
            _uiState.update { it.copy(isLoading = false, error = e.message) }
        }
    }
}

fun loginWithFacebook(context: Context) {
    viewModelScope.launch {
        socialAuthManager.launchFacebookAuth(context)
        // el resultado llega por handleOAuthCallback vía onNewIntent
    }
}

fun loginWithTikTok(context: Context) {
    viewModelScope.launch {
        socialAuthManager.launchTikTokAuth(context)
    }
}

fun handleOAuthCallback(uri: Uri) {
    viewModelScope.launch {
        _uiState.update { it.copy(isLoading = true, error = null) }
        try {
            val user = socialAuthManager.handleCallback(uri)
            authRepository.setCurrentUser(user)
            _uiState.update { it.copy(isLoading = false) }
        } catch (e: Exception) {
            _uiState.update { it.copy(isLoading = false, error = e.message) }
        }
    }
}
```

### 15.5 Dependencias adicionales para social auth

```kotlin
// build.gradle.kts
// Firebase
implementation(platform("com.google.firebase:firebase-bom:33.0.0"))
implementation("com.google.firebase:firebase-auth")

// Google Sign-In
implementation("com.google.android.gms:play-services-auth:21.1.0")

// Custom Tabs (para Facebook/TikTok)
implementation("androidx.browser:browser:1.8.0")
```
