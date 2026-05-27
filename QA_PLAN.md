# Plan QA — PiumsCliente iOS
> Versión 1.0 · Abril 2026  
> Objetivo: pruebas robustas en entorno real con intención de encontrar y documentar fallos para su corrección.

---

## Dispositivos y entornos de prueba

| Dispositivo | iOS | Red |
|-------------|-----|-----|
| iPhone principal (desarrollo) | iOS 18+ | WiFi estable |
| iPhone secundario (si disponible) | iOS 17 | Datos móviles |
| Simulador Xcode | iOS 18 | Sin red / red degradada |

**Backend apuntado:** producción (`piums.io`)  
**Usuarios de prueba:** cuenta cliente real + cuenta artista real (para ver el otro lado)

---

## Módulo 1 — Autenticación

### 1.1 Registro
- [ ] Registro completo con datos válidos → navega a Home
- [ ] Registro con email ya existente → muestra error específico
- [ ] Registro con contraseña débil → barra de seguridad refleja nivel correcto
- [ ] Registro con contraseñas que no coinciden → borde rojo en campo confirmar
- [ ] Botón "Crear cuenta" deshabilitado si algún campo está vacío
- [ ] Botón deshabilitado si no se aceptan términos
- [ ] Tap fuera del teclado cierra el teclado
- [ ] Submit desde teclado (botón "Done") en último campo lanza registro
- [ ] Registro sin conexión → error de red visible

### 1.2 Login
- [ ] Login con credenciales correctas → navega a Home
- [ ] Login con contraseña incorrecta → mensaje de error claro
- [ ] Login con email no registrado → mensaje de error claro
- [ ] Login sin conexión → error de red visible
- [ ] "¿Olvidaste tu contraseña?" navega a ForgotPasswordView
- [ ] Toggle de mostrar/ocultar contraseña funciona

### 1.3 Sesión
- [ ] Cerrar sesión desde Perfil → regresa a login, limpia datos
- [ ] Cerrar y reabrir la app → sesión persiste si no se cerró manualmente
- [ ] Token expirado durante uso → redirige a login sin crash
- [ ] Google Sign-In inicia sesión correctamente

---

## Módulo 2 — Home

- [ ] Saludo con nombre del usuario carga correctamente
- [ ] Artistas recomendados cargan (no lista vacía si hay datos en backend)
- [ ] Pull-to-refresh actualiza el contenido
- [ ] Tap en artista recomendado abre su perfil
- [ ] Banner promo: botón "Register Now" navega a búsqueda por fecha
- [ ] Sección de próximas reservas aparece si hay reservas confirmadas
- [ ] Home sin conexión muestra estado vacío (no crash)
- [ ] Notificaciones: campana con badge si hay no leídas

---

## Módulo 3 — Búsqueda y exploración

### 3.1 Búsqueda libre
- [ ] Buscar texto abierto devuelve resultados relevantes (SmartSearch)
- [ ] Resultados muestran nombre, especialidad, precio y calificación del artista
- [ ] Scroll hasta el final carga más resultados (paginación)
- [ ] Sin resultados muestra estado vacío descriptivo
- [ ] Búsqueda sin conexión muestra error

### 3.2 Filtros
- [ ] Abrir sheet de filtros
- [ ] Filtro por **Talento específico** abre TalentPickerView
- [ ] Seleccionar talento → chip activo aparece en barra, búsqueda usa ese talento
- [ ] Limpiar talento desde chip → se remueve y búsqueda se actualiza
- [ ] Filtro por especialidad (categorías: DJ, Música, Foto, etc.)
- [ ] Filtro por rango de precio (slider min/max)
- [ ] Filtro por calificación mínima
- [ ] Filtro por ciudad
- [ ] Toggle solo verificados
- [ ] Ordenar por: relevancia, precio asc/desc, calificación
- [ ] "Limpiar todos los filtros" resetea todo y actualiza resultados
- [ ] Chips activos en barra reflejan cada filtro aplicado

### 3.3 Búsqueda por fecha y lugar
- [ ] Seleccionar fecha muestra artistas disponibles ese día
- [ ] Seleccionar ubicación filtra por cercanía
- [ ] Artista sin disponibilidad en fecha elegida no aparece

---

