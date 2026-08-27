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
- una lista priorizada de acciones recomendadas, trazables a actualizaciones,
  unidades fallidas, espacio insuficiente o paquetes huérfanos;
- una comprobación previa de plataforma que ejecuta el diagnóstico únicamente
  cuando `/etc/os-release` confirma `ID=arch`;
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
- herramientas de desarrollo opcionales con fixtures visuales para revisar todos
  los estados del panel y del widget sin modificar el sistema;

No incluye AUR, tamaños de descarga, clasificación de warnings o logs,
cálculo de espacio recuperable, red ni métricas de monitorización continua.

## Principio de seguridad

El plugin es **informativo y no destructivo**. Muestra evidencia y comandos,
pero no ejecuta operaciones privilegiadas, limpiezas, actualizaciones ni
reparaciones. El detalle de Updates puede copiar `sudo pacman -Syu` tras
explicar su efecto; esa acción nunca se ejecuta desde Noctalia.

Las herramientas de desarrollo están desactivadas por defecto. Al activar
`Developer tools` en los ajustes avanzados aparece un selector temporal en el
panel para cargar fixtures sintéticos; se restauran los datos reales al
recargar el plugin y los comandos quedan deshabilitados mientras hay datos demo.

## Estado del proyecto

El plugin utiliza Luau, la API 24 de Noctalia v5 y una arquitectura de servicio,
widget y panel inspirada en
[GitHub Activity](https://github.com/AlexMnrs/github-activity). Requiere Arch
Linux confirmado por `ID=arch` y con `systemd`; `pacman-contrib` habilita la comprobación segura de
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

Para revisar estados visuales, activa `Developer tools` en los ajustes del
plugin y elige una entrada del selector `Data source`. `Real system` vuelve a
la comprobación normal; los fixtures no ejecutan colectores ni escriben en el
sistema.

## Licencia

[MIT](./LICENSE)
