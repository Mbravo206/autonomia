// MEDIDOR DE COCINA - Arduino UNO + HX711 + buzzer (pin 8) + 2 botones + lector NFC RC522 (opcional)
// Manda por serial: ESPERA, MIDIENDO, PESO:250, META:100, FALTA:60, PASADO:20, CERO, AYUDA, LLEVA:60,
//                   ERROR:CELDA, ERROR:FICHA, AVISO:CERO, AVISO:RETIRA, TAG:xxxxxxxx
//
// CÓMO SE USA:
//   1) Taza vacía en la plataforma y botón de CERO (pin 4): la balanza queda en 0 con la taza puesta.
//   2) (Opcional) Acercas una ficha -> fija la META (ej. 100 g). Con la misma ficha otra vez se cancela.
//   3) Echan el ingrediente. Con meta: pitido que se acelera hasta tono continuo. Sin meta: un tic cada 10 g.
//   4) Peso estable 2 s (y cerca de la meta, si hay) -> LISTO. Si se pasan de la meta -> PASADO.
//   5) Botón de AYUDA (pin 5): Processing repite qué hacer; midiendo dice "llevas X de Y gramos".
//
// Conexiones:
//   HX711: DT=2  SCK=3  VCC=5V  GND=GND        Buzzer: + a pin 8, otro a GND
//   Botones (cada uno entre su pin y GND): CERO=4  AYUDA=5
//   RC522 (¡3.3V, NO 5V!): SDA=10  SCK=13  MOSI=11  MISO=12  RST=9  GND  3.3V
// Librerías: HX711 (Bogdan Necula) y MFRC522 (Miguel Balboa).
#include "HX711.h"
#include <SPI.h>
#include <MFRC522.h>

HX711 balanza;
MFRC522 rfid(10, 9);                         // SS = 10, RST = 9

// ---- Ajustes ----
const float FACTOR = 1124.0;                 // Calibrado con Calibracion.ino (iPhone 13, 174 g)
const int BUZZER = 8;
const int BOTON_CERO  = 4;                   // Botón de la DERECHA: pone la balanza en cero (con la taza puesta)
const int BOTON_AYUDA = 5;                   // Botón de la IZQUIERDA: ayuda
const bool CONFIRMAR_BOTONES = true;         // true = el primer toque dice qué es el botón y el segundo lo ejecuta
const unsigned long VENTANA_CONFIRMAR = 6000; // ms para dar el segundo toque
const bool BUZZER_PASIVO = true;             // true si con HIGH no suena (usa tone)
const bool USAR_NFC = true;                  // true cuando el lector RC522 está conectado
const bool SOLO_NFC = false;                 // true = demo SIN balanza: la ficha simula el peso (requiere USAR_NFC)
const bool SIMULAR = false;                  // true = SIN balanza ni lector: todo desde el Monitor Serie
                                             //   peso: escribe 230 y Enter (0 = retirar)
                                             //   tag:  escribe t100 y Enter (meta de 100 g)
const bool MOSTRAR_PESO = false;             // true = imprime "G:xx.x" (gramos) para diagnosticar

// Tabla de tags: ID -> gramos de meta. Para saber el ID de cada tag, acércalo
// (con USAR_NFC = true) y mira "TAG:xxxxxxxx" en el Monitor Serie; cópialo aquí.
struct Tag { const char* uid; int gramos; const char* id; };   // id opcional (déjalo "" para que solo diga los gramos)
const Tag TAGS[] = {
  { "53A3818F950001", 100, "" },           // Ficha A: meta de 100 g
  { "53A2818F950001", 50, "" },            // Ficha B: meta de 50 g
};
const int N_TAGS = sizeof(TAGS) / sizeof(TAGS[0]);

// ---- Umbrales ----
const float UMBRAL_PESO   = 20.0;            // g mínimos para considerar que hay algo puesto
const float UMBRAL_RETIRO = 10.0;            // g por debajo de los cuales se considera retirado
const float TOLERANCIA    = 2.0;             // g de variación permitida para estable
                                             // (si el ruido no deja estabilizar, sube a 3 o 4)
