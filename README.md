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

## Primera versión

La versión `0.1.0` implementa:

- un estado global claro: correcto, atención necesaria o problema crítico;
- actualizaciones pendientes y antigüedad de la última actualización completa;
- unidades de `systemd` fallidas;
- uso del sistema de archivos raíz;
- diagnóstico redactado y comandos de inspección fáciles de copiar;
- refresco inicial, manual y programado.

Los logs, la red, la caché y los paquetes huérfanos están reservados para los
siguientes hitos.

## Principio de seguridad

La primera versión es **informativa y no destructiva**. Muestra evidencia y
comandos de inspección, pero no ejecuta operaciones privilegiadas, limpiezas,
actualizaciones ni reparaciones.

## Estado del proyecto

El plugin utiliza Luau, la API 24 de Noctalia v5 y una arquitectura de servicio,
widget y panel inspirada en
[GitHub Activity](https://github.com/AlexMnrs/github-activity). Requiere Arch
Linux con `systemd`; `pacman-contrib` habilita la comprobación segura de
actualizaciones mediante `checkupdates`.

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
