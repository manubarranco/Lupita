# Notas del agente de la ventana Aspecto

## Decisiones pendientes

- **Render de controles**: `ImageRenderer` no dibuja los Picker nativos (salen como placeholders amarillos). `--render-appearance` dibuja el contenido de la ventana con un `NSHostingView` en una `NSWindow` fuera de pantalla y `cacheDisplay` a 2x; la muestra sale igual que con ImageRenderer. Las hojas de contacto sí usan ImageRenderer (solo muestras).
- **Medida de sombra**: se miden dos cosas: el panel (+8 pt, método de `--render-themes`) y el lienzo de muestra completo sobre transparente. El lienzo es de 700 pt (la sombra máxima de Cristal en XL son 64 pt por lado; con 620 tocaba el borde), la ventana de 740 pt.
- **Etiquetas de los estados de muestra** («ID definido», «Término»…) vienen de la galería, solo en español, no pasan por `S`. Propuesta: pasarlas a `S` si la ventana debe estar localizada del todo.
- **Menú**: «Aspecto…» queda encima de «Acerca de» sin separador propio (agrupado con Acerca de/Ayuda/Actualizaciones). Si se quiere separado, una línea.
- **Alto de la ventana**: sigue al contenido (la muestra cambia de alto con el estado y el tamaño), así que la ventana salta de alto al cambiar de estado. Propuesta: alto de muestra fijo al máximo de los 10 estados.
- **Material**: el desenfoque de Cristal no se ve en renders offscreen (ver NOTAS-agente-vistas); en la ventana viva sí compone.
- `TooltipStyle.current` gana un parámetro `defaults` (por defecto `.standard`) para poder apuntar el selftest a unos defaults aislados.
- `--show-appearance <png>` guarda el contenido de la ventana real tras 3 s con `cacheDisplay` (no hace falta permiso de pantalla).
- Propuesta (no implementada): ninguna de controles nuevos.
