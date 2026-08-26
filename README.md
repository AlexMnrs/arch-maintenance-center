# Arch Maintenance Center

Un panel de salud y mantenimiento de solo lectura para Arch Linux, implementado
como plugin de [Noctalia](https://docs.noctalia.dev/).

Arch Maintenance Center busca responder una pregunta en pocos segundos:
**¿está bien el sistema y qué debería revisar ahora?** Reúne señales dispersas
de Arch en una vista compacta, explica su prioridad y propone el siguiente paso
sin tomar el control del equipo.

![Panel de Arch Maintenance Center](./arch-maintenance-center/thumbnail.webp)

> [!NOTE]
> La interfaz parte de este [style frame conceptual](./style-frame-v1.png), que
> se conserva como referencia y no debe confundirse con una captura funcional.

## Versión actual

La versión `0.3.0` implementa:

- un estado global que diferencia sistema correcto, mantenimiento disponible,
  atención necesaria, condición crítica y recopilación incompleta;
- actualizaciones de repositorios oficiales, con una muestra acotada y fecha de
  comprobación separada de la última actualización completa;
- unidades de `systemd` fallidas, con detalle por ámbito y muestra acotada;
- uso del sistema de archivos raíz, caché de pacman, paquetes huérfanos y
  almacenamiento del journal;
- errores recientes del journal visibles para el usuario desde el arranque
  actual, limitados y mostrados como evidencia informativa;
- vistas de detalle navegables dentro del panel, diagnóstico redactado y
  comandos de inspección fáciles de copiar;
- refresco inicial, manual y programado.

No incluye AUR, tamaños de descarga, análisis de warnings genéricos, red ni
métricas de monitorización continua.

## Principio de seguridad

El plugin es **informativo y no destructivo**. Muestra evidencia y comandos,
pero no ejecuta operaciones privilegiadas, limpiezas, actualizaciones ni
reparaciones. El detalle de Updates puede copiar `sudo pacman -Syu` tras
explicar su efecto; esa acción nunca se ejecuta desde Noctalia.

## Estado del proyecto

El plugin utiliza Luau, la API 24 de Noctalia v5 y una arquitectura de servicio,
widget y panel inspirada en
[GitHub Activity](https://github.com/AlexMnrs/github-activity). Requiere Arch
Linux con `systemd`; `pacman-contrib` habilita la comprobación segura de
actualizaciones mediante `checkupdates`. Los detalles de logs incluyen solo
los eventos que el usuario actual puede leer y el diagnóstico copiable conserva
conteos, no mensajes libres. La recopilación acotada de logs requiere `jq`.

El alcance, los criterios de producto y las decisiones pendientes están en
[`docs/PROJECT.md`](./docs/PROJECT.md). Los cambios notables se registran en
[`CHANGELOG.md`](./CHANGELOG.md).

## Desarrollo local

```bash
noctalia msg plugins source add arch-maintenance-center-dev path "$(pwd)"
noctalia msg plugins enable alexmnrs/arch-maintenance-center
```

Las pruebas puras se ejecutan con:

```bash
for test_file in tests/*_spec.luau; do luau "$test_file"; done
```

## Licencia

[MIT](./LICENSE)
