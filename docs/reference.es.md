# Lupita: referencia

El detalle que no cabe en el [README](../README.es.md): permisos, todo lo que Lupita reconoce, sus límites y cómo compilarla.

## Actualizar desde la 0.8.0 o anterior

Sustituye la app a mano una vez. Después, en **Privacidad y
seguridad**, quita la Lupita antigua de **Accesibilidad** y **Grabación de pantalla** (el botón
**−**) y vuelve a darle los permisos. Es la última vez.

## Permisos y privacidad

Todo ocurre en tu Mac. No se envía nada a ningún sitio y no se guarda nada de lo que consultas.
Lupita solo guarda sus ajustes y el índice de tus archivos Markdown, en memoria.

Pide dos permisos de macOS, y solo los usa cuando pulsas el atajo:

- **Accesibilidad**: para el atajo y para leer el texto exacto bajo el puntero (10-40 ms en apps nativas).
- **Grabación de pantalla**: para las apps que no exponen su texto (VS Code, Cursor, Claude,
  navegadores). Lupita lee una franja de 600 × 80 pt alrededor del puntero con el OCR de Apple
  (Vision), en tu Mac. Mientras mantienes el atajo, lee la ventana bajo el puntero, para
  subrayar lo que sabe explicar.

La única llamada de red es **Buscar actualizaciones…**: pregunta a GitHub por la última release,
y solo cuando lo pulsas. **Instalar y reiniciar** la descarga después. Lupita nunca comprueba en
segundo plano.

Es un compromiso también para las versiones futuras. Si Lupita llega a usar un modelo de lenguaje,
será el modelo de Apple que funciona en tu Mac. Si alguna función necesitara la red, vendría
apagada, claramente señalada, y solo funcionaría si tú la activas.

### Informe de IDs (opcional, lo envías tú)

Para ayudar a descubrir formatos de ID que Lupita aún no conoce, mantén **⌥** al abrir el menú
de Lupita y elige **Crear informe de IDs…**. Lupita te enseña todas las filas antes de guardar
nada y puedes quitar cualquiera. Una fila solo lleva la forma de un ID (letras como `A`, dígitos
como `9`: `E2-S3` pasa a `A9-A9`), su prefijo y dónde está escrito (encabezado, tabla, lista,
nombre de archivo, frontmatter). Añade el nombre del archivo, recuentos y si Lupita lo encuentra.
Nunca lleva títulos, definiciones, líneas de texto, rutas de carpetas ni nombres de repos
(los repos son «repo 1», «repo 2»). Guardas el archivo o abres un correo nuevo con él adjunto,
y **tú** pulsas enviar: Lupita no hace ninguna llamada de red.

## Que tus agentes sean fáciles de consultar

Lupita funciona sin configurar nada: ya explica la mayor parte de lo que citan tus agentes. Una
regla en las instrucciones de tu agente la lleva más lejos: a lo que creen a partir de ahora y a
su vocabulario interno.

Lupita nunca escribe en tus repos. Te da un prompt para tu propio agente. Si el agente falla, no
hace nada; no pide commit ni decisiones de criterio. Pégale esto a tu agente (el prompt va siempre
en inglés; los agentes lo leen):

```text
Add this block at the end of this repo's agent instructions file (`AGENTS.md`, or `CLAUDE.md` if there is no `AGENTS.md`). Change nothing else. If the block is already there, do nothing.

<!-- lupita -->
Define each new decision, question, lesson or story once as `## ID — Title` plus a one-line summary.
Add each new internal term to the glossary (`docs/glossary.md` if there is none) as `- **term** — definition`.
Where this repo already has a format for these, keep it.
<!-- /lupita -->
```

La ventana **Prepara tus repos…** (menú de la barra, y en el primer arranque) lista los repos con
`AGENTS.md` o `CLAUDE.md`, cuántas referencias aún no explica nada y si la regla está puesta.
**Copiar y abrir** copia el prompt y abre el repo en tu editor (Cursor, VS Code, Windsurf, Zed o
Finder), listo para pegar.

En [`examples/demo-project`](../examples/demo-project) hay un proyecto pequeño que usa todos los
formatos.

## Referencia

### Qué cuenta como definición

Lupita busca IDs que estén **definidos** en algún sitio, no solo mencionados. Los prefijos se
descubren, no se configuran: `D`, `Q`, `ADR`, `QL`, `E2-S3b` o lo que se hayan inventado tus agentes.

| Formato | Ejemplo |
|---|---|
| Encabezado | `## D23 — Usar SQLite` · `### Q07: ¿Cuántos repos?` |
| Lista o inicio de línea | `- **L34**: nunca parsear HTML con regex` · `Q07: …` |
| Primera columna de tabla | `\| E2-S3 \| Entrada por voz \| … \|` · `\| **E8-S6 Regalar monedas [Could]** \|` |
| Nombre de archivo | `docs/adr/ADR-004-storage.md` · `decisions/D23.md` |
| Frontmatter | `id: ADR-004` |

Todo lo demás es una mención. Las secciones *sobre* un ID (`## D34 parte 2`) y las etiquetas
de prioridad (`## P1`) se reconocen y no estorban. Un vigilante de archivos reindexa el repo que
cambia, así que un ID escrito hace unos segundos se encuentra igualmente.

### Todo lo que explica Lupita

Commits, ramas, archivos y el resto se consultan en el momento en que los señalas, así que nunca están desactualizados.

<details>
<summary>Los 13 tipos de referencia, con lo que muestra el tooltip</summary>