const float MARGEN_META   = 10.0;            // g de margen alrededor de la meta (±10 g = alcanzada)
const float CAMBIO_LISTO  = 15.0;            // g de cambio en LISTO para volver a medir
const float MAX_PESO_CERO = 150.0;           // g: con más peso que esto el botón de cero avisa y no pone el cero
const unsigned long TIEMPO_ESTABLE = 2000;   // ms que debe estar estable

// ---- Tonos (Hz): cada sonido es distinto ----
const int TONO_FICHA  = 2000;                // Ficha leída
const int TONO_CERO   = 1500;                // Botón de cero
const int TONO_AYUDA  = 2200;                // Botón de ayuda
const int TONO_TIC    = 1800;                // Tic sin meta
const int TONO_META   = 2400;                // Tono continuo en la meta
const int TONO_LISTO  = 2600;                // Pitido largo de listo
const int TONO_PASADO = 700;                 // Te pasaste (grave, rápido)
const int TONO_ERROR  = 350;                 // Error (muy grave)

enum Estado { ESPERANDO, MIDIENDO, LISTO, PASADO };
Estado estado = ESPERANDO;

int meta = 0;                                // Meta en gramos (0 = sin ficha)
int metaIndice = -1;                         // Posición en la tabla de la ficha que fijó la meta (-1 = ninguna)
float pesoSimulado = 0;
float pesoActual = 0;                        // Último peso leído
float pesoRef = 0;                           // Peso de referencia para medir estabilidad
float pesoTick = 0;                          // Peso en el que sonó el último "tic" (medida sin meta)
bool celdaLista = false;                     // true cuando el HX711 ya respondió y se hizo el cero
unsigned long inicioEstable = 0;
unsigned long ultimoPitido = 0;              // Para el pitido progresivo
unsigned long ultimoAnuncioFalta = 0;        // Cuándo se dijo por última vez cuánto falta
float faltanteAnunciado = 0;                 // Cuánto faltaba en ese último anuncio
unsigned long ultimoDebug = 0;
unsigned long ultimoBoton = 0;               // Para ignorar rebotes de los botones
unsigned long anuncioCero = 0;               // Cuándo se anunció el botón de cero (0 = no anunciado)
unsigned long anuncioAyuda = 0;              // Cuándo se anunció el botón de ayuda
unsigned long ultimaLectura = 0;             // Cuándo respondió la celda por última vez
unsigned long ultimoError = 0;               // Cuándo sonó el último aviso de error de la celda

// ---------------------------------------------------------------- SONIDO

// Pitido con frenado del programa (dura "ms")
void beepTono(int ms, int freq) {
  if (BUZZER_PASIVO) {
    tone(BUZZER, freq, ms);
    delay(ms);
  } else {
    digitalWrite(BUZZER, HIGH);
    delay(ms);
    digitalWrite(BUZZER, LOW);
  }
}

void beep(int ms) { beepTono(ms, TONO_FICHA); }

// Pitido corto que no frena el programa (buzzer pasivo); con buzzer activo usa beepTono()
void sonidoTono(int ms, int freq) {
  if (BUZZER_PASIVO) tone(BUZZER, freq, ms);
  else beepTono(ms, freq);
}

void pitar() { beepTono(600, TONO_LISTO); }  // Listo: un pitido largo y agudo

void alertaPasado() {                        // Te pasaste: tres pitidos rápidos y graves
  for (int i = 0; i < 3; i++) {
    beepTono(150, TONO_PASADO);
    delay(100);
  }
}

void errorSonoro() {                         // Error: tres pitidos muy graves
  for (int i = 0; i < 3; i++) {
    beepTono(250, TONO_ERROR);
    delay(150);
  }
}

// Margen de acierto: 6 % de la meta, entre 4 g y MARGEN_META (así una meta de 30 g no acepta de 20 a 40)
float margenMeta() {
  return constrain(meta * 0.06, 4.0, MARGEN_META);
}

