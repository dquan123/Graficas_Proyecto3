# Proyecto 3: Space Travel
Diego Quan (24336)

Simulación del sistema solar con un software renderer hecho en Zig 0.16.0. Raylib se usa solo para abrir la ventana, leer teclado y mouse, y mostrar el framebuffer. Todo lo demás (proyección 3D, relleno de triángulos, z-buffer, texturas, luz, cámara, colisiones) está programado desde cero. No se usa ninguna función de dibujo ni de 3D de raylib.

**Video:** [VIDEO_AQUI]

## Cómo correrlo

Requiere Zig 0.16.0.

```
zig build run -Doptimize=ReleaseFast
```

## Controles

| Tecla | Acción |
|---|---|
| Mouse | Mirar |
| W / S | Avanzar / retroceder (hacia donde miras) |
| A / D | Moverse a los lados |
| E / Q | Subir / bajar |
| Shift izquierdo | Ir más rápido |
| ESC | Salir |

## Requisitos de la rúbrica

| Requisito | Pts |
|---|---|
| 5 cuerpos con textura distinta (Sol, Tierra, Luna, Marte, Júpiter) | 50 |
| Órbitas de los planetas | 20 |
| El Sol ilumina a los planetas | 10 |
| Back-face culling | 10 |
| Movimiento 3D de la cámara | 10 |
| Skybox con estrellas | 10 |
| La cámara no atraviesa los cuerpos | 10 |
| Nave que sigue a la cámara | 30 |
| Nave modelada por nosotros (`nave.blend`) | 10 |
| El programa corre bien (60 FPS) | 10 |
| No se atasca estando cerca de los objetos | 10 |
| **Total según la lista** | **180** |

No implementados: LOD, shader único por cuerpo y viaje rápido.

## Cómo funciona

1. **Carga de modelos** (`obj.zig`): lee `v`, `vt`, `vn` y `f` de un `.obj`; las caras de más de 3 vértices se parten en triángulos.
2. **Pipeline 3D** (`camera.zig`, `render.zig`): mundo → cámara con los ejes de la cámara → perspectiva dividiendo entre la profundidad → pantalla. Sin matrices 4×4.
3. **Triángulos rellenos** (`raster.zig`): coordenadas baricéntricas por píxel dentro de la caja contenedora del triángulo.
4. **Z-buffer**: guarda `1/z` por píxel, de modo que los cuerpos cercanos tapan a los lejanos sin importar el orden.
5. **Texturas**: coordenadas UV interpoladas con perspectiva correcta (`u/z`, `v/z`, `1/z`) y muestreo del píxel más cercano (`texture.zig`).
6. **Luz**: la normal de cada píxel se interpola; en las esferas es el vector del centro al punto, y en la nave la normal de cada triángulo.
7. **Animación**: cada cuerpo orbita y gira con `velocidad × tiempo`.

## Estructura

```
src/
  main.zig        bucle principal, entrada, escena
  framebuffer.zig lienzo de píxeles (base del curso, con put_pixel)
  vec3.zig        vectores
  obj.zig         cargador de .obj
  camera.zig      cámara y proyección
  raster.zig      triángulos, z-buffer, texturas y luz
  render.zig      dibujo de esferas y de la nave
  texture.zig     texturas
  system.zig      cuerpos, órbitas y colisiones
  stars.zig       skybox de estrellas
  assets/         modelos .obj y texturas .png
nave.blend        modelo de la nave en Blender
```

## Créditos

Texturas de [Solar System Scope](https://www.solarsystemscope.com/textures/) (CC BY 4.0). Modelo de la nave hecho por mí en Blender.

## Uso de IA

Se usó un asistente de IA (Claude) como ayuda durante el desarrollo: explicación de los conceptos, escritura de código y corrección de errores de compilación. Las pruebas, la revisión de cada fase, el modelado de la nave y las decisiones de diseño fueron propias.
