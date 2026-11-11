# Cocina · AUTONOMÍA / Sendero Sonoro

Estación **Cocina** del proyecto de Taller IV, construida por Shara y Daniela con Makey Makey. Se llama "Cocina sensorial: parfait inclusivo". La persona toca un contacto y oye el nombre del ingrediente.

## Cómo funciona

```
Contacto 1..4 ── Makey Makey ── USB (teclado) ── Processing ── audio
```

- El **Makey Makey** entra al computador como un teclado. Cada contacto manda una flecha.
- **Processing** (`cocina/cocina.pde`) escucha las flechas y reproduce el audio de `cocina/data/`.

### Qué oye la persona

1. Al abrir el programa suena la **bienvenida**. Mientras suena, los toques se ignoran.
2. Después, cada flecha dice un ingrediente:

| Flecha | Audio | Dice |
|---|---|---|
| Arriba | `yogur.wav` | El camino al yogur griego, de fomi moldeable |
| Abajo | `granola.wav` | El camino a la granola, de algodón |
| Izquierda | `fresas.wav` | El camino a las fresas, de palos de balso |
| Derecha | `arandanos.wav` | El camino a los arándanos, de limpiapipas |

3. Si deja el dedo sostenido, el audio no se reinicia.
4. Si toca otro contacto, el audio anterior se corta y suena el nuevo.

## Cómo ponerlo en marcha

1. Instala **Processing 4** y, desde *Herramientas > Gestionar herramientas > Bibliotecas*, la librería **Minim**. El Medidor usa **Sound**; esta estación usa **Minim**.
2. Conecta el Makey Makey por USB al computador.
3. Abre `cocina/cocina.pde` y pulsa **Ejecutar**.
4. Espera a que termine la bienvenida y toca los contactos. Sin Makey Makey, se prueba con las flechas del teclado.

## Archivos

| Archivo | Contenido |
|---|---|
| `cocina/cocina.pde` | Código de la estación |
| `cocina/data/bienvenida.wav` | Audio de bienvenida |
| `cocina/data/yogur.wav`, `granola.wav`, `fresas.wav`, `arandanos.wav` | Un audio por ingrediente |

Los audios deben estar en la carpeta `cocina/data/` junto al `.pde`, con esos nombres.

La voz es la misma del Medidor (Microsoft Sabina). Para cambiar una frase, edita `voz/textos.json` en la raíz del repositorio y corre `voz/generar_voces.ps1`.

## Por completar por Shara y Daniela

- Qué objeto o contacto físico toca la persona para cada flecha, y cómo queda en la mesa.
- Cómo se cierra el circuito del Makey Makey (tierra, pulsera o contacto en la mesa).
- Si la estación va a seguir una receta en orden, con confirmación y error, o solo nombra los ingredientes.
