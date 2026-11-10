// AUTONOMÍA / Sendero Sonoro - Estación Medidor
// Lee el serial del Arduino, reproduce los audios de la carpeta "data" y muestra la interfaz.
// Librería: Sound. Cierra el Monitor Serie del Arduino IDE antes de correr.
//
// MODO SIMULACIÓN (SIMULAR = true): no necesita Arduino. Teclas:
//   1 = ESPERA    2 = MIDIENDO    3 = PESO:100    4 = PESO:500    5 = PESO:250
//   6 = META:100  7 = PASADO:30   8 = AYUDA       9 = CERO        0 = FALTA:40
// En cualquier modo: + y - hacen la voz más rápida o más lenta. T cambia entre tema oscuro y claro.
//
// Interfaz: design system AUTONOMÍA (componente InterfazMedidor).
// Fuentes: AtkinsonHyperlegible-Bold.ttf y JetBrainsMono-Bold.ttf en "data" (viajan con la carpeta).
// Si faltan, usa la fuente instalada con ese nombre y, si tampoco, Segoe UI y Consolas.
//
// Audios: se piden por su nombre sin extensión ("espera") y se busca primero el .mp3 y luego el .wav.
// Para cambiar una voz, copia un .mp3 con el mismo nombre en "data".
import processing.serial.*;
import processing.sound.*;

final boolean SIMULAR = false;                // true = sin Arduino, con las teclas de arriba
final String PUERTO = "";                     // "" = lo busca solo. Si elige mal, escribe aquí el tuyo (ej. "COM3")

// Tokens de color del design system AUTONOMÍA. Los de tema se llenan en aplicarTema()
boolean temaOscuro = true;                    // Oscuro para pantallas; claro para imprimir
color SURFACE_100, SURFACE_200, SURFACE_300, INK, INK_SOFT, BRAND, BRAND_STRONG, ON_BRAND, LINE;
final color STATE_ESPERA = #a0acc4;           // Espera: círculo hueco
final color STATE_MIDE   = #deaa62;           // Midiendo: triángulo
final color STATE_LISTO  = #7ab694;           // Listo: visto
final color STATE_PASADO = #d47e7a;           // Te pasaste o Error: equis
final color ON_STATE     = #1b1230;           // Texto sobre cualquier state-*
PFont fSans, fMono;                           // Atkinson Hyperlegible (texto) y JetBrains Mono (cifras)

// Voz
ArrayList<String> cola = new ArrayList<String>();   // Clips en espera, en orden
SoundFile sonando = null;
int finClip = 0;                                    // millis() en que termina el clip actual
float velocidadVoz = 1.0;                           // 1.0 = normal. Teclas + y - la cambian (0.8 a 1.6)
final int ESPERA_RECORDATORIO = 15000;              // ms sin actividad antes de repetir la ayuda
final int MAX_RECORDATORIOS = 2;                    // veces que repite antes de callar
int ultimaActividad = 0;                            // millis() del último mensaje del Arduino
int recordatorios = 0;

// Estado que muestra la pantalla
final String FRASE_ESPERA = "Pon el ingrediente en la pesa";
String estado = "ESPERA";                     // ESPERA, MIDIENDO, LISTO o PASADO
int meta = 0;                                 // Meta en gramos que fijó la ficha NFC (0 = sin ficha)
String frase = FRASE_ESPERA;                  // Lo que dice la voz, escrito
String fraseAviso = null;                     // Si frase es un aviso o error, se marca con la pill "Error"
int pesoVisto = -1;                           // Gramos conocidos mientras mide o se pasa (-1 = no se sabe)
int pesoObjetivo = 0;                         // Peso confirmado (LISTO)
float pesoAnim = 0;                           // Número que "sube" hasta el peso confirmado
float progreso = 0, progresoObjetivo = 0;     // Avance hacia la meta (0 a 1), animado
String botonPendiente = "";                   // "CERO" o "AYUDA" mientras espera el segundo toque
int botonHasta = 0;                           // millis() en que vence el segundo toque
final int VENTANA_CONFIRMAR = 6000;           // Igual que en el Arduino
float[] barras = new float[48];               // Alturas de las ondas de la voz
boolean primeraEspera = true;                 // El ESPERA del arranque no corta la bienvenida

