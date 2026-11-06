// PRUEBA DE BOTONES - cero en el pin 4, ayuda en el pin 5 (cada uno entre su pin y GND)
// Monitor Serie a 9600. Pulsa cada botón y mira qué pin se activa.
// Debe verse:  botón de la DERECHA  -> "D4 (cero) PULSADO"
//              botón de la IZQUIERDA -> "D5 (ayuda) PULSADO"
// Si los dos botones activan el mismo pin, hay un cable cruzado o los dos van al mismo pin.

const int BOTON_CERO = 4;
const int BOTON_AYUDA = 5;
bool ceroAntes = false;
bool ayudaAntes = false;

void setup() {
  Serial.begin(9600);
  pinMode(BOTON_CERO, INPUT_PULLUP);
  pinMode(BOTON_AYUDA, INPUT_PULLUP);
  Serial.println("PRUEBA DE BOTONES. Sin pulsar nada no debe salir ningun mensaje.");
}

void loop() {
  bool cero = digitalRead(BOTON_CERO) == LOW;
  bool ayuda = digitalRead(BOTON_AYUDA) == LOW;
  if (cero != ceroAntes) {
    Serial.println(cero ? "D4 (cero) PULSADO" : "D4 (cero) suelto");
    ceroAntes = cero;
  }
  if (ayuda != ayudaAntes) {
    Serial.println(ayuda ? "D5 (ayuda) PULSADO" : "D5 (ayuda) suelto");
    ayudaAntes = ayuda;
  }
  delay(20);
}