| Señalas | El tooltip muestra |
|---|---|
| Un nombre de repo (`atlas`) | El título y la primera línea de su README, la rama actual, el último commit y los cambios sin commitear |
| Un commit (`e455cf7`) | Su mensaje, la fecha y si está en `main`. Clic: el commit en GitHub |
| Una rama (`fix/search`) | Su último commit y cuánto va por delante de `main`, o, si se borró, el merge que la cerró |
| Un archivo (`docs/decisions.md:12`) | Su título y primera línea (Markdown) o su último cambio. Clic: lo abre en la línea |
| Un comando (`/retro`) | Su descripción, de `.claude/commands` o `.claude/skills`, en el repo o en `~/.claude` |
| Un término de glosario (`liquidación`, `el libro mayor`) | Su definición, de un archivo de glosario (`glossary.md`, `glosario.md`…) del repo. Clic: lo abre en la línea. Valen términos de una a cuatro palabras; si viene de otro repo, lo indica |
| Un símbolo (`build_glyphs`, `ARM_TENSION`, `test_engine`, `"panza_a"`) | Su propio comentario (3 primeras líneas) y dónde se define, o «sin comentario». Primero el repo de la ventana; si es de otro repo, lo indica. Una palabra suelta necesita `()` o comillas invertidas |
| Una dirección local (`localhost:8130`, `http://127.0.0.1:8131/x.html`) | Qué repo la sirve (por el proceso que escucha o `.claude/launch.json`), qué página y si está encendida. No hace ninguna petición |
| Un token CSS (`--accent`, `var(--accent)`) o un color hex (`#0E5400`) | Su valor en claro y oscuro, una muestra de color y dónde se define (o qué tokens tienen ese color) |
| Un comando de terminal (`npm run build`, `git reset --hard`) | Qué hace el script (de `package.json`) o una línea sobre git y los comandos comunes, con aviso en las opciones peligrosas |
| Un error (`ENOENT`, `TypeError`, `HTTP 401`) o una etiqueta HTML (`<dialog>`) | Una línea de un diccionario fijo |
| Una palabra de git en prosa (`rebase`, `fast-forward`, `detached HEAD`, `pushear`) | Una línea en lenguaje llano y un ejemplo. Una palabra que también es del habla corriente (`main`, `push`, `rama`) solo cuenta junto a otra palabra de git, en inline code o junto al nombre de un archivo o rama |
| Una PR (`#123`, `PR 123`) | Título y fecha del merge, leídos del historial git local del repo de la ventana; o «No está en el historial local» |

</details>

Commits, ramas y PRs necesitan git (las Command Line Tools); sin ellas, simplemente no se reconocen.

**Apaga la jerga que ya conoces.** En **Explicar términos de:** del menú, cada diccionario fijo
está encendido por defecto: **Git** (palabras de git en prosa y comandos `git …`), **Terminal**
(comandos de shell como `rm` o `chmod`) y **Development** (errores, estados HTTP y etiquetas
HTML). Lo que sale de tus repos (IDs, glosarios, commits, ramas, archivos, PRs, símbolos, tokens,
direcciones locales y scripts de `package.json`) está siempre encendido.

### Qué repo, cuando los IDs coinciden

`D001` suele existir en todos los repos. Lupita elige el bueno por este orden: un repo nombrado
justo antes del ID, un repo nombrado en el archivo que lees, el repo de la ventana activa, la
carpeta más cercana. Si la definición viene de otro repo, el tooltip lo dice.

## Límites conocidos

- En apps Electron y navegadores el texto llega por OCR (150-300 ms). Las apps nativas
  responden por accesibilidad (10-40 ms).
- Los IDs muy cortos leídos por OCR (`D5` a partir de "DS") se muestran como sugerencia,
  "¿Querías decir D5?", nunca como respuesta.
- Un ID citado de otro repo sin nombrarlo se resuelve con el del repo local.
- Solo se indexan archivos Markdown para los IDs. Archivos, commits y ramas se buscan al momento.
- Una rama borrada solo se encuentra si algún mensaje de commit la nombra (un merge suele hacerlo).

## Herramientas parecidas

- **Consultar de macOS** (⌃⌘D) y [Lookupper](https://apps.apple.com/app/lookupper/id1667225994):
  el mismo gesto, para palabras del diccionario.
- **[Autolinks de GitHub](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/configuring-autolinks-to-reference-external-resources)**
  e **issue navigation de JetBrains**: convierten prefijos fijos en enlaces, dentro de su herramienta.
- **[VS Code ADR Manager](https://github.com/adr/vscode-adr-manager)**, **[Backlog.md](https://github.com/MrLesk/Backlog.md)**:
  guardan decisiones y tareas en Markdown para agentes.

Lupita es para el momento intermedio: estás leyendo lo que ha escrito un agente, donde sea, y
necesitas saber qué está citando.

## Desarrollo

Para compilar desde el código, con Xcode o solo con las Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/manubarranco/Lupita.git
cd Lupita
./scripts/bundle.sh
open build/Lupita.app
```

macOS olvida los permisos en cada compilación salvo que la app esté firmada con un certificado
estable: crea en Acceso a Llaveros un certificado autofirmado de **Firma de código** llamado
`Lupita Dev` y `scripts/bundle.sh` lo usará. Sin él el script se para; para compilar igualmente
con firma ad-hoc, ejecuta `LUPITA_SIGN_IDENTITY=- ./scripts/bundle.sh`.

```bash
./scripts/test.sh                 # tests (funciona sin Xcode)
swift run lupita index ~/Repos      # indexar y ver cifras
swift run lupita D23 --repo mirepo  # resolver un ID desde la terminal
swift run lupita report ~/Repos     # informe de acierto (HTML, se queda en local)
```

Decisiones de diseño: [`docs/decisions.md`](decisions.md), escritas en el mismo formato que lee Lupita.
Registro de depuración (qué se consultó y por qué vía): `defaults write com.manubarranco.lupita debugLog -bool true`.

## Licencia

[MIT](../LICENSE)
