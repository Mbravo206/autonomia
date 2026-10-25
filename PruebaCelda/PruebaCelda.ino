// PRUEBA DE LA CELDA DE CARGA (HX711) - sin calibrar
// Conexión: HX711 DT = pin 2, SCK = pin 3, VCC = 5V, GND = GND.
// Monitor Serie a 9600. Con la plataforma VACÍA, reinicia el Arduino (hace el cero).
// Luego pon algo encima: el número debe subir. Quítalo: debe volver cerca de 0.
// (Los números NO son gramos todavía: eso se hace con Calibracion.ino.)
#include "HX711.h"

HX711 balanza;
long cero = 0;                               // Lectura con la plataforma vacía
long anterior = 0;

void setup() {
  Serial.begin(9600);
  Serial.println("PRUEBA DE CELDA");
  balanza.begin(2, 3);                       // DT = pin 2, SCK = pin 3

  if (!balanza.wait_ready_timeout(3000)) {
    Serial.println("ERROR: el HX711 NO responde. Revisa VCC, GND, DT (pin 2) y SCK (pin 3).");
    while (true);
  }

  cero = balanza.read_average(20);
  anterior = cero;
  Serial.print("HX711 responde. Cero = ");
  Serial.println(cero);
  Serial.println("Ahora pon peso encima y mira si cambia...");
}

void loop() {
  if (!balanza.is_ready()) return;

  long valor = balanza.read_average(5) - cero;   // Cambio respecto al cero
  Serial.print("Valor: ");
  Serial.print(valor);

  long cambio = valor - anterior;
  if (abs(valor) < 2000) {
    Serial.println("   -> en cero (sin peso)");
  } else if (cambio > 2000) {
    Serial.println("   -> SUBIO: la celda detecta peso");
  } else if (cambio < -2000) {
    Serial.println("   -> BAJO: quitaron peso");
  } else {
    Serial.println("   -> con peso, estable");
  }
  anterior = valor;
  delay(300);
}
