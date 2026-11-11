
import os
import serial
import time
import winsound

PUERTO = "COM4"
BAUDIOS = 115200

# La voz es la misma del Medidor (Microsoft Sabina, velocidad -1), pregrabada en la
# carpeta "audios". Así suena igual en cualquier Windows, tenga o no esa voz instalada.
# Los textos y el generador están en voz/ en la raíz del repositorio.
AUDIOS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audios")


def hablar(clip, texto):

    print("VOZ:", texto)

    try:
        winsound.PlaySound(
            os.path.join(AUDIOS, clip + ".wav"),
            winsound.SND_FILENAME | winsound.SND_NODEFAULT
        )

    except Exception as error:

        print("ERROR DE VOZ:", clip, error)


def sonido_correcto():

    print("SONIDO: CORRECTO")

    winsound.Beep(1200, 150)
    winsound.Beep(1600, 180)


def sonido_incorrecto():

    print("SONIDO: INCORRECTO")

    winsound.Beep(400, 350)


print("Conectando con Arduino en COM4...")

arduino = serial.Serial(
    PUERTO,
    BAUDIOS,
    timeout=1
)

time.sleep(2)

print("Arduino conectado.")
print("Sistema de audio listo.")
print("--------------------------------")


hablar(
    "bienvenida",
    "Bienvenido a la estación de organización. "
    "Puedes explorar los vasos con calma para reconocerlos "
    "y sentir sus espacios. "
    "No es necesario hacerlo rápido. "
    "Cuando estés listo, acerca un vaso al lector "
    "para conocer la posición donde debe ir. "
    "Después lleva el vaso con calma hacia la base. "
    "No arrastres el vaso. "
    "Levántalo y colócalo suavemente sobre el espacio. "
    "Dos sonidos cortos significan correcto. "
    "Un sonido diferente significa que debes intentar nuevamente. "
    "Puedes comenzar cuando estés listo."
)


ingrediente_actual = ""


while True:

    try:

        linea = arduino.readline().decode(
            "utf-8",
            errors="ignore"
        ).strip()

        if not linea:
            continue

        print("ARDUINO:", linea)

        if linea.startswith("INGREDIENTE:"):

            ingrediente_actual = linea.split(
                ":",
                1
            )[1].strip()

            print(
                "INGREDIENTE GUARDADO:",
                ingrediente_actual
            )

        elif linea.startswith("DEBE IR EN POSICION:"):

            posicion = linea.split(
                ":",
                1
            )[1].strip()

            print(
                "POSICION RECIBIDA:",
                posicion
            )

            # Audio de cada ingrediente (ing_*.wav) y de cada posición (pos_1 a pos_5)
            ingredientes = {
                "YOGURT": "ing_yogurt",
                "GRANOLA": "ing_granola",
                "FRUTOS SECOS": "ing_frutos_secos",
                "FRESAS": "ing_fresas",
                "ARANDANOS": "ing_arandanos"
            }

            if ingrediente_actual in ingredientes:
                hablar(
                    ingredientes[ingrediente_actual],
                    ingrediente_actual
                )

            hablar(
                "pos_" + posicion,
                "Debe ir en la posición " + posicion + "."
            )

            hablar(
                "levanta",
                "Levanta el vaso "
                "y colócalo suavemente "
                "sobre el espacio indicado."
            )

        elif linea == "CORRECTO":

            sonido_correcto()

            hablar(
                "correcto",
                "Correcto. "
                "Continúa con el siguiente vaso."
            )

        elif linea == "INCORRECTO":

            sonido_incorrecto()

            hablar(
                "incorrecto",
                "Incorrecto. "
                "Intenta nuevamente."
            )

        elif "PARFAIT COMPLETADO" in linea:

            hablar(
                "completado",
                "Excelente. "
                "Has completado correctamente "
                "la organización del parfait."
            )

    except KeyboardInterrupt:

        print()
        print("Programa terminado.")

        arduino.close()

        break

    except Exception as error:

        print("ERROR:", error)

        arduino.close()

        break
