// AUTONOMÍA / Sendero Sonoro - Estación Medidor
// Lee el serial del Arduino, reproduce los audios (.wav o .mp3, carpeta "data") y muestra la interfaz.
// Librería: Sound. Cierra el Monitor Serie del Arduino IDE antes de correr.
//
// MODO SIMULACIÓN (SIMULAR = true): no necesita Arduino. Teclas:
//   1 = ESPERA    2 = MIDIENDO    3 = PESO:100    4 = PESO:500    5 = PESO:250
//   6 = META:100  7 = PASADO      8 = AYUDA       9 = CERO
// En cualquier modo: + y - hacen la voz más rápida o más lenta.
import processing.serial.*;
import processing.sound.*;

final boolean SIMULAR = false;                // false cuando conectes el Arduino
final String PUERTO = "COM3";                 // ← puerto del Arduino

// Colores: fondo crema y tonos suaves
final color C_FONDO   = color(245, 236, 216);
final color C_TEXTO   = color(58, 50, 44);
final color C_SUAVE   = color(118, 106, 94);
final color C_ESPERA  = color(160, 172, 196);   // azul grisáceo
final color C_MIDE    = color(222, 170, 98);    // ámbar suave
final color C_LISTO   = color(122, 182, 148);   // verde suave
final color C_PASADO  = color(212, 126, 122);   // rosa suave

Serial puerto;
ArrayList<String> cola = new ArrayList<String>();   // Nombres de archivo en espera
SoundFile sonando = null;
int finClip = 0;                                    // millis() en que termina el clip actual
float velocidadVoz = 1.0;                           // 1.0 = normal. Teclas + y - la cambian (0.8 a 1.6)
final int ESPERA_RECORDATORIO = 15000;              // ms sin actividad antes de repetir la ayuda
final int MAX_RECORDATORIOS = 2;                    // veces que repite antes de callar
int ultimaActividad = 0;                            // millis() del último mensaje del Arduino
int recordatorios = 0;
PFont fTexto, fNum;                                 // Tipografías: texto y números grandes
float progreso = 0, progresoObjetivo = 0;           // Avance hacia la meta (0 a 1), animado
float[] barras = new float[48];                     // Alturas de las ondas de la voz
int faltaActual = -1;                               // Gramos que faltan según el último aviso (-1 = no hay)

// Estado de la interfaz
String estado = "ESPERA";                     // ESPERA, MIDIENDO, LISTO o PASADO
int meta = 0;                                 // Meta en gramos que fijó el tag NFC (0 = sin tag)
String frase = "Pon el ingrediente en la pesa";
int pesoObjetivo = 0;
float pesoAnim = 0;                           // Número que "sube" hasta el peso real
int tiempoEstado = 0;                         // millis() al cambiar de estado
boolean primeraEspera = true;                 // El ESPERA del arranque no corta la bienvenida

void setup() {
  size(1000, 640);
  smooth(8);
  fTexto = createFont("Segoe UI", 32);        // Si no existe, Processing usa una fuente parecida
  fNum = createFont("Segoe UI Black", 32);
  textFont(fTexto);
  if (!SIMULAR) {
    printArray(Serial.list());                // Puertos disponibles
    puerto = new Serial(this, PUERTO, 9600);  // Al abrirlo, el Arduino se reinicia (y hace tare)
    puerto.clear();
  }
  decir("bienvenida.wav", "ubicacion.wav");   // Bienvenida y dónde están las cosas
  ultimaActividad = millis();
}

void draw() {
  // Leer todas las líneas que lleguen
  if (!SIMULAR) {
    while (puerto.available() > 0) {
      String linea = puerto.readStringUntil('\n');
      if (linea == null) break;
      procesar(trim(linea));
    }
  }

  // Reproducir la cola, un clip tras otro
  if (millis() >= finClip && cola.size() > 0) {
    SoundFile s = clip(cola.remove(0));
    if (s != null) {
      sonando = s;
      s.play(velocidadVoz);
      finClip = millis() + (int)(s.duration() * 1000 / velocidadVoz) + 100;   // No arranca otro hasta que termine este
    }
  }

  // Si la persona se queda quieta, repite la ayuda de ese momento (máximo 2 veces)
  int desde = max(ultimaActividad, finClip);   // Cuenta el silencio desde el final de lo último que sonó
  if (millis() - desde > ESPERA_RECORDATORIO && recordatorios < MAX_RECORDATORIOS
      && millis() >= finClip && cola.size() == 0) {
    recordatorios++;
    ultimaActividad = millis();
    decir(archivoAyuda());
  }

  pesoAnim = lerp(pesoAnim, pesoObjetivo, 0.12);
  progreso = lerp(progreso, progresoObjetivo, 0.1);
  dibujar();
}

