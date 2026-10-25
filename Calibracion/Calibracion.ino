// CALIBRACIÓN del medidor. Se sube ANTES del código final.
// Pasos: plataforma puesta y VACÍA -> reset -> poner pasta de 500 g ->
// esperar 20 s -> escribir 500 y Enter UNA sola vez.
// Monitor Serie: 9600 baud, "Sin ajuste de línea".
#include "HX711.h"

HX711 balanza;
float factor = 0;  // Se calcula al calibrar

void setup() {
  Serial.begin(9600);
  Serial.println("Arduino vivo");
  balanza.begin(2, 3);                      // DT = pin 2, SCK = pin 3

  // Espera al HX711 máximo 3 segundos, sin quedarse colgado
  if (!balanza.wait_ready_timeout(3000)) {
    Serial.println("HX711 NO responde: revisa VCC, GND, DT y SCK");
    while (true);
  }

  balanza.tare();                           // Cero (incluye la plataforma)
  Serial.println("1. Plataforma vacia (ya esta en cero)");
  Serial.println("2. Pon el peso conocido y espera 20 segundos");
  Serial.println("3. Escribe el peso en gramos y Enter (ej: 500)");
}

void loop() {
  if (Serial.available()) {
    float pesoConocido = Serial.parseFloat();
    while (Serial.available()) Serial.read();   // Vacía el buffer
    if (pesoConocido > 0) {
      factor = balanza.get_value(20) / pesoConocido;   // Promedio de 20 lecturas
      balanza.set_scale(factor);
      Serial.print("FACTOR = ");
      Serial.println(factor, 2);
      Serial.println("Calibrado. Ahora muestra gramos.");
    }
  }

  if (factor != 0 && balanza.is_ready()) {
    Serial.print(balanza.get_units(10), 1);
    Serial.println(" g");
  }
  delay(300);
}