void setup() {
  size(1000, 640);
  smooth(8);
  aplicarTema(temaOscuro);
  fSans = fuente("AtkinsonHyperlegible-Bold.ttf", "Atkinson Hyperlegible Bold", "Segoe UI Bold");
  fMono = fuente("JetBrainsMono-Bold.ttf", "JetBrains Mono Bold", "Consolas Bold");
  textFont(fSans);
  if (!SIMULAR) conectar();
  decir("bienvenida", "ubicacion");           // Bienvenida y dónde están las cosas
  ultimaActividad = millis();
}

void draw() {
  if (!SIMULAR) leerSerial();

  // Reproducir la cola, un clip tras otro
  if (millis() >= finClip && cola.size() > 0) {
    SoundFile s = clip(cola.remove(0));
    if (s != null) {
      sonando = s;
      s.play(velocidadVoz);
      finClip = millis() + (int)(s.duration() * 1000 / velocidadVoz) + 100;   // No arranca otro hasta que termine este
    }
  }

  // Si la persona se queda quieta, repite la ayuda de ese momento (máximo 2 veces).
  // Sin Arduino no hay nada que ayudar a hacer: calla.
  boolean hayArduino = SIMULAR || arduinoRespondio;
  int desde = max(ultimaActividad, finClip);   // Cuenta el silencio desde el final de lo último que sonó
  if (hayArduino && millis() - desde > ESPERA_RECORDATORIO && recordatorios < MAX_RECORDATORIOS
      && millis() >= finClip && cola.size() == 0) {
    recordatorios++;
    ultimaActividad = millis();
    decir(clipAyuda());
  }

  if (millis() > botonHasta) botonPendiente = "";
  pesoAnim = lerp(pesoAnim, pesoObjetivo, 0.12);
  progreso = lerp(progreso, progresoObjetivo, 0.1);
  dibujar();
}

// ---------------------------------------------------------------- PUERTO SERIAL
// Así el sketch funciona en cualquier computador: busca el Arduino solo. Si el puerto que abre
// no contesta en 8 s (por ejemplo, un puerto Bluetooth), prueba el siguiente. Si no hay ninguno
// o se desconecta, lo avisa en pantalla y vuelve a intentar cada 3 s en vez de cerrarse.
final String SIN_ARDUINO = "Conecta el Arduino";
final int ESPERA_RESPUESTA = 8000;            // ms que se le da al Arduino para decir algo al abrir
Serial puerto = null;
String nombrePuerto = "";
int ultimoIntento = 0, conectadoEn = 0;
boolean arduinoRespondio = false;
ArrayList<String> descartados = new ArrayList<String>();   // Puertos que no contestaron

void conectar() {
  ultimoIntento = millis();
  String[] lista = Serial.list();
  printArray(lista);                          // Puertos disponibles
  String elegido = elegirPuerto(lista);
  if (elegido == null) {
    descartados.clear();                      // En la próxima vuelta se vuelven a probar todos
    avisar(SIN_ARDUINO);
    return;
  }
  try {
    puerto = new Serial(this, elegido, 9600); // Al abrirlo, el Arduino se reinicia (y hace tare)
    puerto.clear();
    nombrePuerto = elegido;
    conectadoEn = millis();
    arduinoRespondio = false;
    println("Probando " + elegido + "...");
  } catch (Exception e) {
    puerto = null;
    descartados.add(elegido);
    avisar(SIN_ARDUINO);
    println("No se pudo abrir " + elegido + " (¿Monitor Serie abierto?): " + e.getMessage());
  }
}

// Orden: el que escribiste en PUERTO; en Mac y Linux, los nombres típicos de Arduino;
// en Windows, del COM más alto al más bajo (COM1 es del computador). Salta los descartados.
String elegirPuerto(String[] lista) {
  ArrayList<String> orden = new ArrayList<String>();
  for (String p : lista) if (p.equals(PUERTO)) orden.add(p);
  for (String p : lista) {
    if (p.contains("usbmodem") || p.contains("usbserial") || p.contains("ttyACM") || p.contains("ttyUSB")) orden.add(p);
  }
  for (int i = lista.length - 1; i >= 0; i--) {
    if (lista[i].startsWith("COM") && !lista[i].equals("COM1")) orden.add(lista[i]);
  }
  for (String p : orden) if (!descartados.contains(p)) return p;
  return null;
}

