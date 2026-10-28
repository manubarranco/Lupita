# Glosario

- **scope** — elemento `.scope` del prototipo que lleva las variables CSS de un tema y modo; el tooltip se pinta dentro.
- **stage** — fondo falso (líneas grises y una banda de color) sobre el que se dibuja un tooltip para que se vea la translucidez.
- **overflow check** — comprobación de `render-sheets.mjs`: ningún texto se desborda y el ancho renderizado es `size.width`.
- **token semántico** — valor de estilo con nombre de rol (`text.title`, `radius.container`); el tema lo cambia y el componente solo lo referencia.
- **tema** — conjunto de overrides de tokens (tipografía, color, forma, espacio, sombra), con claro y oscuro, sobre el tema base «Lupita».
- **grupo (de tokens)** — uno de los cinco ejes independientes: type, color, shape, space, shadow.
- **variante** — tema que cambia un solo grupo sobre Lupita, para demostrar la independencia (`variants/ind-*.json`).
- **baseline** — marca de un tema cuyos fallos de contraste se avisan y no fallan: hoy solo Lupita, que conserva los colores del sistema.
