<img src="docs/brand/lupita.svg" width="80" alt="Lupita: una lupa con dos ojos de píldora">

# Lupita

**Tu agente dice `D23`, `L04`, `E2-S4`. Lupita te dice qué significan.**

Apunta a cualquier referencia, en cualquier app, pulsa un atajo y lee su definición en tus repos.

Los agentes de código (Claude Code, Cursor, Devin, Copilot…) guardan su memoria en archivos
Markdown y la citan por ID: *"como se decidió en D23, y a la espera de Q07, he aplicado
L34"*. El agente sabe qué son. Tú no te acuerdas. Lupita es una app de la barra de menús de
macOS que te enseña la definición de la referencia que tienes bajo el ratón, en cualquier
app: un chat con un agente, un editor, una terminal, el navegador.

![Demo de Lupita: al apuntar a D003 en un chat con un agente aparece su definición](docs/demo.gif)

**[⬇ Descarga Lupita para macOS](https://github.com/manubarranco/lupita/releases/latest/download/Lupita.zip)** (Apple Silicon, macOS 14 o posterior)

[Read in English](README.md)

## Cómo funciona

1. **Indexa tus repos.** Registras una o varias carpetas (`~/Repos` por defecto). Lupita
   encuentra los repos git que hay dentro y lee sus `.md`, buscando IDs que estén
   **definidos** en algún sitio, no solo mencionados. Los prefijos se descubren, no se
   configuran: `D`, `Q`, `ADR`, `QL`, `E2-S3b` o lo que se hayan inventado tus agentes.
2. **Apuntas y pulsas ⌃⌥⌘** (las tres a la vez y sueltas). Lupita lee la palabra bajo el
   ratón: con la accesibilidad de macOS cuando la app expone su texto, o con OCR en tu Mac
   sobre una franja pequeña alrededor del ratón cuando no (VS Code, Cursor, Claude,
   navegadores).
3. **Aparece un tooltip** con el ID, su título, dos o tres líneas de la definición, el repo y
   el archivo, y cuántas veces se cita. Clic para abrir el archivo en esa línea; Esc lo cierra.

El índice se mantiene al día solo: un vigilante de archivos reindexa el repo que cambia, y un
ID escrito hace unos segundos se encuentra igualmente.

### Qué cuenta como definición

| Formato | Ejemplo |
|---|---|
| Encabezado | `## D23 — Usar SQLite` · `### Q07: ¿Cuántos repos?` |
| Lista o inicio de línea | `- **L34**: nunca parsear HTML con regex` · `Q07: …` |
| Primera columna de tabla | `\| E2-S3 \| Entrada por voz \| … \|` · `\| **E8-S6 Regalar monedas [Could]** \|` |
| Nombre de archivo | `docs/adr/ADR-004-storage.md` · `decisions/D23.md` |
| Frontmatter | `id: ADR-004` |

Todo lo demás es una mención. Las secciones *sobre* un ID (`## D34 parte 2`) y las etiquetas
de prioridad (`## P1`) se reconocen y no estorban.

### Más allá de los IDs: commits, ramas, archivos y comandos

Los agentes también citan cosas que viven en git y en el disco. Lupita las busca en el momento
en que las señalas, así que nunca están desactualizadas:

| Señalas | La ficha muestra |
|---|---|
| Un nombre de repo (`atlas`) | El título y la primera línea de su README, la rama actual, el último commit y los cambios sin commitear |
| Un commit (`e455cf7`) | Su mensaje, la fecha y si está en `main`. Clic: el commit en GitHub |
| Una rama (`fix/search`) | Su último commit y cuánto va por delante de `main`, o, si se borró, el merge que la cerró |
| Un archivo (`docs/decisions.md:12`) | Su título y primera línea (Markdown) o su último cambio. Clic: lo abre en la línea |
| Un comando (`/retro`) | Su descripción, de `.claude/commands` o `.claude/skills`, en el repo o en `~/.claude` |
| Un término de glosario (`pase de render`, `la Mesa`) | Su definición, de un archivo de glosario (`glossary.md`, `glosario.md`…) del repo. Clic: lo abre en la línea. Valen términos de una a cuatro palabras; si viene de otro repo, lo indica |

Commits y ramas necesitan git (las Command Line Tools); sin ellas, simplemente no se reconocen.

### Qué repo, cuando los IDs coinciden

`D001` suele existir en todos los repos. Lupita elige el bueno por este orden: un repo nombrado
justo antes del ID, un repo nombrado en el archivo que lees, el repo de la ventana activa, la
carpeta más cercana. Si la definición viene de otro repo, el tooltip lo dice.

## Que tus agentes sean fáciles de consultar

Lupita funciona con lo que los agentes ya escriben, pero es exacto cuando cada referencia está
definida así. Añádelo a tu `AGENTS.md` o `CLAUDE.md`:

```markdown
Define every decision, question, lesson or story you create as a heading
`## ID — Title`, followed by a one-line summary. Cite it by ID elsewhere.
```

En [`examples/demo-project`](examples/demo-project) hay un proyecto pequeño que usa todos los
formatos.

## Instalar

Necesita macOS 14 o posterior. La release es para Apple Silicon; en un Mac Intel, compílala desde el código.

**Desde una release.** Descarga `Lupita.zip` en [Releases](../../releases), descomprímelo y
mueve `Lupita.app` a Aplicaciones. La app aún no está notarizada, así que la primera vez que macOS la bloquee:
abre **Ajustes del Sistema → Privacidad y seguridad**, baja hasta el final y pulsa **Abrir igualmente**.

**Desde el código.** Con Xcode o solo con las Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/manubarranco/lupita.git
cd lupita
./scripts/bundle.sh
open build/Lupita.app
```

## Permisos y privacidad

Lupita pide dos permisos de macOS, y solo los usa cuando pulsas el atajo:

- **Accesibilidad**: para el atajo y para leer el texto exacto bajo el ratón.
- **Grabación de pantalla**: para leer con el OCR de Apple (Vision) una franja de
  600 × 80 pt alrededor del ratón, en las apps que no exponen su texto.

Todo ocurre en tu Mac. No se envía nada a ningún sitio y no se guarda nada de lo que
consultas. Lupita solo guarda sus ajustes y el índice de tus archivos Markdown, en memoria.

Si compilas desde el código, macOS olvida los permisos en cada compilación salvo que la app
esté firmada con un certificado estable: crea en Acceso a Llaveros un certificado autofirmado
de **Firma de código** llamado `Lupita Dev` y `scripts/bundle.sh` lo usará.

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

```bash
./scripts/test.sh                 # tests (funciona sin Xcode)
swift run lupita index ~/Repos      # indexar y ver cifras
swift run lupita D23 --repo mirepo  # resolver un ID desde la terminal
swift run lupita report ~/Repos     # informe de acierto (HTML, se queda en local)
```

Decisiones de diseño: [`docs/decisions.md`](docs/decisions.md), escritas en el mismo formato que lee Lupita.
Registro de depuración (qué se consultó y por qué vía): `defaults write com.manubarranco.lupita debugLog -bool true`.

## Licencia

[MIT](LICENSE)