void leerSerial() {
  if (puerto == null) {
    if (millis() - ultimoIntento > 3000) conectar();
    return;
  }
  try {
    while (puerto.available() > 0) {
      String linea = puerto.readStringUntil('\n');
      if (linea == null) break;               // Línea a medias: se termina de leer en el próximo cuadro
      if (!arduinoRespondio) {
        arduinoRespondio = true;
        println("Arduino en " + nombrePuerto);
        if (frase.equals(SIN_ARDUINO)) frase = FRASE_ESPERA;
      }
      procesar(trim(linea));
    }
  } catch (Exception e) {
    soltarPuerto("Se perdió la conexión con " + nombrePuerto);
    return;
  }
  if (!arduinoRespondio && millis() - conectadoEn > ESPERA_RESPUESTA) {
    descartados.add(nombrePuerto);
    soltarPuerto(nombrePuerto + " no contesta: pruebo otro puerto");
  }
}

void soltarPuerto(String motivo) {
  println(motivo);
  try {
    puerto.stop();
  } catch (Exception e) {
    // Si ya estaba cerrado no importa
  }
  puerto = null;
  arduinoRespondio = false;
  ultimoIntento = millis();
  avisar(SIN_ARDUINO);
}

// ---------------------------------------------------------------- INTERFAZ
// Componente InterfazMedidor del design system AUTONOMÍA: una pantalla (surface-200, radius-lg)
// con la pill de estado y la meta arriba, la cifra en "peso", el mensaje en "subtitulo",
// la barra de avance hacia la meta y los botones Ayuda y Cero (los dos botones físicos).
// La pantalla solo confirma lo que la persona ya oyó.

// Rejilla de 8 px (space-*) y radio de la pantalla (radius-lg)
final int SPACE_2 = 8, SPACE_4 = 16, SPACE_6 = 24, SPACE_8 = 32;
final int RADIUS_LG = 24;
final int ALTO_PILL = 38, ALTO_PISTA = 16, ALTO_BOTON = 56;

void aplicarTema(boolean oscuro) {
  temaOscuro = oscuro;
  if (oscuro) {
    SURFACE_100 = #1b1230;  SURFACE_200 = #261a40;  SURFACE_300 = #33235a;
    INK = #f4efff;          INK_SOFT = #bdb0dd;
    BRAND = #8e6bff;        BRAND_STRONG = #c4b0ff; ON_BRAND = #1b1230;
    LINE = #4a3a7a;
  } else {
    SURFACE_100 = #f6f2ff;  SURFACE_200 = #ffffff;  SURFACE_300 = #ece4ff;
    INK = #1b1230;          INK_SOFT = #5a4b7c;
    BRAND = #5b38d6;        BRAND_STRONG = #3e22a8; ON_BRAND = #ffffff;
    LINE = #cfc3ee;
  }
}

// Carga una fuente: primero de "data", luego instalada, y si no, la de respaldo
PFont fuente(String archivo, String nombre, String respaldo) {
  if (dataFile(archivo).exists()) return createFont(archivo, 96, true);
  for (String f : PFont.list()) if (f.equals(nombre)) return createFont(nombre, 96, true);
  println("Fuente " + nombre + " no encontrada: uso " + respaldo);
  return createFont(respaldo, 96, true);
}

void dibujar() {
  background(SURFACE_100);

  // Pantalla: surface-200 sobre surface-100, borde line, radius-lg, margen space-8
  float px = SPACE_8, py = SPACE_8, pw = width - 2 * SPACE_8, ph = height - 2 * SPACE_8;
  fill(SURFACE_200);
  stroke(LINE);
  strokeWeight(1);
  rect(px, py, pw, ph, RADIUS_LG);
  noStroke();

  // Contenido con relleno space-6
  float x = px + SPACE_6, y = py + SPACE_6, w = pw - 2 * SPACE_6;
  float abajo = py + ph - SPACE_6;

  // Cabecera: pill de estado (y de error, si hay un aviso) a la izquierda; meta a la derecha
  float finPill = pill(x, y, palabraEstado(), colorEstado(), formaEstado());
  if (frase.equals(fraseAviso)) pill(finPill + SPACE_2, y, "Error", STATE_PASADO, 3);
  fill(INK_SOFT);
  textFont(fSans);
  textSize(13);
  etiqueta(meta > 0 ? "META " + meta + " G" : "SIN META", x + w, y + ALTO_PILL / 2);

  // Pie: barra de avance y los dos botones físicos
  float yBotones = abajo - ALTO_BOTON;
  float yPista = yBotones - SPACE_6 - ALTO_PISTA;
  pista(x, yPista, w);
  float bw = (w - SPACE_4) / 2.0;
  boton(x, yBotones, bw, "Ayuda", botonPendiente.equals("AYUDA"));              // Izquierda, como en la caja
  boton(x + bw + SPACE_4, yBotones, bw, "Cero", botonPendiente.equals("CERO")); // Derecha

  // Centro: cifra (96), mensaje (2 líneas de 30) y onda de la voz (24), centrados entre cabecera y pie
  float alto = 96 + SPACE_4 + 60 + SPACE_4 + 24;
  float yMedio = y + ALTO_PILL + (yPista - (y + ALTO_PILL) - alto) / 2.0;
  cifra(x, yMedio);
  textFont(fSans);
  textSize(24);
  textLeading(30);
  textAlign(LEFT, TOP);
  fill(INK);
  text(frase, x, yMedio + 96 + SPACE_4, w, 60);
  onda(x, yMedio + 96 + SPACE_4 + 60 + SPACE_4 + 12);
}