## Módulo 4 — Perfil de Artista

- [ ] Foto, nombre, especialidad y calificación cargan
- [ ] Servicios del artista cargan desde API (no mock)
- [ ] Si API de servicios falla → muestra error, no datos inventados ✓ (corregido)
- [ ] Reseñas del artista cargan desde API (no mock)
- [ ] Si API de reseñas falla → muestra error, no datos inventados ✓ (corregido)
- [ ] Portfolio de imágenes/videos carga
- [ ] Botón "Reservar" abre flujo de reserva
- [ ] Botón "Favorito" (corazón) agrega/quita de favoritos
- [ ] Calificación promedio y número de reseñas son correctos

---

## Módulo 5 — Flujo de Reserva

- [ ] Paso 1: Seleccionar servicio del artista
- [ ] Paso 2: Calendario muestra días ocupados/bloqueados correctamente
- [ ] Paso 3: Slots de horarios cargan desde API para la fecha elegida
- [ ] Si API de slots falla → muestra error (no slots inventados) ✓ (corregido)
- [ ] Días sin disponibilidad no son seleccionables
- [ ] Paso 4: Resumen de reserva con precio correcto
- [ ] Confirmar reserva crea la reserva en backend
- [ ] Reserva aparece en Mi Espacio tras confirmar
- [ ] Salir del flujo a mitad → no crea reserva incompleta

---

## Módulo 6 — Mi Espacio

### 6.1 Reservas
- [ ] Lista de reservas carga (pendientes, confirmadas, completadas, canceladas)
- [ ] Filtrar por estado funciona
- [ ] Tap en reserva abre detalle completo
- [ ] Deep link de reserva (notificación push) navega directamente al detalle
- [ ] Pull-to-refresh actualiza estados
- [ ] Paginación al llegar al final de la lista

### 6.2 Eventos
- [ ] Lista de eventos carga correctamente
- [ ] Crear evento con nombre, fecha y descripción
- [ ] Editar evento existente
- [ ] Eliminar evento con confirmación
- [ ] Compartir evento
- [ ] Vincular reserva a evento → **SuccessBannerView aparece 3 segundos** ✓ (implementado)
- [ ] Si vincular falla → ErrorBannerView aparece ✓ (implementado)
- [ ] Reservas ya vinculadas no aparecen en el picker

### 6.3 Favoritos
- [ ] Lista de artistas favoritos carga
- [ ] Quitar de favoritos actualiza la lista inmediatamente
- [ ] Tap en artista favorito abre su perfil

---

## Módulo 7 — Mensajes / Chat

- [ ] Lista de conversaciones carga (no "Sin mensajes" si hay datos) ✓ (corregido)
- [ ] Nombre del artista visible en cada conversación
- [ ] Último mensaje y hora visible en cada fila
- [ ] Badge de no leídos en fila de conversación
- [ ] Badge en tab bar refleja total de no leídos
- [ ] Abrir conversación carga mensajes
- [ ] Burbujas propias a la derecha (naranja), artista a la izquierda ✓ (corregido)
- [ ] Enviar mensaje con socket conectado → aparece inmediatamente
- [ ] Enviar mensaje sin socket (fallback HTTP) → aparece correctamente
- [ ] Recibir mensaje en tiempo real mientras el chat está abierto
- [ ] Badge se actualiza al recibir mensaje con app en foreground
- [ ] Abrir conversación marca mensajes como leídos
- [ ] Scroll al mensaje más reciente al abrir chat
- [ ] Teclado no tapa el campo de texto al abrirse

---

## Módulo 8 — Notificaciones

- [ ] Notificaciones cargan en lista
- [ ] Badge en campana refleja no leídas
- [ ] Marcar notificación como leída (tap) actualiza el badge
- [ ] "Marcar todas como leídas" funciona
- [ ] Paginación de notificaciones
- [ ] Notificación push llega con app en background
- [ ] Tap en notificación push abre la pantalla correcta (reserva, mensaje, etc.)

---

## Módulo 9 — Perfil y Cuenta

- [ ] Datos del usuario cargan (nombre, email, foto)
- [ ] Editar perfil guarda cambios en backend
- [ ] Foto de perfil se puede cambiar
- [ ] Sección "Cómo funciona Piums?" abre el tutorial
- [ ] Sección de historial de reseñas
- [ ] Cerrar sesión con confirmación funciona
- [ ] Ajustes de configuración persisten

