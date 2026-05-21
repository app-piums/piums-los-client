# Piums Cliente iOS — Nuevas Features (Mayo 2026)

> Guía de implementación para las funcionalidades añadidas desde la entrega de tickets/eventos hasta 2026-05-20.
> El backend expone todas estas rutas bajo `https://backend.piums.io`. El cliente iOS usa `https://client.piums.io` como proxy para rutas autenticadas.

---

## 1. Tickets y Eventos de Conciertos

### Qué puede hacer el cliente
- Explorar eventos publicados por artistas (conciertos, festivales, fiestas)
- Ver tiers de precio (General, VIP, etc.) con disponibilidad en tiempo real
- Comprar boletos con tarjeta (flujo Tilopay existente)
- Ver sus boletos comprados con código QR para entrada
- Filtrar por fecha, categoría y disponibilidad

### Modelos Swift

```swift
struct TicketEvent: Codable, Identifiable {
    let id: String
    let code: String
    let artistId: String
    let name: String
    let description: String?
    let venue: String
    let address: String
    let locationLat: Double?
    let locationLng: Double?
    let eventDate: String          // ISO 8601
    let doorsOpen: String?
    let imageUrl: String?
    let maxCapacity: Int
    let status: String             // BORRADOR | PUBLICADO | AGOTADO | CANCELADO | FINALIZADO
    let tiers: [TicketTier]
    let createdAt: String
}

struct TicketTier: Codable, Identifiable {
    let id: String
    let ticketEventId: String
    let name: String
    let description: String?
    let priceCents: Int
    let currency: String
    let totalQty: Int
    let soldQty: Int               // disponible = totalQty - soldQty
}

struct TicketPurchase: Codable, Identifiable {
    let id: String
    let code: String               // código QR
    let ticketEventId: String
    let tierId: String
    let buyerId: String
    let buyerEmail: String
    let buyerName: String
    let quantity: Int
    let subtotalCents: Int
    let discountCents: Int
    let totalCents: Int
    let currency: String
    let couponCode: String?
    let status: String             // PENDIENTE | PAGADO | USADO | REEMBOLSADO | EXPIRADO
    let paidAt: String?
    let checkedInAt: String?
    let ticketEvent: TicketEvent?
    let tier: TicketTier?
    let createdAt: String
}
```

### Endpoints

| Acción | Método | URL |
|--------|--------|-----|
| Listar eventos públicos | GET | `/api/ticket-events?page=1&limit=12` |
| Detalle de evento | GET | `/api/ticket-events/{id}` |
| Mis boletos | GET | `/api/ticket-purchases/my` *(auth)* |
| Detalle de boleto | GET | `/api/ticket-purchases/{id}` *(auth)* |
| Comprar boleto | POST | `/api/ticket-events/{eventId}/purchase` *(auth)* |

**Body compra:**
```json
{
  "tierId": "uuid",
  "quantity": 1,
  "buyerName": "Juan Pérez",
  "buyerEmail": "juan@email.com",
  "couponCode": "PROMO10",
  "returnUrl": "piums://tickets/confirmacion/{purchaseId}"
}
```

### Vistas recomendadas

- `TicketsView` — grid de cards con imagen, nombre, venue, fecha mínima de precio
- `TicketDetailView` — hero image, info completa, selector de tier con disponibilidad, botón comprar
- `MyTicketsView` — lista de compras separadas en "Próximos" y "Pasados"
- `TicketCardView` — muestra código QR generado del campo `code` usando `CoreImage` o librería QR
- Polling cada 3s tras compra hasta que `status == "PAGADO"` (máx 10 intentos)

---

## 2. Ofertas del Día (Day Offers)

### Qué puede ver el cliente
- Al ver el perfil de un artista o el detalle de un servicio, si el artista activó una oferta del día, se muestra el precio con descuento
- El descuento se aplica automáticamente al hacer la reserva ese día

### Modelo Swift

```swift
struct ServiceDayOffer: Codable, Identifiable {
    let id: String
    let serviceId: String
    let artistId: String
    let discountPercent: Int?
    let discountAmount: Int?        // en centavos
    let note: String?
    let isActive: Bool
    let validFrom: String?
    let validUntil: String?
    let createdAt: String
}
```

### Endpoint
```
GET /api/catalog/services/{serviceId}/day-offers/public
```
Retorna lista de ofertas activas del día. Mostrar el badge de descuento en la tarjeta del servicio si hay alguna activa hoy.

---

## 3. Solicitud de Cambio de Fecha (Reschedule)

### Flujo cliente
1. Cliente solicita nueva fecha desde el detalle de su reserva (solo si la reserva es futura con >24h de anticipación)
2. El artista recibe la notificación `RESCHEDULE_REQUEST` y acepta/rechaza
3. Si acepta, el cliente recibe email con enlace para confirmar el cambio definitivo
4. El cliente confirma → la reserva se actualiza a la nueva fecha

### Endpoints

| Acción | Método | URL |
|--------|--------|-----|
| Crear solicitud | POST | `/api/bookings/{id}/reschedule-request` *(auth)* |
| Confirmar (link email) | GET | `/api/reschedule-requests/confirm?token=...` |

**Body crear solicitud:**
```json
{
  "proposedDate": "2026-06-15T20:00:00.000Z",
  "reason": "Cambio de planes en el evento"
}
```

### Validaciones
- Solo reservas en estado: `PENDING`, `CONFIRMED`, `PAYMENT_PENDING`, `PAYMENT_COMPLETED`
- La fecha actual de la reserva debe ser futura con al menos 24h de anticipación
- Si la reserva ya pasó (`hoursUntilBooking < 0`): error "No puedes reprogramar una reserva cuya fecha ya pasó"
- Si faltan menos de 24h: error "No puedes solicitar cambio de fecha con menos de 24 horas de anticipación"