// Pill de estado: relleno state-*, forma y palabra en on-state. Devuelve dónde termina
float pill(float x, float y, String palabra, color c, int forma) {
  textFont(fSans);
  textSize(15);
  float w = SPACE_4 + 18 + SPACE_2 + textWidth(palabra) + SPACE_4;
  noStroke();
  fill(c);
  rect(x, y, w, ALTO_PILL, ALTO_PILL / 2);
  forma(forma, x + SPACE_4, y + (ALTO_PILL - 18) / 2);
  fill(ON_STATE);
  textAlign(LEFT, CENTER);
  text(palabra, x + SPACE_4 + 18 + SPACE_2, y + ALTO_PILL / 2 - 1);
  return x + w;
}

// Formas de 18 px: 0 círculo hueco, 1 triángulo, 2 visto, 3 equis
void forma(int f, float x, float y) {
  pushMatrix();
  translate(x, y);
  stroke(ON_STATE);
  strokeWeight(2.5);
  strokeCap(ROUND);
  strokeJoin(ROUND);
  noFill();
  if (f == 0) {
    ellipse(9, 9, 12, 12);
  } else if (f == 1) {
    noStroke();
    fill(ON_STATE);
    triangle(9, 2, 16, 15, 2, 15);
  } else if (f == 2) {
    beginShape();
    vertex(3, 9.5);
    vertex(7.5, 14);
    vertex(15, 4.5);
    endShape();
  } else {
    line(4, 4, 14, 14);
    line(14, 4, 4, 14);
  }
  popMatrix();
  noStroke();
}

// Etiqueta en mayúsculas con espaciado de 0.08 em, alineada a la derecha
void etiqueta(String s, float xDerecha, float cy) {
  float esp = g.textSize * 0.08, total = 0;
  for (int i = 0; i < s.length(); i++) total += textWidth(s.charAt(i)) + (i > 0 ? esp : 0);
  float cx = xDerecha - total;
  textAlign(LEFT, CENTER);
  for (int i = 0; i < s.length(); i++) {
    text(s.charAt(i), cx, cy);
    cx += textWidth(s.charAt(i)) + esp;
  }
}

// La cifra en "peso" (96 px, JetBrains Mono) con la unidad en "meta" (28 px, ink-soft)
void cifra(float x, float y) {
  String n = textoPeso();
  textFont(fMono);
  textSize(96);
  textAlign(LEFT, BASELINE);
  float base = y + textAscent();
  fill(INK);
  text(n, x, base);
  float xUnidad = x + textWidth(n) + SPACE_2;
  textSize(28);
  fill(INK_SOFT);
  text("g", xUnidad, base);
}

// Qué número mostrar: el peso confirmado, el último peso conocido, 0 en espera o "--" si no se sabe
String textoPeso() {
  if (estado.equals("LISTO")) return str(round(pesoAnim));
  if (pesoVisto >= 0) return str(pesoVisto);
  if (estado.equals("ESPERA")) return "0";
  return "--";
}