// ---------------------------------------------------------------- INTERFAZ

void dibujar() {
  background(C_FONDO);
  color c = colorEstado();
  float cx = width / 2.0, cy = 290, D = 300;

  // Título discreto
  textFont(fTexto);
  textAlign(LEFT, CENTER);
  fill(C_SUAVE);
  textSize(16);
  text("Medidor · Autonomía", 48, 44);

  // Anillo fino
  noFill();
  stroke(0, 16);
  strokeWeight(6);
  ellipse(cx, cy, D, D);

  strokeCap(ROUND);
  stroke(c);
  strokeWeight(6);
  if (estado.equals("ESPERA")) {
    // Respira lento
    float p = 0.5 + 0.5 * sin(millis() * 0.002);
    stroke(red(c), green(c), blue(c), 90 + 120 * p);
    ellipse(cx, cy, D, D);
  } else if (estado.equals("MIDIENDO")) {
    if (meta > 0) {
      // Con meta: el arco se llena hasta la meta
      arc(cx, cy, D, D, -HALF_PI, -HALF_PI + TWO_PI * max(progreso, 0.02));
    } else {
      // Sin meta: un arco que gira
      float a = millis() * 0.005;
      arc(cx, cy, D, D, a, a + TWO_PI * 0.25);
    }
  } else if (estado.equals("PASADO")) {
    ellipse(cx, cy, D, D);
  } else {
    // Se completa el anillo al llegar a LISTO
    float t = constrain((millis() - tiempoEstado) / 600.0, 0, 1);
    arc(cx, cy, D, D, -HALF_PI, -HALF_PI + TWO_PI * t);
  }
  noStroke();

  // Centro del anillo
  textAlign(CENTER, CENTER);
  if (estado.equals("LISTO")) {
    numeroGrande(round(pesoAnim), "gramos", cx, cy);
  } else if (estado.equals("PASADO")) {
    textFont(fTexto);
    fill(C_TEXTO);
    textSize(34);
    text("te pasaste", cx, cy - 10);
    fill(C_SUAVE);
    textSize(20);
    text("meta " + meta + " g", cx, cy + 32);
  } else if (estado.equals("MIDIENDO")) {
    if (meta > 0 && faltaActual > 0) {
      numeroGrande(round(faltaActual / 10.0) * 10, "gramos por echar", cx, cy);
    } else {
      textFont(fTexto);
      fill(C_TEXTO);
      textSize(30);
      text("midiendo", cx, cy - 6);
      if (meta > 0) {
        fill(C_SUAVE);
        textSize(20);
        text("meta " + meta + " g", cx, cy + 34);
      }
    }
  } else {
    if (meta > 0) {
      numeroGrande(meta, "gramos de meta", cx, cy);
    } else {
      textFont(fTexto);
      fill(C_TEXTO);
      textSize(30);
      text("listo para pesar", cx, cy - 6);
      fill(C_SUAVE);
      textSize(20);
      text("pon la taza", cx, cy + 34);
    }
  }

  // Ondas de la voz: se mueven mientras habla
  boolean habla = (sonando != null && millis() < finClip);
  float bw = 8, gap = 6, total = barras.length * (bw + gap) - gap;
  float x0 = cx - total / 2.0;
  float yOnda = cy + D / 2 + 48;
  for (int i = 0; i < barras.length; i++) {
    float objetivo = habla ? 8 + 44 * noise(i * 0.35, millis() * 0.004) : 4;
    barras[i] = lerp(barras[i], objetivo, 0.25);
    fill(habla ? c : color(0, 22));
    rect(x0 + i * (bw + gap), yOnda - barras[i] / 2, bw, barras[i], 4);
  }

  // Lo que se está diciendo, bajo las ondas
  textFont(fTexto);
  textAlign(CENTER, CENTER);
  fill(C_TEXTO);
  textSize(22);
  text(frase, cx, yOnda + 56);
}

// Un número grande y delgado con su unidad debajo
void numeroGrande(int n, String unidad, float cx, float cy) {
  textFont(fNum);
  fill(C_TEXTO);
  textSize(112);
  text(n, cx, cy - 14);
  textFont(fTexto);
  fill(C_SUAVE);
  textSize(20);
  text(unidad, cx, cy + 56);
}

