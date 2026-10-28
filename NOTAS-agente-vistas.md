# Notas del agente de vistas

## Decisiones pendientes

- **Materiales en los renders**: `ImageRenderer` no desenfoca lo que hay detrás (Material sale como relleno plano). En la hoja real, Cristal (claro/oscuro, blur 40) no deja ver la banda de color a través como en el HTML (`sheets/theme-cristal.png`). En la app viva el material sí se compone con la ventana de detrás; falta verificarlo a ojo con el panel real. El número `surfaceBlur` solo elige `.thinMaterial` (<=24) o `.regularMaterial`.
- **Spread de sombra**: SwiftUI no tiene spread; se ignora. Afecta a Cristal (spread -8 en la sombra grande: la app la dibuja algo más ancha) y Papel (-2).
- **Sombra con superficie translúcida**: la capa de sombra se enmascara para no verse por debajo del cuadro; no hay equivalente exacto del `box-shadow` de CSS en el radio (radius = blur/2 es una aproximación).
- **Neón**: el resplandor se ve más corto/menos difuso que en el HTML por la misma razón (blur/2).
- **Estado `term` de la galería**: el JSON dice kind «git»; se construye con regla `.term` (sin ID, insignia «término») para mantener el diseño de la tarjeta; el vocabulario real (`.vocabulary`) muestra el ID encima y la insignia «git».
- **Estado `range` de la galería**: 4 entradas (D40–D43, D43 sin definir); la fila «… N más» exige >= 7 entradas y no se dibuja. El texto «Rango · 4 decisiones» sale de `S`, no del JSON. «Citado 1248 veces» sin separador de miles (viene de `S.cited`).
- **Estado `stress`**: usa la regla `.symbol` para tener insignia («símbolo»); el JSON dice «decisión».
- **Core**: `Resolution`, `RangeList`, `Definition` y `Mentions` no tenían inicializadores públicos. Se añadió `Sources/LupitaCore/PublicInits.swift` (solo constructores `made(...)`, sin lógica) porque no se puede tocar `Resolver.swift`. Alternativa: hacer públicos los memberwise en su fichero.
- **@State**: sin Xcode falta el plugin de macros; `HoverBand` usa `State<Bool>` como tipo normal.
- **Hover de fila**: solo las filas pulsables (con archivo/URL) tienen banda de hover; las de diccionario (sin archivo) no. `TooltipView.previewHover` (opcional) deja pintar una fila como en hover para las hojas.
- **Medida de recorte de texto**: no hay forma de leer píxeles recortados en SwiftUI; se compara el ancho ideal (`fittingSize`) con el ancho de token y la altura ideal con la altura bajo ese ancho. Los recortes por `lineLimit` son deliberados (como la elipsis del HTML).
- **Medida de recorte de sombra**: el panel solo (tooltip + insets de sombra) se dibuja sobre transparente con 8 pt de margen extra; cualquier píxel con alfa >= 2/255 en el borde cuenta como violación.
- `--render-tooltips`: lienzo ampliado a 540x320 y margen 40 para no recortar la sombra.