// Barra de avance hacia la meta: pista surface-300, relleno del color del estado
void pista(float x, float y, float w) {
  float h = ALTO_PISTA;
  fill(SURFACE_300);
  rect(x, y, w, h, h / 2);
  fill(colorEstado());
  if (estado.equals("MIDIENDO") && meta == 0) {
    // Sin meta no hay avance que mostrar: un tramo que recorre la pista mientras mide
    float tramo = w * 0.2;
    float t = (millis() * 0.0004) % 1.0;
    rect(x + (w - tramo) * (0.5 - 0.5 * cos(TWO_PI * t)), y, tramo, h, h / 2);
  } else if (progreso > 0.005) {
    rect(x, y, max(h, w * progreso), h, h / 2);
  }
}

// Botón pill de 56 px: borde brand-strong. Se llena en brand mientras espera el segundo toque
void boton(float x, float y, float w, String texto, boolean activo) {
  if (activo) {
    noStroke();
    fill(BRAND);
  } else {
    stroke(BRAND_STRONG);
    strokeWeight(2);
    noFill();
  }
  rect(x, y, w, ALTO_BOTON, ALTO_BOTON / 2);
  noStroke();
  textFont(fSans);
  textSize(18);
  textAlign(CENTER, CENTER);
  fill(activo ? ON_BRAND : BRAND_STRONG);
  text(texto, x + w / 2, y + ALTO_BOTON / 2 - 2);
}

// Onda de la voz: barras en brand-strong que se mueven mientras habla
void onda(float x, float yCentro) {
  boolean habla = (sonando != null && millis() < finClip);
  float bw = 4, gap = 4;
  for (int i = 0; i < barras.length; i++) {
    float objetivo = habla ? 4 + 20 * noise(i * 0.35, millis() * 0.004) : 4;
    barras[i] = lerp(barras[i], objetivo, 0.25);
    fill(habla ? BRAND_STRONG : LINE);
    rect(x + i * (bw + gap), yCentro - barras[i] / 2, bw, barras[i], 2);
  }
}

String palabraEstado() {
  if (estado.equals("MIDIENDO")) return "Midiendo";
  if (estado.equals("LISTO")) return "Listo";
  if (estado.equals("PASADO")) return "Te pasaste";
  return "Espera";
}

int formaEstado() {
  if (estado.equals("MIDIENDO")) return 1;
  if (estado.equals("LISTO")) return 2;
  if (estado.equals("PASADO")) return 3;
  return 0;
}

color colorEstado() {
  if (estado.equals("MIDIENDO")) return STATE_MIDE;
  if (estado.equals("LISTO")) return STATE_LISTO;
  if (estado.equals("PASADO")) return STATE_PASADO;
  return STATE_ESPERA;
}

// ------------------------------------------------------------ LÓGICA / AUDIO

void keyPressed() {
  if (key == '+') velocidadVoz = min(1.6, round(velocidadVoz * 10 + 1) / 10.0);   // Voz más rápida
  if (key == '-') velocidadVoz = max(0.8, round(velocidadVoz * 10 - 1) / 10.0);   // Voz más lenta
  if (key == 't' || key == 'T') aplicarTema(!temaOscuro);                         // Tema oscuro / claro
  if (!SIMULAR) return;
  if (key == '1') procesar("ESPERA");
  if (key == '2') procesar("MIDIENDO");
  if (key == '3') procesar("PESO:100");
  if (key == '4') procesar("PESO:500");
  if (key == '5') procesar("PESO:250");
  if (key == '6') procesar("META:100");
  if (key == '7') procesar("PASADO:30");
  if (key == '8') procesar("AYUDA");
  if (key == '9') procesar("CERO");
  if (key == '0') procesar("FALTA:40");
}

