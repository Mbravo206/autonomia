#include "HX711.h"

HX711 balanza;

const float FACTOR = 430.0;          // ← pon aquí TU factor calibrado
const int BUZZER = 8;
const float UMBRAL_PESO = 20.0;      // g mínimos para considerar que hay algo puesto
const float TOLERANCIA = 2.0;        // g de variación permitida para considerar el peso estable
const unsigned long TIEMPO_ESTABLE = 2000;  // ms que debe estar estable

enum Estado { ESPERANDO, MIDIENDO, LISTO };
Estado estado = ESPERANDO;

float pesoRef = 0;
unsigned long inicioEstable = 0;

void pitar() {
  digitalWrite(BUZZER, HIGH);   // Si tu buzzer es pasivo, usa tone(BUZZER, 1000, 200);
  delay(200);
  digitalWrite(BUZZER, LOW);
}

void setup() {
  Serial.begin(9600);
  pinMode(BUZZER, OUTPUT);
  balanza.begin(2, 3);              // DT = pin 2, SCK = pin 3
  balanza.set_scale(FACTOR);
  delay(1000);
  balanza.tare();                   // Cero con la plataforma vacía
  Serial.println("ESPERA");
}

void loop() {
  if (!balanza.is_ready()) return;
  float peso = balanza.get_units(5);

  switch (estado) {
    case ESPERANDO:
      if (peso > UMBRAL_PESO) {     // Pusieron algo
        estado = MIDIENDO;
        pesoRef = peso;
        inicioEstable = millis();
        Serial.println("MIDIENDO");
      }
      break;

    case MIDIENDO:
      if (peso < UMBRAL_PESO) {     // Lo quitaron antes de terminar
        estado = ESPERANDO;
        Serial.println("ESPERA");
      } else if (fabs(peso - pesoRef) > TOLERANCIA) {
        pesoRef = peso;             // Aún cambia: reinicia el conteo
        inicioEstable = millis();
      } else if (millis() - inicioEstable >= TIEMPO_ESTABLE) {
        estado = LISTO;             // Estable 2 segundos: listo
        pitar();
        Serial.print("PESO:");
        Serial.println((int)round(peso));
      }
      break;

    case LISTO:
      if (peso < UMBRAL_PESO) {     // Retiraron el ingrediente
        estado = ESPERANDO;
        Serial.println("ESPERA");
      }
      break;
  }
}