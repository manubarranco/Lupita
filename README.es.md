<img src="docs/brand/lupita.svg" width="80" alt="Lupita: una lupa con dos ojos de píldora">

# Lupita

**Tu agente dice `D23`, `L04`, `E2-S4`. Lupita te dice qué significan.**

Apunta a cualquier referencia, en cualquier app, pulsa un atajo y lee su definición desde tus repos.

[Read in English](README.md)

Los LLM no tienen memoria persistente. Lo compensan anotándolo todo en los archivos del repo y
dejándose referencias para encontrar y cargar después lo que necesitan. Pero cuando hablan
contigo se olvidan de que tú no tienes su contexto ni su memoria de trabajo, y te dicen cosas como:

> *Queda anotado L023 y D042. Queda pendiente resolver las preguntas abiertas Q34-36. ¿Empezamos con E3S1?*

Lupita es una app de la barra de menús de macOS que busca esas referencias en tus repos, igual
que hacen tus agentes, y te las explica en el sitio.

![Demo de Lupita: al apuntar a D003 en un chat con un agente aparece su definición](docs/demo.gif)

**[⬇ Descarga Lupita para macOS](https://github.com/manubarranco/Lupita/releases/latest/download/Lupita.zip)**

Gratis y de código abierto · Todo se queda en tu Mac · macOS 14 o posterior, Apple Silicon

## Cómo funciona

1. Le dices en qué carpetas están tus repos y enciendes los que estás usando.
2. Lupita busca las referencias en sus archivos `.md` y las indexa.
3. Mantienes pulsado ⌃⌥⌘ y te subraya en pantalla todo lo que puede explicarte.
4. Sueltas las teclas con el ratón sobre una referencia y te la explica en un tooltip, justo ahí.

Funciona en cualquier app: Cursor, Claude, Obsidian, Slack, una nota, un documento, un email…
Donde haya una referencia, Lupita la lee de tu pantalla.

Y no solo IDs como `D042`: también commits, ramas, archivos, comandos y los términos del
glosario de tus repos.

## Cuando la cosa se pone técnica

Además de las referencias, Lupita trae diccionarios de desarrollo, terminal y Git en lenguaje
llano. Si alguien te habla de un `rebase`, un `HTTP 401` o un `chmod`, te lo explica en una
línea. Están pensados para acortar distancias entre diseño, desarrollo y negocio, y se pueden
apagar desde el menú si ya los dominas.

## Todo se queda en tu Mac

Lupita es determinista: no usa IA ni necesita internet para funcionar. Nada se envía a la nube y
no guarda lo que consultas. La única conexión es buscar actualizaciones, y solo cuando tú lo pides.

Para leer tu pantalla te pedirá dos permisos de macOS, y solo los usa cuando pulsas el atajo:

- **Accesibilidad**: para el atajo y para leer el texto de las apps que lo permiten.
- **Grabación de pantalla**: para leer con el OCR de macOS las apps que no lo permiten (Cursor,
  Claude o el navegador).

## Instalar

Descarga `Lupita.zip`, descomprímelo y mueve `Lupita.app` a Aplicaciones.

Aún no está notarizada por Apple, así que la primera vez macOS la bloqueará. Para abrirla, ve a
**Ajustes del Sistema → Privacidad y seguridad**, baja hasta **Seguridad** y pulsa
**Abrir igualmente**.

Para actualizar, abre el menú de Lupita y elige **Buscar actualizaciones…**. Se instala en un clic y
mantiene los permisos.

## Ayuda a tus agentes a ser más claros

Lupita funciona sin configurar nada. Pero si quieres que entienda todo lo que tus agentes creen a
partir de ahora, pídeles que lo escriban en un formato que Lupita sepa leer. La ventana
**Prepara tus repos…** te da el prompt y abre cada repo en tu editor, listo para pegar.

## Más detalles

Todo lo que Lupita reconoce, cómo decide entre repos, sus límites y cómo compilarla desde el
código están en la [referencia](docs/reference.es.md).

## Apoya el proyecto

Si te gusta Lupita, regálale una estrella en GitHub ⭐️ Y si encuentras algo que no explica,
[cuéntamelo](../../issues).

Licencia [MIT](LICENSE).