// Un mensaje del Arduino: cambia lo que se ve y arma lo que se dice
void procesar(String linea) {
  if (linea.length() == 0) return;
  println("Arduino: " + linea);
  if (!linea.startsWith("G:")) {              // Cualquier mensaje (menos el diagnóstico) cuenta como actividad
    ultimaActividad = millis();
    recordatorios = 0;
  }

  if (linea.equals("ESPERA")) {
    cambiar("ESPERA", FRASE_ESPERA);
    if (primeraEspera) primeraEspera = false;   // Arranque: deja terminar la bienvenida
    else decir("espera");

  } else if (linea.equals("MIDIENDO")) {
    cambiar("MIDIENDO", "Espera, estoy midiendo");
    decir("midiendo");

  } else if (linea.startsWith("META:")) {       // META:100 o META:100:nombre. META:0 solo quita la meta
    meta = int(split(linea.substring(5), ':')[0]);
    if (meta > 0) {
      cambiar("ESPERA", "Meta: " + meta + " gramos");
      if (hay("meta_" + meta)) {
        decir("meta_" + meta);                  // Clip completo para ese peso, si existe
      } else {                                  // Cualquier otro peso: "Ficha de" + número + "gramos"
        ArrayList<String> clips = new ArrayList<String>();
        clips.add("ficha_de");
        agregarNumero(clips, meta);
        clips.add("gramos");
        clips.add("cancelar_ficha");
        decir(clips);
      }
    }

  } else if (linea.equals("META_CANCELADA")) {
    cambiar("ESPERA", "Ya no tienes meta");
    decir("meta_cancelada");

  } else if (linea.equals("BOTON_CERO")) {      // Primer toque: dice qué botón es
    esperarSegundoToque("CERO", "Botón de cero. Púlsalo de nuevo", "boton_cero");
  } else if (linea.equals("BOTON_AYUDA")) {
    esperarSegundoToque("AYUDA", "Botón de ayuda. Púlsalo de nuevo", "boton_ayuda");

  } else if (linea.equals("CERO")) {            // Segundo toque de cero
    botonPendiente = "";
    cambiar("ESPERA", "Balanza en cero. Echa el ingrediente");
    decir("cero");
  } else if (linea.equals("AYUDA")) {           // Segundo toque de ayuda (sin estar midiendo)
    botonPendiente = "";
    decir(clipAyuda());
  } else if (linea.startsWith("LLEVA:")) {      // Ayuda mientras mide: cuánto lleva
    botonPendiente = "";
    decirLleva(int(linea.substring(6)));

  } else if (linea.equals("ERROR:CELDA")) {
    avisar("La balanza no responde");
    decir("error_celda");
  } else if (linea.equals("AVISO:CERO")) {
    avisar("Hay peso en la balanza");
    decir("aviso_cero");
  } else if (linea.equals("ERROR:FICHA")) {
    avisar("Ficha no reconocida");
    decir("ficha_desconocida");
  } else if (linea.equals("AVISO:RETIRA")) {
    avisar("Retira la taza");
    decir("retira_taza");

  } else if (linea.startsWith("FALTA:")) {      // Solo llega con meta y mientras mide
    int falta = int(linea.substring(6));
    if (estado.equals("MIDIENDO") && meta > 0 && falta > 0) {
      pesoVisto = max(0, meta - falta);
      progresoObjetivo = constrain((meta - falta) / (float) meta, 0, 1);
      ArrayList<String> clips = new ArrayList<String>();
      if (falta < 20) {                         // Falta poco: sugiere con qué completar
        clips.add("te_falta_poco");
        clips.add(cucharaPara(falta));
        frase = "Te falta poco. " + textoCuchara(falta);
      } else {
        clips.add("faltan");
        agregarNumero(clips, falta);
        clips.add("gramos");
        frase = "Faltan " + redondear10(falta) + " gramos";
      }
      decir(clips);
    }

  } else if (linea.equals("PASADO") || linea.startsWith("PASADO:")) {
    int sobra = linea.startsWith("PASADO:") ? int(linea.substring(7)) : 0;   // Gramos sobre la meta
    cambiar("PASADO", "Te pasaste. Quita peso");
    if (sobra > 0) {
      if (meta > 0) pesoVisto = meta + sobra;
      int quita = max(10, redondear10(sobra));
      ArrayList<String> clips = new ArrayList<String>();
      clips.add("te_pasaste_quita");
      agregarNumero(clips, quita);
      clips.add("gramos");
      frase = "Te pasaste. Quita " + quita + " gramos";
      decir(clips);
    } else {
      decir("te pasaste");
    }

  } else if (linea.startsWith("PESO:")) {
    int g = int(linea.substring(5));
    cambiar("LISTO", "Este peso es " + g + " gramos");
    pesoObjetivo = g;
    pesoAnim = 0;
    decirPeso(g);
  }
  // Otras líneas (TAG:..., G:..., el diagnóstico del lector NFC) solo se imprimen
}

// Cambia de estado y deja la pantalla limpia para ese estado
void cambiar(String nuevo, String texto) {
  estado = nuevo;
  frase = texto;
  pesoObjetivo = 0;
  pesoVisto = -1;
  progresoObjetivo = (nuevo.equals("LISTO") || nuevo.equals("PASADO")) ? 1 : 0;
}