// Mientras echan el ingrediente hacia la meta: el pitido se acelera y sube de tono
// al acercarse, y pasa a tono continuo al entrar en el margen de la meta.
void pitidoProgreso(float peso) {
  if (peso >= meta - margenMeta()) {
    sonidoTono(250, TONO_META);              // En la meta: tono continuo
    return;
  }
  float avance = constrain(peso / meta, 0.0, 1.0);
  unsigned long intervalo = 900 - (unsigned long)(650 * avance);   // 900 ms (lejos) -> 250 ms (cerca)
  if (millis() - ultimoPitido >= intervalo) {
    ultimoPitido = millis();
    sonidoTono(60, 1200 + (int)(1000 * avance));                   // Sube de 1200 a 2200 Hz
  }
}

// Con meta: de vez en cuando manda cuánto falta para que Processing lo diga ("Faltan 60 gramos").
// Solo habla si el faltante cambió al menos 20 g desde el último aviso (3 g cuando ya falta poco,
// para sugerir con qué completar), y no más de uno cada 3 s.
void anunciarFalta(float peso) {
  float faltante = meta - peso;
  float paso = (faltante <= 20.0) ? 3.0 : 20.0;
  if (millis() - ultimoAnuncioFalta >= 3000 && fabs(faltante - faltanteAnunciado) >= paso) {
    ultimoAnuncioFalta = millis();
    faltanteAnunciado = faltante;
    Serial.print("FALTA:");
    Serial.println((int)round(faltante));
  }
}

// Sin meta (sin ficha): un "tic" corto cada 10 g que cambia el peso, para sentir cómo va llenando
void pitidoLibre(float peso) {
  if (fabs(peso - pesoTick) >= 10.0) {
    pesoTick = peso;
    sonidoTono(40, TONO_TIC);
  }
}

// Prototipo sin celda: simula echar el ingrediente hasta la meta.
// Pitidos cada vez más rápidos -> tono continuo -> listo.
void simularLlenado(int g) {
  Serial.println("MIDIENDO");
  for (int pausa = 700; pausa > 80; pausa -= 70) {
    beep(60);
    delay(pausa);
  }
  beepTono(1200, TONO_META);                 // Tono continuo: llegaste al peso
  Serial.print("PESO:");
  Serial.println(g);
  delay(4000);                               // Tiempo para que la interfaz diga el peso
  Serial.println("ESPERA");
}

// ---------------------------------------------------------------- FICHAS

// Fija una meta nueva (solo si está esperando). La misma ficha de nuevo la cancela.
void aplicarMeta(int g, int indice, const char* id) {
  if (g <= 0) return;
  if (estado != ESPERANDO) {                 // Hay algo en la balanza: no se puede cambiar la meta
    beepTono(300, TONO_ERROR);
    Serial.println("AVISO:RETIRA");
    return;
  }
  if (!SOLO_NFC && g == meta && indice == metaIndice) {              // Misma ficha otra vez: cancela la meta (medida libre)
    meta = 0;
    metaIndice = -1;
    Serial.println("META:0");
    Serial.println("META_CANCELADA");        // Processing dice "Ya no tienes meta"
    beep(80);
    delay(100);
    beep(80);                                // Dos pitidos cortos: meta cancelada
    return;
  }
  meta = g;
  metaIndice = indice;
  Serial.print("META:");
  Serial.print(meta);
  if (id[0] != '\0') {                        // Si la ficha tiene nombre: META:130:nombre
    Serial.print(":");
    Serial.print(id);
  }
  Serial.println();
  beep(150);                                 // Pitido corto: ficha leída
  if (SOLO_NFC) {
    delay(1500);                             // Pausa: "ahora echa el ingrediente"
    simularLlenado(g);
    meta = 0;
    Serial.println("META:0");
  }
}

void revisarTag() {
  if (SIMULAR || !USAR_NFC) return;
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;

  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  Serial.print("TAG:");
  Serial.println(uid);                       // Útil para copiar el ID a la tabla
  for (int i = 0; i < N_TAGS; i++) {
    if (uid.equals(TAGS[i].uid)) {
      aplicarMeta(TAGS[i].gramos, i, TAGS[i].id);
      return;
    }
  }
  beepTono(400, TONO_ERROR);                 // Ficha que no está en la tabla
  Serial.println("ERROR:FICHA");
}

