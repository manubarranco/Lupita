# Informe: sistema de diseño en la app y ventana «Aspecto»

Rama `claude/aspecto-77327a` (desde `claude/modest-archimedes-oikgin`). **Nada mergeado, nada publicado.**

## Qué hay
- **El sistema de diseño en el modelo D55**: tres papeles de fuente (títulos, texto, código), escala de tamaño S/M/L/XL, densidad compacta/normal/amplia y **7 temas** (Cristal por defecto, Papel, Terminal, Neón, Brutalista, Ficha, Blueprint). Grande, Compacto y Lupita ya no son temas.
- **El tooltip, los avisos y la muestra de color leen esos números**: en `TooltipPanel.swift` no queda ningún valor de estilo escrito a mano; la sombra la dibuja el tema.
- **Ventana «Aspecto»** (menú → «Aspecto…», encima de «Acerca de»): tooltip de muestra vivo con selector de los 10 estados y cuatro controles (tema, modo, tamaño, densidad). Lo elegido se guarda y el tooltip real lo usa la siguiente vez que aparece, sin reiniciar. Sigue los ajustes de macOS de «aumentar contraste» y «reducir transparencia».
- **Hojas de contacto reales** (dibujadas por la app, no HTML): `docs/design-system/sheets-real/` (7 temas × claro/oscuro × 10 estados) y `sheets-real/aspecto/` (tamaños y densidades de la ventana).
- **Números**: 215 tests en verde (184 de antes sin tocar + 31 nuevos), `run-all` en verde, 1680 renders HTML sin desbordes, 140 renders reales sin recortes de sombra ni de texto, 168 capturas de la ventana sin recortes. App firmada con el certificado de siempre y arrancada.

## Qué se propone
1. Probar con el plan de 5 puntos de abajo y decidir qué temas se quedan.
2. Decidir si «Aspecto» pasa los nombres de los estados de muestra a inglés/español (hoy solo español) y si la muestra tiene alto fijo.
3. Cuando lo apruebes, el merge es tuyo.

## Por qué
Tamaño y densidad son preferencias de quien lee, no de un tema (D55); con tokens, cambiar el aspecto no toca las vistas. El subrayado y el resolutor no se han tocado.

## Riesgo (lo que no cuadra o no pude ver)
- **Son 7 temas, no 8**: el brief contaba mal (10 − Lupita − Grande − Compacto). No inventé un octavo.
- **El material de Cristal** se ve plano en las hojas (limitación de los renders sin pantalla); en la ventana viva sí deja ver lo de atrás. A mirar en el test.
- **Parecido con el prototipo HTML**: en píxeles Cristal difiere un 7,6 % (el criterio pedía < 2 %): el texto cae 1-3 pt distinto y el material no se ve en el render. El alto del tooltip coincide a 2 pt (246 vs 248). `sheets-real/cristal-swift-vs-html.png`.
- **Sombras**: SwiftUI no tiene «extensión» de sombra; Cristal y Papel salen algo más anchas y Neón algo menos difuso.
- **Terminal** (Monaco, un solo peso): sin negrita; título e identificador en verde. **Neón, Ficha, Blueprint**: «sin definición» sin cursiva (sus fuentes no tienen).
- **Dos Lupita a la vez**: está arrancada la tuya (build viejo) y la nueva; ciérrala antes de probar, comparten atajo.
- Un tooltip ya abierto no cambia al tocar «Aspecto»; el siguiente sí.
- Detalle y lista completa: `decisiones-pendientes.md` en la carpeta de notas de la sesión.

## Test plan (5 puntos)
1. Abre «Aspecto» desde el menú y recorre los 7 temas.
2. Sube a L y XL y mira un identificador, un término y un rango.
3. Cambia la densidad.
4. Activa Terminal y Ficha en oscuro y mira un color y un aviso.
5. Cierra y reabre la app: se conserva lo elegido.