// Un aviso o error: se escribe y se marca con la pill "Error" hasta que cambie la frase
void avisar(String texto) {
  frase = texto;
  fraseAviso = texto;
}

void esperarSegundoToque(String boton, String texto, String audio) {
  botonPendiente = boton;
  botonHasta = millis() + VENTANA_CONFIRMAR;
  frase = texto;
  decir(audio);
}

// Con qué completar lo que falta (aproximado: 1 cucharada = 10 g, 1 cucharadita = 3 g)
String cucharaPara(int falta) {
  if (falta >= 15) return "cuch_2";
  if (falta >= 7) return "cuch_1";
  if (falta >= 3) return "cuch_tsp";
  if (falta >= 2) return "cuch_media";
  return "cuch_casi";
}

String textoCuchara(int falta) {
  if (falta >= 15) return "Échale dos cucharadas";
  if (falta >= 7) return "Échale una cucharada";
  if (falta >= 3) return "Échale una cucharadita";
  if (falta >= 2) return "Échale media cucharadita";
  return "Ya casi llegas";
}

// La ayuda depende del momento en que está la persona
String clipAyuda() {
  if (estado.equals("MIDIENDO")) return "ayuda_midiendo";
  if (estado.equals("LISTO")) return "ayuda_listo";
  if (estado.equals("PASADO")) return "ayuda_pasado";
  return "ayuda_espera";
}

int redondear10(int g) {
  return round(g / 10.0) * 10;
}

// Corta lo que suena y arma una frase nueva con los clips en orden
void decir(String... clips) {
  cola.clear();
  if (sonando != null) sonando.stop();
  finClip = 0;
  for (String c : clips) cola.add(c);
}

void decir(ArrayList<String> clips) {
  decir(clips.toArray(new String[0]));
}

// "Este peso es" + número + "gramos" (o el clip completo, si existe)
void decirPeso(int g) {
  g = redondear10(g);
  if (hay("peso_" + g)) {
    decir("peso_" + g);
    return;
  }
  ArrayList<String> clips = new ArrayList<String>();
  clips.add("este_peso_es");
  agregarNumero(clips, g);
  clips.add("gramos");
  decir(clips);
}

// "Llevas 60 de 100 gramos". Si ya se pasó: "Te pasaste por 20 gramos"
void decirLleva(int g) {
  pesoVisto = g;
  if (estado.equals("MIDIENDO") && meta > 0) progresoObjetivo = constrain(g / (float) meta, 0, 1);
  ArrayList<String> clips = new ArrayList<String>();
  if (estado.equals("PASADO") && meta > 0) {
    int sobra = max(10, redondear10(g - meta));
    clips.add("te_pasaste_por");
    agregarNumero(clips, sobra);
    frase = "Te pasaste por " + sobra + " gramos";
  } else {
    clips.add("llevas");
    agregarNumero(clips, g);
    if (meta > 0) {
      clips.add("de");
      agregarNumero(clips, meta);
    }
    frase = "Llevas " + redondear10(g) + (meta > 0 ? " de " + meta : "") + " gramos";
  }
  clips.add("gramos");
  decir(clips);
}

// Agrega los clips de un número, redondeado a múltiplos de 10 (hay clips de 10 a 1000)
void agregarNumero(ArrayList<String> clips, int g) {
  g = redondear10(g);
  if (g >= 1000) {
    clips.add("n1000");
  } else {
    int c = (g / 100) * 100;                  // Centenas
    int d = g % 100;                          // Decenas
    if (c == 100) clips.add(d == 0 ? "n100" : "n101");   // cien / ciento
    else if (c > 100) clips.add("n" + c);
    if (d > 0) clips.add("n" + d);
  }
}

// Carga el clip nuevo cada vez (reusar uno detenido a veces no vuelve a sonar).
// Si falta el archivo, avisa y se salta (no se cae)
SoundFile clip(String nombre) {
  String real = buscar(nombre);
  if (real == null) {
    println("FALTA el clip: " + nombre);
    return null;
  }
  return new SoundFile(this, real);
}

// Archivo de un clip: primero el .mp3 (voz propia) y si no, el .wav
String buscar(String nombre) {
  if (dataFile(nombre + ".mp3").exists()) return nombre + ".mp3";
  if (dataFile(nombre + ".wav").exists()) return nombre + ".wav";
  return null;
}

boolean hay(String nombre) {
  return buscar(nombre) != null;
}