// ---------------------------------------------------------------- ESTADOS

// Pasa a MIDIENDO tomando el peso actual como referencia
void empezarAMedir(float peso) {
  estado = MIDIENDO;
  pesoRef = peso;
  pesoTick = peso;
  faltanteAnunciado = meta;                  // El primer aviso llega cuando ya falte 20 g menos que la meta
  inicioEstable = millis();
  Serial.println("MIDIENDO");
}

void volverAEsperar() {
  estado = ESPERANDO;
  if (meta != 0) {
    meta = 0;
    metaIndice = -1;
    Serial.println("META:0");
  }
  Serial.println("ESPERA");
}

// Avisa (sonido + serial) que la celda no responde
void avisarCelda() {
  ultimoError = millis();
  Serial.println("ERROR:CELDA");
  errorSonoro();
}

void revisarBotones() {
  if (millis() - ultimoBoton < 500) return;  // Evita lecturas dobles
  if (digitalRead(BOTON_CERO) == LOW) {
    ultimoBoton = millis();
    beepTono(60, TONO_CERO);                 // Clic inmediato: la persona sabe que el botón se pulsó
    if (CONFIRMAR_BOTONES && (anuncioCero == 0 || millis() - anuncioCero > VENTANA_CONFIRMAR)) {
      anuncioCero = millis();                // Primer toque: dice qué es el botón
      Serial.println("BOTON_CERO");
      return;
    }
    anuncioCero = 0;                         // Segundo toque: lo ejecuta
    if (!SIMULAR && !SOLO_NFC) {
      if (!celdaLista) return;               // Sin celda no hay cero que poner (ya se avisa el error)
      if (pesoActual > MAX_PESO_CERO) {      // Demasiado peso: seguramente hay ingrediente encima
        errorSonoro();
        Serial.println("AVISO:CERO");
        return;
      }
      balanza.tare();                        // Cero con la taza puesta
      pesoActual = 0;
    }
    estado = ESPERANDO;
    beepTono(200, TONO_CERO);
    Serial.println("CERO");
  } else if (digitalRead(BOTON_AYUDA) == LOW) {
    ultimoBoton = millis();
    beepTono(80, TONO_AYUDA);
    bool midiendo = (estado == MIDIENDO || estado == PASADO);
    if (CONFIRMAR_BOTONES && !midiendo && (anuncioAyuda == 0 || millis() - anuncioAyuda > VENTANA_CONFIRMAR)) {
      anuncioAyuda = millis();               // Primer toque: dice qué es el botón (midiendo, la ayuda es directa)
      Serial.println("BOTON_AYUDA");
      return;
    }
    anuncioAyuda = 0;
    if (midiendo) {
      Serial.print("LLEVA:");                // "Llevas X de Y gramos" / "Te pasaste por X gramos"
      Serial.println((int)round(pesoActual));
    } else {
      Serial.println("AYUDA");
    }
  }
}

// ---------------------------------------------------------------- PRINCIPAL

void setup() {
  Serial.begin(9600);
  pinMode(BUZZER, OUTPUT);
  pinMode(BOTON_CERO, INPUT_PULLUP);
  pinMode(BOTON_AYUDA, INPUT_PULLUP);
  if (!SIMULAR) {
    if (USAR_NFC) {
      SPI.begin();
      rfid.PCD_Init();
      rfid.PCD_DumpVersionToSerial();        // Diagnóstico: debe decir "Firmware Version: 0x92" (o 0x91)
    }
    if (!SOLO_NFC) {
      balanza.begin(2, 3);                   // DT = pin 2, SCK = pin 3
      balanza.set_scale(FACTOR);
      if (balanza.wait_ready_timeout(3000)) {   // Espera al HX711 máximo 3 s, sin quedarse colgado
        delay(1000);
        balanza.tare();                      // Cero con la plataforma vacía
        celdaLista = true;
        ultimaLectura = millis();
      } else {
        avisarCelda();                       // Se reintenta en el loop
      }
    }
  }
  beep(200);                                 // Pitido de arranque: el buzzer y el código funcionan
  Serial.println("ESPERA");
}

