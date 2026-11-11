# Organización · AUTONOMÍA / Sendero Sonoro

Estación **Organización** del proyecto de Taller IV, construida por Sara. Ayuda a armar un parfait: la persona acerca un vaso al lector y la estación le dice qué ingrediente es y en qué posición va. Después confirma por sonido y voz si lo puso bien.

## Cómo funciona

```
Lector NFC + sensores (switch) ── Arduino ── USB (serial 115200) ── Python ── voz y sonidos
```

- El **Arduino** lee el lector NFC de cada vaso y los sensores de las posiciones, y manda mensajes de texto por serial.
- **Python** (`audio_perfait.py`) lee esos mensajes y habla o suena.

### Lo que vive la persona

1. Escucha la bienvenida: puede explorar los vasos con calma, acercar uno al lector, llevarlo a la base sin arrastrarlo y colocarlo suavemente.
2. Acerca un vaso al lector y oye el ingrediente y la posición: «Fresas. Debe ir en la posición cuatro».
3. Oye «Levanta el vaso y colócalo suavemente sobre el espacio indicado».
4. Si lo puso bien: dos sonidos cortos y «Correcto. Continúa con el siguiente vaso».
5. Si no: un sonido grave y «Incorrecto. Intenta nuevamente».
6. Al terminar: «Excelente. Has completado correctamente la organización del parfait».

### Ingredientes y posiciones

Cinco ingredientes: yogurt, granola, frutos secos, fresas y arándanos. Las posiciones van de la uno a la cinco.

### Mensajes del Arduino a Python

| Mensaje | Qué hace Python |
|---|---|
| `INGREDIENTE:<nombre>` | Guarda el ingrediente leído (`YOGURT`, `GRANOLA`, `FRUTOS SECOS`, `FRESAS`, `ARANDANOS`) |
| `DEBE IR EN POSICION:<n>` | Dice el ingrediente y la posición, y pide colocar el vaso |
| `CORRECTO` | Dos pitidos agudos y confirmación por voz |
| `INCORRECTO` | Un pitido grave y «Intenta nuevamente» |
| `PARFAIT COMPLETADO` | Felicita y cierra la secuencia |

## Cómo ponerlo en marcha

1. Instala **Python 3** y la librería: `pip install pyserial`.
2. Necesita **Windows** (usa `winsound`, que ya viene con Python). La voz va pregrabada en `audios/`, así que no hace falta tener ninguna voz instalada.
3. Conecta el Arduino por USB y mira su puerto en el Administrador de dispositivos.
4. En `audio_perfait.py`, cambia `PUERTO` si no es `COM4`. La velocidad es `BAUDIOS = 115200`.
5. Ejecuta `python audio_perfait.py`. Para terminar, `Ctrl + C`.

## Archivos

| Archivo | Contenido |
|---|---|
| `audio_perfait.py` | Voz y sonidos de la estación |
| `audios/` | La voz de la estación: bienvenida, ingredientes (`ing_*.wav`), posiciones (`pos_1` a `pos_5`), `levanta`, `correcto`, `incorrecto` y `completado` |

La voz es la misma del Medidor (Microsoft Sabina). Para cambiar una frase, edita `voz/textos.json` en la raíz del repositorio y corre `voz/generar_voces.ps1`.

## Por completar por Sara

- El código del Arduino (lectura del NFC y de los sensores), que no está en esta carpeta.
- Cómo quedan conectados el lector y los sensores, y dónde va cada posición en la base.
- Qué etiqueta NFC lleva cada vaso.
