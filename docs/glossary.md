# Glosario

- **scope** — elemento `.scope` del prototipo que lleva las variables CSS de un tema y modo; el tooltip se pinta dentro.
- **stage** — fondo falso (líneas grises y una banda de color) sobre el que se dibuja un tooltip para que se vea la translucidez.
- **overflow check** — comprobación de `render-sheets.mjs`: ningún texto se desborda y el ancho renderizado es `size.width`.
- **token semántico** — valor de estilo con nombre de rol (`text.title`, `radius.container`); el tema lo cambia y el componente solo lo referencia.
- **tema** — conjunto de overrides de tokens (tipografía, color, forma, espacio, sombra), con claro y oscuro, sobre el tema base «Lupita».
- **grupo (de tokens)** — uno de los cinco ejes independientes: type, color, shape, space, shadow.
- **variante** — tema que cambia un solo grupo sobre Lupita, para demostrar la independencia (`variants/ind-*.json`).
- **baseline** — marca de un tema cuyos fallos de contraste se avisan y no fallan: hoy solo Lupita, que conserva los colores del sistema.
- **papel tipográfico** — uso del texto al que un tema asigna una fuente: `heading`, `body` o `code` (D55).
- **escala de texto** — los cuatro pasos de tamaño (S, M, L, XL), cada uno una jerarquía completa válida en todos los temas (D55).
- **densidad** — ajuste de espacios (compacta, normal, amplia) independiente del tema (D55).
- **welcome step** — primer paso del onboarding: enseña el gesto (mantener, apuntar, soltar) sobre una nota de muestra antes de pedir carpetas (D56).
- **keycap** — dibujo de una tecla del atajo en el paso de bienvenida; se rellena mientras el atajo está pulsado (D56).