### Vista
En `BookingDetailView`: botón "Solicitar cambio de fecha" que abre `ModifyDateSheet`:
- Mostrar fecha actual
- DatePicker para nueva fecha (mínimo: ahora + 24h)
- Campo opcional de motivo

---

## 4. Sistema de Disputas / Quejas

### Qué puede hacer el cliente
- Reportar un problema con una reserva (artista no se presentó, servicio no cumplió, etc.)
- Ver el estado de sus disputas abiertas
- Chatear con el equipo de Piums dentro de la disputa

### Modelos Swift

```swift
struct Dispute: Codable, Identifiable {
    let id: String
    let bookingId: String
    let clientId: String
    let artistId: String
    let reason: String
    let description: String
    let status: String    // OPEN | UNDER_REVIEW | RESOLVED | CLOSED
    let resolution: String?
    let createdAt: String
    let updatedAt: String
}

struct DisputeMessage: Codable, Identifiable {
    let id: String
    let disputeId: String
    let senderId: String
    let senderRole: String   // cliente | artista | admin
    let content: String
    let createdAt: String
}
```

### Endpoints

| Acción | Método | URL |
|--------|--------|-----|
| Crear disputa | POST | `/api/disputes` *(auth)* |
| Mis disputas | GET | `/api/disputes/me` *(auth)* |
| Detalle | GET | `/api/disputes/{id}` *(auth)* |
| Mensajes | GET | `/api/disputes/{id}/messages` *(auth)* |

**Body crear disputa:**
```json
{
  "bookingId": "uuid",
  "reason": "artist_no_show",
  "description": "El artista no llegó al evento"
}
```

### Vistas
- `DisputasView` — lista de disputas del cliente con badge de estado
- `DisputeDetailView` — hilo de mensajes + estado actual + resolución si existe
- Accesible desde `BookingDetailView` con botón "Reportar problema" (solo reservas CONFIRMED/COMPLETED)

---

## 5. Colaboradores en Reservas (Vista de solo lectura)

### Qué ve el cliente
Cuando un artista invitó y tiene colaboradores aceptados en una reserva, el cliente ve en el detalle de su reserva una sección **"Equipo adicional"** con el nombre y rol de cada colaborador.

### Endpoint
```
GET /api/bookings/{bookingId}/collaborators
```
Retorna array de `BookingCollaborator`. Filtrar solo `status == "ACCEPTED"`.

### Modelo Swift

```swift
struct BookingCollaborator: Codable, Identifiable {
    let id: String
    let bookingId: String
    let artistId: String
    let invitedBy: String
    let role: String?
    let status: String    // INVITED | ACCEPTED | REJECTED | CANCELLED
    let notes: String?
    let invitedAt: String
    let respondedAt: String?
    // Enriched
    let artistName: String?
    let artistAvatar: String?
}
```

### Vista
En `BookingDetailView`, sección "Equipo adicional" (solo si hay colaboradores aceptados):
```swift
if !collaborators.isEmpty {
    Section("Equipo adicional") {
        ForEach(collaborators) { collab in
            HStack {
                AsyncImage(url: URL(string: collab.artistAvatar ?? "")) // avatar
                VStack(alignment: .leading) {
                    Text(collab.artistName ?? "Colaborador").font(.subheadline.bold())
                    if let role = collab.role {
                        Text(role).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
```

---

## 6. Google Calendar (Cliente)

### Qué puede hacer el cliente
- Conectar su Google Calendar desde Perfil → Configuración
- Al confirmar una reserva, el evento se agrega automáticamente a su calendario
- Desconectar en cualquier momento

### Endpoints

| Acción | Método | URL |
|--------|--------|-----|
| Estado de conexión | GET | `/api/auth/google-calendar/status` *(auth)* |
| Conectar | Redirect | `https://backend.piums.io/api/auth/google/calendar-connect?token={jwt}` |
| Desconectar | POST | `/api/auth/google-calendar/disconnect` *(auth)* |

### Implementación iOS (ASWebAuthenticationSession)
```swift
func connectGoogleCalendar(token: String) {
    let url = URL(string: "https://backend.piums.io/api/auth/google/calendar-connect?token=\(token)")!
    let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: "piums"
    ) { callbackURL, error in
        guard let url = callbackURL else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if components?.queryItems?.first(where: { $0.name == "calendarConnected" })?.value == "true" {
            // Actualizar estado: calendario conectado
        }
    }
    session.presentationContextProvider = self
    session.start()
}
```

**Callback URL:** `piums://profile/personal?calendarConnected=true`

Agregar `piums` al `LSApplicationQueriesSchemes` en Info.plist y como URL Scheme.

---

## 7. Notificaciones (Tipos nuevos)

Tipos adicionales que el cliente puede recibir vía push/FCM:

| Tipo | Descripción |
|------|-------------|
| `DELIVERY_PROBLEM_REPORTED` | Problema reportado en una entrega |
| `dispute_opened` | Disputa abierta en una reserva |
| `COUPON_EXPIRING` | Cupón próximo a vencer |
| `COUPON_SENT` | Nuevo cupón recibido |
| `DISCOUNT` | Oferta/descuento disponible |
| `RESCHEDULE_REQUEST` | Artista aceptó tu solicitud de cambio de fecha |

Manejar en `userNotificationCenter(_:didReceive:)` con deep link al recurso correspondiente.
