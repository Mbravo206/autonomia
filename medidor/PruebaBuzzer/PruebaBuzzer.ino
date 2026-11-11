// PRUEBA DE BUZZER - pin 8 y GND
// Hace 3 cosas, en bucle: 1) tono con tone() (buzzer pasivo)
// 2) HIGH/LOW (buzzer activo)  3) silencio.
// Mira en el Monitor Serie (9600) cuál de las dos suena.

const int BUZZER = 8;

void setup() {
  Serial.begin(9600);
  pinMode(BUZZER, OUTPUT);
}

void loop() {
  Serial.println("1) tone() 2000 Hz  -> suena si es PASIVO");
  tone(BUZZER, 2000, 700);
  delay(1200);

  Serial.println("2) HIGH             -> suena si es ACTIVO");
  digitalWrite(BUZZER, HIGH);
  delay(700);
  digitalWrite(BUZZER, LOW);
  delay(1200);

  Serial.println("3) silencio");
  delay(1500);
}