color colorEstado() {
  if (estado.equals("MIDIENDO")) return C_MIDE;
  if (estado.equals("LISTO")) return C_LISTO;
  if (estado.equals("PASADO")) return C_PASADO;
  return C_ESPERA;
}

// ------------------------------------------------------------ LÓGICA / AUDIO

void keyPressed() {
  if (key == '+') velocidadVoz = min(1.6, velocidadVoz + 0.1);   // Voz más rápida
  if (key == '-') velocidadVoz = max(0.8, velocidadVoz - 0.1);   // Voz más lenta
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
}

void procesar(String linea) {
  if (linea.length() == 0) return;
  println("Arduino: " + linea);
  if (!linea.startsWith("G:")) {              // Cualquier mensaje (menos el diagnóstico) cuenta como actividad
    ultimaActividad = millis();
    recordatorios = 0;
  }
  if (linea.equals("ESPERA")) {
    cambiar("ESPERA", "Pon el ingrediente en la pesa");
    if (primeraEspera) primeraEspera = false;   // Arranque: deja terminar la bienvenida
    else decir("espera.mp3");
  } else if (linea.equals("MIDIENDO")) {
    cambiar("MIDIENDO", "Espera, estoy midiendo");
    decir("midiendo.mp3");
  } else if (linea.startsWith("META:")) {
    meta = int(split(linea.substring(5), ':')[0]);
    if (meta > 0) {
      cambiar("ESPERA", "Meta: " + meta + " gramos");
      if (hay("meta_" + meta + ".mp3")) {
        decir("meta_" + meta + ".mp3");              // Clip completo para ese peso, si existe
      } else {                                        // Cualquier otro peso: "Ficha de" + número + "gramos"
        ArrayList<String> clips = new ArrayList<String>();
        clips.add(archivo("ficha_de"));
        agregarNumero(clips, meta);
        clips.add(archivo("gramos"));
        clips.add(archivo("cancelar_ficha"));
        decir(clips.toArray(new String[0]));
      }
    }
  } else if (linea.equals("BOTON_CERO")) {
    frase = "Botón de cero. Púlsalo de nuevo";
    decir("boton_cero.wav");
  } else if (linea.equals("BOTON_AYUDA")) {
    frase = "Botón de ayuda. Púlsalo de nuevo";
    decir("boton_ayuda.wav");
  } else if (linea.equals("META_CANCELADA")) {
    cambiar("ESPERA", "Ya no tienes meta");
    decir("meta_cancelada.wav");
  } else if (linea.equals("CERO")) {
    cambiar("ESPERA", "Balanza en cero. Echa el ingrediente");
    decir("cero.wav");
  } else if (linea.equals("AYUDA")) {
    decir(archivoAyuda());
  } else if (linea.startsWith("LLEVA:")) {
    decirLleva(int(linea.substring(6)));
  } else if (linea.equals("ERROR:CELDA")) {
    frase = "La balanza no responde";
    decir("error_celda.wav");
  } else if (linea.equals("AVISO:CERO")) {
    frase = "Hay peso en la balanza";
    decir("aviso_cero.wav");
  } else if (linea.equals("ERROR:FICHA")) {
    frase = "Ficha no reconocida";
    decir("ficha_desconocida.wav");
  } else if (linea.equals("AVISO:RETIRA")) {
    frase = "Retira la taza";
    decir("retira_taza.wav");
  } else if (linea.startsWith("FALTA:")) {
    int falta = int(linea.substring(6));
    if (estado.equals("MIDIENDO") && falta > 0) {
      faltaActual = falta;
      if (meta > 0) progresoObjetivo = constrain((meta - falta) / (float) meta, 0, 1);
      ArrayList<String> clips = new ArrayList<String>();
      if (falta < 20) {                              // Falta poco: sugiere con qué completar
        clips.add(archivo("te_falta_poco"));
        clips.add(archivo(cucharaPara(falta)));
        frase = "Te falta poco. " + textoCuchara(falta);
      } else {
        clips.add(archivo("faltan"));
        agregarNumero(clips, falta);
        clips.add(archivo("gramos"));
        frase = "Faltan " + round(falta / 10.0) * 10 + " gramos";
      }
      decir(clips.toArray(new String[0]));
    }
  } else if (linea.equals("PASADO") || linea.startsWith("PASADO:")) {
    int sobra = linea.length() > 7 ? int(linea.substring(7)) : 0;   // gramos sobre la meta
    cambiar("PASADO", "Te pasaste. Quita peso");
    if (sobra > 0) {
      int quita = max(10, round(sobra / 10.0) * 10);
      ArrayList<String> clips = new ArrayList<String>();
      clips.add(archivo("te_pasaste_quita"));
      agregarNumero(clips, quita);
      clips.add(archivo("gramos"));
      frase = "Te pasaste. Quita " + quita + " gramos";
      decir(clips.toArray(new String[0]));
    } else {
      decir("te pasaste.mp3");
    }
  } else if (linea.startsWith("PESO:")) {
    int g = int(linea.substring(5));
    pesoObjetivo = g;
    pesoAnim = 0;
    cambiar("LISTO", "Este peso es " + g + " gramos");
    decirPeso(g);
  }
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
String archivoAyuda() {
  if (estado.equals("MIDIENDO")) return "ayuda_midiendo.wav";
  if (estado.equals("LISTO")) return "ayuda_listo.wav";
  if (estado.equals("PASADO")) return "ayuda_pasado.wav";
  return "ayuda_espera.wav";
}

void cambiar(String nuevo, String texto) {
  estado = nuevo;
  frase = texto;
  tiempoEstado = millis();
  if (!nuevo.equals("LISTO")) pesoObjetivo = 0;
  progresoObjetivo = (nuevo.equals("LISTO") || nuevo.equals("PASADO")) ? 1 : 0;
  faltaActual = -1;
}

// Corta lo que suena y arma una frase nueva
void decir(String... archivos) {
  cola.clear();
  if (sonando != null) sonando.stop();
  finClip = 0;
  for (String a : archivos) cola.add(a);
}

// "Este peso es" + número + "gramos"
void decirPeso(int g) {
  g = round(g / 10.0) * 10;                   // Redondea a múltiplos de 10
  if (hay("peso_" + g + ".mp3")) {            // Clip con la frase completa
    decir("peso_" + g + ".mp3");
    return;
  }
  ArrayList<String> clips = new ArrayList<String>();
  clips.add("este_peso_es.mp3");
  agregarNumero(clips, g);
  clips.add("gramos.mp3");
  decir(clips.toArray(new String[0]));
}

// "Llevas 60 de 100 gramos". Si ya se pasó: "Te pasaste por 20 gramos"
void decirLleva(int g) {
  ArrayList<String> clips = new ArrayList<String>();
  if (estado.equals("PASADO") && meta > 0) {
    int sobra = max(10, round((g - meta) / 10.0) * 10);
    clips.add(archivo("te_pasaste_por"));
    agregarNumero(clips, sobra);
    frase = "Te pasaste por " + sobra + " gramos";
  } else {
    clips.add(archivo("llevas"));
    agregarNumero(clips, g);
    if (meta > 0) {
      clips.add(archivo("de"));
      agregarNumero(clips, meta);
    }
    frase = "Llevas " + round(g / 10.0) * 10 + (meta > 0 ? " de " + meta : "") + " gramos";
  }
  clips.add(archivo("gramos"));
  decir(clips.toArray(new String[0]));
}

// Agrega los clips de un número (redondeado a múltiplos de 10)
void agregarNumero(ArrayList<String> clips, int g) {
  g = round(g / 10.0) * 10;
  if (g >= 1000) {
    clips.add(archivo("n1000"));
  } else {
    int c = (g / 100) * 100;                  // Centenas
    int d = g % 100;                          // Decenas
    if (c == 100) clips.add(archivo(d == 0 ? "n100" : "n101"));   // cien / ciento
    else if (c > 100) clips.add(archivo("n" + c));
    if (d > 0) clips.add(archivo("n" + d));
  }
}

// Nombre del clip: usa .mp3 si existe y si no .wav
String archivo(String base) {
  return dataFile(base + ".mp3").exists() ? base + ".mp3" : base + ".wav";
}

// Carga el clip nuevo cada vez (reusar uno detenido a veces no vuelve a sonar).
// Si falta el archivo, avisa y se salta (no se cae)
SoundFile clip(String archivo) {
  String real = buscar(archivo);
  if (real == null) {
    println("FALTA el clip: " + archivo);
    return null;
  }
  return new SoundFile(this, real);
}

// Busca el clip con la extensión pedida; si no está, prueba con la otra (.mp3 o .wav)
String buscar(String archivo) {
  if (dataFile(archivo).exists()) return archivo;
  int punto = archivo.lastIndexOf('.');
  String base = punto >= 0 ? archivo.substring(0, punto) : archivo;
  if (dataFile(base + ".wav").exists()) return base + ".wav";
  if (dataFile(base + ".mp3").exists()) return base + ".mp3";
  return null;
}

boolean hay(String archivo) {
  return buscar(archivo) != null;
}
