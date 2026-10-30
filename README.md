# Medidor de cocina · AUTONOMÍA / Sendero Sonoro

Estación **Medidor** del proyecto de Taller IV. Una persona ciega o con baja visión mide un ingrediente sin depender de nadie: pone la taza, echa el ingrediente y **escucha** cuándo llegó al peso.

El sistema se oye, no se ve. La pantalla de Processing es solo para el equipo.

## Cómo funciona

```
Celda de carga ─ HX711 ─┐
Botón de cero ──────────┤
Botón de ayuda ─────────┼─ Arduino UNO ── USB (serial 9600) ── Processing ── voz y pantalla
Lector NFC (opcional) ──┤        │
                        └─ buzzer (pitidos)
```

- **Arduino** (`MedidorCocina/`): lee el peso, decide el estado, hace sonar el buzzer y manda mensajes de texto por serial.
- **Processing** (`medidorprocessing/`): lee esos mensajes, dibuja la interfaz y reproduce los audios de `data/`.

### Lo que vive la persona

1. Escucha la bienvenida al abrir el programa.
2. Pone la taza vacía y pulsa **dos veces** el **botón de cero** (el de la derecha, al frente): el primer toque dice qué botón es y el segundo pone la balanza en cero, descontando la taza.
3. (Opcional) Acerca una **ficha** NFC para elegir un peso (100 g o 250 g). Con la misma ficha otra vez se cancela la meta.
4. Echa el ingrediente poco a poco.
   - Con ficha: el pitido se acelera y sube de tono hasta un tono continuo en la meta.
   - Sin ficha: un tic corto cada 10 g.
5. Se queda quieto 2 s: pitido largo y la voz dice el peso.
6. Con meta, mientras llena, dice cuánto falta («Faltan 60 gramos»). Si se pasa (más de 10 g): tres pitidos graves y «Te pasaste. Quita 30 gramos».
7. Si se queda quieta 15 s, Processing repite la ayuda de ese momento (máximo 2 veces). Pulsar cero corta la bienvenida.
8. El **botón de ayuda** (el de la izquierda, también con doble toque) repite qué hacer según el momento. Los botones y dónde están las cosas solo se explican al comenzar. Mientras mide, dice «Llevas X de Y gramos»; si se pasó, «Te pasaste por X gramos».

### Estados del Arduino

| Estado | Cuándo | Mensaje serial |
|---|---|---|
| ESPERANDO | Plataforma vacía (menos de 20 g) | `ESPERA` |
| MIDIENDO | Hay peso y todavía cambia o falta llegar a la meta | `MIDIENDO` |
| LISTO | Peso estable 2 s (y dentro de la meta ±10 g, si hay) | `PESO:xxx` |
| PASADO | Más de 10 g sobre la meta | `PASADO:30` (gramos que sobran) |

### Mensajes del Arduino a Processing

| Mensaje | Qué hace Processing |
|---|---|
| `ESPERA`, `MIDIENDO` | Cambia el estado y dice la frase |
| `FALTA:60` | Dice «Faltan sesenta gramos» (solo con meta, al menos 20 g de cambio y cada 3 s como mínimo) |
| `PASADO:30` | Dice «Te pasaste. Quita treinta gramos» |
| `META:100` / `META:0` | Muestra y dice la meta / la quita |
| `PESO:250` | Muestra el número y dice «Este peso es…» |
| `CERO` | Dice «Balanza en cero» |
| `AYUDA` | Dice la ayuda según el estado |
| `LLEVA:60` | Dice «Llevas sesenta de cien gramos» |
| `ERROR:CELDA` | Dice «La balanza no responde» |
| `AVISO:CERO` | Dice «Hay peso en la balanza» |
| `ERROR:FICHA` | Dice «Ficha no reconocida» |
| `AVISO:RETIRA` | Dice «Retira la taza» |
| `TAG:xxxxxxxx` | Solo informativo (para copiar el UID a la tabla) |
| `G:xx.x` | Diagnóstico de peso; Processing lo ignora |

### Sonidos

Cada sonido tiene su tono: los graves son avisos y los agudos son confirmaciones.

| Sonido | Significa |
|---|---|
| Pitido de arranque | El Arduino encendió |
| Pitido (botón de cero, derecha) | Balanza en cero |
| Pitido corto (ficha) | Ficha leída |
| Un tic cada 10 g | Sin ficha: va llenando |
| Pitidos que se aceleran | Con ficha: se acerca a la meta |
| Tono continuo | Está en la meta |
| Pitido largo agudo | Peso confirmado |
| Tres pitidos graves rápidos | Te pasaste |
| Dos pitidos cortos | Meta cancelada |
| Tres pitidos muy graves | Error (celda sin respuesta o peso al pulsar cero) |
| Un pitido muy grave | Ficha desconocida, o hay algo en la balanza |

## Conexiones (Arduino UNO)

