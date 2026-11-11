
import serial
import time
import pyttsx3
import winsound

PUERTO = "COM4"
BAUDIOS = 115200


def hablar(texto):

    print("VOZ:", texto)

    try:
        voz = pyttsx3.init()

        voz.setProperty("rate", 150)
        voz.setProperty("volume", 1.0)

        for voice in voz.getProperty("voices"):

            nombre = str(voice.name).lower()
            idiomas = str(voice.languages).lower()

            if (
                "spanish" in nombre
                or "español" in nombre
                or "es-" in idiomas
                or "es_" in idiomas
            ):
                voz.setProperty("voice", voice.id)
                break

        voz.say(texto)
        voz.runAndWait()

        voz.stop()
        del voz

    except Exception as error:

        print("ERROR DE VOZ:", error)


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

            posiciones = {
                "1": "uno",
                "2": "dos",
                "3": "tres",
                "4": "cuatro",
                "5": "cinco"
            }

            nombres = {
                "YOGURT": "Yogurt",
                "GRANOLA": "Granola",
                "FRUTOS SECOS": "Frutos secos",
                "FRESAS": "Fresas",
                "ARANDANOS": "Arándanos"
            }

            posicion_texto = posiciones.get(
                posicion,
                posicion
            )

            nombre = nombres.get(
                ingrediente_actual,
                ingrediente_actual
            )

            hablar(
                nombre
                + ". Debe ir en la posición "
                + posicion_texto
                + "."
            )

            hablar(
                "Levanta el vaso "
                "y colócalo suavemente "
                "sobre el espacio indicado."
            )

        elif linea == "CORRECTO":

            sonido_correcto()

            hablar(
                "Correcto. "
                "Continúa con el siguiente vaso."
            )

        elif linea == "INCORRECTO":

            sonido_incorrecto()

            hablar(
                "Incorrecto. "
                "Intenta nuevamente."
            )

        elif "PARFAIT COMPLETADO" in linea:

            hablar(
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