void loop() {
  float peso;
  revisarBotones();
  if (SIMULAR) {
    if (Serial.available()) {
      if (Serial.peek() == 't') {            // Tag simulado: t100
        Serial.read();
        aplicarMeta(Serial.parseInt(), -1, "");
      } else {                               // Peso escrito a mano
        pesoSimulado = Serial.parseFloat();
      }
      while (Serial.available()) Serial.read();
    }
    peso = pesoSimulado;
    delay(100);
  } else {
    revisarTag();
    if (SOLO_NFC) return;                    // Sin celda: todo ocurre al leer la ficha
    if (!celdaLista) {                       // La celda no respondió al arrancar: reintenta
      if (balanza.is_ready()) {
        delay(1000);
        balanza.tare();
        celdaLista = true;
        ultimaLectura = millis();
        Serial.println("ESPERA");
      } else {
        if (millis() - ultimoError > 4000) avisarCelda();
        return;
      }
    }
    if (!balanza.is_ready()) {               // La celda dejó de responder (cable suelto)
      if (millis() - ultimaLectura > 3000 && millis() - ultimoError > 4000) avisarCelda();
      return;
    }
    ultimaLectura = millis();
    peso = balanza.get_units(2);             // Promedio de 2 lecturas (~0.2 s): rápido para el pitido progresivo
  }
  pesoActual = peso;

  if (MOSTRAR_PESO && millis() - ultimoDebug >= 500) {   // Diagnóstico: Processing ignora estas líneas
    ultimoDebug = millis();
    Serial.print("G:");
    Serial.println(peso, 1);
  }

  switch (estado) {
    case ESPERANDO:
      if (peso > UMBRAL_PESO) {              // Pusieron algo
        empezarAMedir(peso);
      }
      break;

    case MIDIENDO:
      if (meta > 0 && peso >= UMBRAL_RETIRO && peso <= meta + margenMeta()) {
        pitidoProgreso(peso);                // Con meta: pitido que se acelera hacia la meta
        if (peso < meta - margenMeta()) anunciarFalta(peso);   // y dice cuánto falta
      } else if (meta == 0 && peso >= UMBRAL_RETIRO) {
        pitidoLibre(peso);                   // Sin meta: un tic cada 10 g
      }
      if (peso < UMBRAL_RETIRO) {            // Lo quitaron antes de terminar (la meta se conserva)
        estado = ESPERANDO;
        Serial.println("ESPERA");
      } else if (meta > 0 && peso > meta + margenMeta()) {
        estado = PASADO;                     // Se pasaron de la meta
        alertaPasado();
        Serial.print("PASADO:");             // Con cuánto se pasó de la meta: Processing dice cuánto quitar
        Serial.println((int)round(peso - meta));
      } else if (fabs(peso - pesoRef) > TOLERANCIA) {
        pesoRef = peso;                      // Aún cambia: reinicia el conteo
        inicioEstable = millis();
      } else if (millis() - inicioEstable >= TIEMPO_ESTABLE) {
        // Estable 2 segundos. Con meta, solo vale si está cerca de ella.
        if (meta == 0 || peso >= meta - margenMeta()) {
          estado = LISTO;
          pesoRef = peso;
          pitar();
          Serial.print("PESO:");
          Serial.println((int)round(peso));  // Peso real medido (Processing lo redondea a 10 g al decirlo)
        } else {
          inicioEstable = millis();          // Falta ingrediente: sigue esperando
        }
      }
      break;

    case LISTO:
      if (peso < UMBRAL_RETIRO) {            // Retiraron el ingrediente
        volverAEsperar();
      } else if (fabs(peso - pesoRef) > CAMBIO_LISTO) {
        empezarAMedir(peso);                 // Cambiaron el peso sin retirar: medir de nuevo
      }
      break;

    case PASADO:
      if (peso < UMBRAL_RETIRO) {            // Retiraron todo
        volverAEsperar();
      } else if (peso <= meta + margenMeta() - 3) {
        empezarAMedir(peso);                 // Quitaron un poco y ya no se pasa
      }
      break;
  }
}
