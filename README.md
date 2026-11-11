# AUTONOMÍA · Sendero Sonoro

Instalación de audio y tacto para que una persona ciega organice, mida y cocine sola. *Cocinar sin ver, sin depender de nadie.*

Proyecto de Taller IV · Diseño Interactivo · Universidad de Bogotá Jorge Tadeo Lozano · 2026.

## Equipo

| Estación | Quién la construyó |
|---|---|
| **Medidor** | Mariana Bravo |
| **Organización** | Sara Loza |
| **Cocina** | Shara Meneses y Daniela Rojas |

Equipo AUTONOMÍA: Mariana Bravo, Shara Meneses, Daniela Rojas y Sara Loza.

## Las tres estaciones

La receta es un parfait. La persona pasa por tres estaciones, de la más fácil a la más difícil.

| Carpeta | Estación | Qué hace | Con qué |
|---|---|---|---|
| [`organizacion/`](organizacion/) | Organización | Acerca un vaso al lector y oye qué ingrediente es y en qué posición va; confirma con sonido si lo puso bien | Arduino, NFC, sensores y Python |
| [`medidor/`](medidor/) | Medidor | Pesa el ingrediente y avisa por voz y pitidos cuánto falta, si llegó o si se pasó | Arduino, celda de carga, NFC y Processing |
| [`cocina/`](cocina/) | Cocina | Toca un contacto y oye el nombre del ingrediente | Makey Makey y Processing |

Cada carpeta tiene su propio README con cómo montarla, cómo correrla y qué hacer si algo falla.

## Por dónde empezar

- **Medidor:** en Windows no hace falta instalar nada: hay un ejecutable. Mira «Abrirlo rápido» en [`medidor/README.md`](medidor/README.md).
- **Organización:** Python 3 con `pyserial`, en Windows. Detalle en [`organizacion/README.md`](organizacion/README.md).
- **Cocina:** Processing 4 con la librería Minim. Detalle en [`cocina/README.md`](cocina/README.md).

## Voz

Las tres estaciones hablan con la misma voz: Microsoft Sabina (español), a velocidad −1, pregrabada en WAV. Así suenan igual en cualquier computador, sin depender de las voces que tenga instaladas.

Los textos de Cocina y Organización están en [`voz/textos.json`](voz/textos.json). Para cambiar una frase, edítala ahí y corre, desde la raíz del repositorio:

```
powershell -ExecutionPolicy Bypass -File voz\generar_voces.ps1
```

## Diseño

La interfaz del Medidor sigue el design system de AUTONOMÍA: tema oscuro para pantallas, Atkinson Hyperlegible para el texto (diseñada para baja visión) y estados que nunca se comunican solo con color: cada uno lleva palabra, forma y sonido.
