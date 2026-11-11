import ddf.minim.*;

Minim minim;
AudioPlayer bienvenida, yogur, granola, fresas, arandanos;
AudioPlayer sonidoActual = null; // Variable para rastrear el audio que está sonando actualmente

void setup() {
  size(600, 400);
  background(30);
  
  minim = new Minim(this);
  
  // Cargamos tus 5 audios reales desde la carpeta "data"
  bienvenida = minim.loadFile("bienvenida.wav");
  yogur = minim.loadFile("yogur.wav");
  granola = minim.loadFile("granola.wav");
  fresas = minim.loadFile("fresas.wav");
  arandanos = minim.loadFile("arandanos.wav");
  
  // Iniciar la experiencia con el audio de bienvenida
  reproducir(bienvenida);
}

void draw() {
  background(35);
  fill(255);
  textSize(18);
  textAlign(CENTER);
  text("COCINA SENSORIAL - PARFAIT INCLUSIVO", width/2, 40);
  
  textSize(14);
  fill(200);
  text("Usa las flechas de tu Makey Makey para explorar los ingredientes.", width/2, 200);
}

// Detectar las teclas del Makey Makey
void keyPressed() {
  if (keyCode == UP) {
    reproducir(yogur);
    println("Reproduciendo: Yogur");
  } 
  else if (keyCode == DOWN) {
    reproducir(granola);
    println("Reproduciendo: Granola");
  } 
  else if (keyCode == LEFT) {
    reproducir(fresas);
    println("Reproduciendo: Fresa");
  } 
  else if (keyCode == RIGHT) {
    reproducir(arandanos);
    println("Reproduciendo: Arándano");
  }
}

// Función con protección contra repetición de tecla y bienvenida protegida
void reproducir(AudioPlayer audio) {
  // 1. Si la bienvenida SÍ está sonando, ignoramos cualquier toque nuevo
  if (bienvenida.isPlaying()) {
    return; 
  }
  
  // 2. Si el audio que intentan reproducir YA es el mismo que está sonando, 
  // no hacemos nada para evitar que se reinicie si dejan el dedo sostenido.
  if (audio == sonidoActual && audio.isPlaying()) {
    return;
  }
  
  // 3. Si es un audio DIFERENTE, cortamos el anterior con seguridad
  if (sonidoActual != null && sonidoActual != bienvenida) {
    sonidoActual.pause();
    sonidoActual.rewind();
  }
  
  // 4. Reproducimos el nuevo audio
  if (audio != null) {
    sonidoActual = audio;
    sonidoActual.rewind();
    sonidoActual.play();
  }
}