| Pieza | Pin del módulo | Arduino |
|---|---|---|
| HX711 | VCC / GND / DT / SCK | 5V / GND / 2 / 3 |
| Celda → HX711 | rojo / negro / blanco / verde | E+ / E− / A− / A+ |
| Buzzer | + / otro | 8 / GND |
| Botón de cero (derecha) | un lado | 4 (el otro lado a GND) |
| Botón de ayuda (izquierda) | un lado | 5 (el otro lado a GND) |
| RC522 (opcional) | SDA / SCK / MOSI / MISO / RST | 10 / 13 / 11 / 12 / 9 |
| RC522 | 3.3V / GND | 3.3V (**nunca 5V**) / GND |

Si el número baja al poner peso, intercambia A+ con A−.

## Cómo ponerlo en marcha

1. Plataforma **vacía**, conecta el Arduino por USB y sube `MedidorCocina/MedidorCocina.ino`. Librerías: **HX711** (Bogdan Necula) y **MFRC522** (Miguel Balboa).
2. Espera el pitido de arranque (ahí toma el cero).
3. Cierra el Monitor Serie del Arduino IDE.
4. Abre `medidorprocessing/MedidorProcessing.pde` con `SIMULAR = false` y el `PUERTO` correcto (librería **Sound**).
5. Pon la taza y pulsa dos veces el botón de cero (primer toque: dice qué es; segundo: lo ejecuta).

### Interruptores del código (arriba de `MedidorCocina.ino`)

| Interruptor | Para qué sirve |
|---|---|
| `USAR_NFC` | `true` cuando el lector RC522 está conectado |
| `SOLO_NFC` | `true` para la demo sin balanza: la ficha simula el peso |
| `SIMULAR` | `true` sin nada conectado: peso y fichas por el Monitor Serie |
| `MOSTRAR_PESO` | `true` imprime el peso en gramos para diagnosticar |
| `FACTOR` | Calibración de la balanza (hoy 1124) |
| `BUZZER_PASIVO` | `false` si el buzzer es activo |

En Processing, con `SIMULAR = true` las teclas 1 a 9 simulan los mensajes (espera, midiendo, pesos, meta, pasado, ayuda, cero). Con cualquier modo, las teclas `+` y `-` hacen la voz más rápida o más lenta (0.8 a 1.6).

### Fichas NFC

Con `USAR_NFC = true`, acerca la ficha y copia el `TAG:xxxxxxxx` del Monitor Serie a la tabla `TAGS` con su peso. Hoy: `F5C97E05` = 100 g y `620493EE` = 250 g.

### Calibración

1. Sube `Calibracion/Calibracion.ino` con la plataforma vacía.
2. Pon un peso exacto en el centro y espera 20 s.
3. Escribe el peso en gramos y Enter, **una sola vez**.
4. Copia el `FACTOR` que salga a `MedidorCocina.ino`.

## Archivos

| Carpeta | Contenido |
|---|---|
| `MedidorCocina/` | Código final del Arduino |
| `medidorprocessing/` | Interfaz y voz; audios en `data/` (voz sintética en `.wav`) |
| `Calibracion/` | Calcula el `FACTOR` con un peso conocido |
| `Guia-Montaje-Medidor.html` | Guía ilustrada: montaje de la balanza, conexiones y distribución en la caja (también en `.png`) |
| `Evaluacion-Heuristica-Medidor.xlsx` | Evaluación heurística de usabilidad |
| `PruebaCelda/` | Comprueba que el HX711 y la celda funcionan |
| `PruebaBuzzer/` | Comprueba el buzzer (pasivo o activo) |
| `audios_originales/` | Copia de los primeros audios en mp3 |
| `_archivo/` | Copias viejas y zips |

Los audios se buscan en `.mp3` y, si no están, en `.wav`. Para usar tu propia voz, copia un `.mp3` con el mismo nombre en `data/`.

## Si algo falla

| Síntoma | Qué revisar |
|---|---|
| La lectura salta, es negativa o cambia entre pruebas | Cable flojo, cero desplazado, objeto fuera del centro. Usa `PruebaCelda` |
| Marca de más o de menos de forma constante | Repetir `Calibracion` con un peso exacto |
| El buzzer no suena | `PruebaBuzzer`; si solo suena «HIGH», `BUZZER_PASIVO = false` |
| `Firmware Version: 0x0` | RC522 mal conectado (o `USAR_NFC = true` sin lector) |
| `TAG:…` pero no pasa nada | El UID no está en la tabla `TAGS` |
| Nunca llega a «listo» | Subir `TOLERANCIA` a 3 o 4 |
| Processing no muestra nada | Cerrar el Monitor Serie, revisar `PUERTO`, mirar la consola |
| Audios que no suenan | Mensajes `FALTA el clip` en la consola de Processing |

## Pendiente

- Estabilidad de la lectura (montaje físico de la celda) y calibración con un peso exacto.
- Embudo y pared en U impresos en 3D, aro para la taza y botones distintos al tacto.
- Prueba con persona vendada (Sprint 4).