---

## Módulo 10 — Tutorial Interactivo

- [ ] Tutorial aparece automáticamente al primer inicio tras registro
- [ ] Pantalla intro muestra los 8 atajos de sección, cada uno navega al tab correcto
- [ ] "Iniciar tour interactivo" cierra sheet y activa overlay sobre la app real
- [ ] Overlay aparece con backdrop, flecha apuntando al tab activo
- [ ] 6 pasos navegan al tab correcto automáticamente al avanzar
- [ ] Botón "← atrás" regresa al paso anterior
- [ ] Botón "Ir a [Sección]" navega y cierra el tour
- [ ] Botón ✕ cierra el tour en cualquier paso
- [ ] "¡Listo!" en último paso cierra correctamente
- [ ] Segundo acceso al tutorial (desde Perfil) funciona igual
- [ ] `AppStorage("hasSeenHowItWorks")` evita que reaparezca automáticamente

---

## Módulo 11 — Quejas / Disputas

- [ ] Lista de quejas/disputas carga
- [ ] Crear nueva queja asociada a una reserva
- [ ] Chat de disputa: mensajes cargan y se pueden enviar
- [ ] Estados de disputa se muestran correctamente (Abierta, En revisión, Resuelta, etc.)

---

## Módulo 12 — Onboarding

- [ ] Aparece solo en primer inicio
- [ ] 3 pasos de selección de intereses
- [ ] Mínimo de intereses para continuar
- [ ] Sub-tags de cada categoría seleccionables
- [ ] Guarda preferencias en backend
- [ ] "Omitir" salta el onboarding sin crash

---

## Pruebas de red y estados de error

| Escenario | Comportamiento esperado |
|-----------|------------------------|
| Sin internet al abrir | Estado vacío en cada pantalla, no crash |
| Internet se corta durante carga | Mensaje de error con opción de reintentar |
| Respuesta lenta (>5s) | Loading spinner visible |
| Backend devuelve 401 | Redirige a login |
| Backend devuelve 500 | Error genérico amigable |
| Paginación en lista larga | Carga más al llegar al final |
| Pull-to-refresh | Recarga datos frescos |

---

## Pruebas de dispositivo y sistema

| Prueba | Notas |
|--------|-------|
| Dynamic Type tamaño grande | Textos no se truncan, layouts no se rompen |
| iPhone SE (pantalla pequeña) | Cards y botones accesibles |
| iPhone Pro Max (pantalla grande) | Espaciado proporcional |
| Modo oscuro | Toda la UI usa paleta dark correctamente |
| Rotar a landscape | No crash (aunque la app es portrait-first) |
| App en background → foreground | Datos se refrescan, socket se reconecta |
| Llamada entrante mientras se usa | App pausa y reanuda correctamente |
| Bajo nivel de batería / modo ahorro | No afecta funcionalidad core |

---

## Cómo documentar un fallo

Para cada fallo encontrado, registrar:

```
## Bug #[número]
**Módulo:** [ej. Chat]
**Pantalla:** [ej. ChatDetailView]
**Pasos para reproducir:**
1. ...
2. ...
**Resultado esperado:** ...
**Resultado real:** ...
**Severidad:** Crítico / Alto / Medio / Bajo
**Captura / Log:** [adjuntar screenshot o stack trace de Xcode]
```

---

## Criterios de aprobación

- **Crítico (bloqueante):** 0 bugs sin resolver antes de publicar
- **Alto:** Máximo 2 bugs conocidos con workaround documentado
- **Medio/Bajo:** Se pueden publicar con ticket creado para próxima versión

---

## Checklist final antes de publicar

- [ ] Todos los módulos críticos (1–8) sin bugs bloqueantes
- [ ] App firmada con certificado de distribución
- [ ] Bundle ID y versión correctos (`PIUMS.PiumsCliente` · v1.0)
- [ ] No hay logs de debug (`print(`, `debugPrint(`) en código de producción
- [ ] URL base apunta a producción, no a localhost
- [ ] Notificaciones push configuradas para producción (APN production)
- [ ] App probada en al menos 2 dispositivos físicos distintos
