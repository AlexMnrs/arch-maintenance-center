# Arch Maintenance Center

Un panel de salud y mantenimiento de solo lectura para Arch Linux, implementado
como plugin de [Noctalia](https://docs.noctalia.dev/).

Arch Maintenance Center responde en pocos segundos a dos preguntas: **¿está
bien el sistema?** y **¿qué debería revisar ahora?** Reúne señales dispersas
de Arch en una vista compacta, explica su prioridad y propone el siguiente paso
sin tomar el control del equipo.

![Panel de Arch Maintenance Center](./arch-maintenance-center/thumbnail.webp)

> [!NOTE]
> La interfaz parte de este [style frame conceptual](./style-frame-v1.png), que
> se conserva como referencia y no debe confundirse con una captura funcional.

## Estado actual

La versión `0.3.0` del plugin `alexmnrs/arch-maintenance-center` requiere
Noctalia v5 con plugin API 24 y ejecuta cinco comprobaciones de solo lectura,
después de confirmar que `/etc/os-release` contiene `ID=arch`:

- **Updates:** actualizaciones de repositorios oficiales, el total pendiente,
  como máximo ocho nombre/versiones y la fecha de la última actualización
  completa leída de `/var/log/pacman.log`;
- **Services:** unidades `systemd` fallidas en los ámbitos de sistema y usuario,
  con como máximo veinte unidades por ámbito;
- **Disk:** uso del sistema de archivos raíz `/`;
- **Cleanup:** caché de pacman, paquetes huérfanos y almacenamiento del journal;
- **System Logs:** errores recientes del journal visibles para el usuario actual
  desde el arranque actual, con una muestra limitada y normalizada;

El estado global distingue diagnóstico saludable, mantenimiento recomendado,
atención, condición crítica y recopilación incompleta, con acciones enlazadas a
la evidencia concreta.

El panel ofrece vistas de detalle, refresco inicial, manual y programado, una
fecha de comprobación independiente de la última actualización completa,
diagnóstico copiable redactado y comandos de inspección de solo lectura. El
widget de barra abre el panel y refleja el estado actual.

Las comprobaciones de plataforma, las unidades de usuario, las fuentes de
Cleanup y los logs distinguen explícitamente los resultados incompletos de los
errores y de un sistema saludable. Una recopilación tiene un watchdog de 35
segundos; un callback tardío no puede modificar una recopilación posterior.

No incluye AUR, tamaños de descarga, clasificación de warnings genéricos o
logs como incidencias, cálculo de espacio recuperable, red ni métricas de
monitorización continua. Tampoco ejecuta actualizaciones, limpiezas,
reparaciones ni comandos privilegiados.

## Recomendaciones y seguridad

Las acciones recomendadas se derivan de señales concretas:

- las actualizaciones pendientes son informativas y pasan a warning cuando han
  transcurrido al menos 14 días desde la última actualización completa;
- una unidad fallida produce una recomendación de revisión;
- el uso de `/` produce warning desde el 80 % y estado crítico desde el 90 %;
- los paquetes huérfanos producen una recomendación informativa.

Los errores del journal, el tamaño de la caché y el tamaño del journal se
conservan como evidencia o contexto y no elevan por sí solos el estado global.
El diagnóstico copiable contiene estados, conteos, disponibilidad y nombres de
unidades seguros; no incluye mensajes libres del journal ni stdout crudo.

El plugin es **informativo y no destructivo**. No solicita ni conserva
credenciales de administrador. El detalle de Updates puede copiar el comando
`sudo pacman -Syu` tras explicar que modifica paquetes y puede pedir una
contraseña, pero el comando nunca se ejecuta desde Noctalia. Los comandos generales son de
inspección y se ofrecen únicamente cuando la plataforma es compatible.

## Configuración y desarrollo visual

El ajuste `Refresh interval` permite refrescos automáticos cada 15, 30 o 60
minutos. `Developer tools` es un ajuste avanzado desactivado por defecto; al
activarlo aparece en el panel el selector temporal `Data source` con estas diez
fixtures:

`healthy`, `recommendations`, `attention`, `critical`, `incomplete`,
`all_checks_failed`, `collecting`, `platform_checking`,
`platform_unsupported` y `platform_error`.

Las fixtures usan la misma ruta de datos que el widget y el panel, no ejecutan
colectores ni habilitan comandos de sistema o de actualización. Se identifican
como demo, y el plugin vuelve a `Real system` al recargarse.

## Desarrollo local

Para probar una copia local desde el directorio raíz del repositorio:

```bash
noctalia msg plugins source add arch-maintenance-center-dev path "$(pwd)"
noctalia msg plugins enable alexmnrs/arch-maintenance-center
```

El widget se llama `health`, el panel `dashboard` y el servicio de recopilación
`monitor`. También se puede refrescar el servicio o abrir el panel por IPC:

```bash
noctalia msg plugin alexmnrs/arch-maintenance-center:monitor all refresh
noctalia msg panel-toggle alexmnrs/arch-maintenance-center:dashboard
```

Las pruebas puras y las comprobaciones que usa CI se ejecutan con:

```bash
for file in arch-maintenance-center/*.luau arch-maintenance-center/lib/*.luau tests/*.luau; do
  luau-compile "$file" >/dev/null
done
bash scripts/check_noctalia_requires.sh
for test_file in tests/*_spec.luau; do
  luau "$test_file"
done
```

## Requisitos y estado del proyecto

- Arch Linux con `ID=arch` en `/etc/os-release` y `systemd`;
- Noctalia v5.0.0-beta.9 o posterior con plugin API 24;
- `pacman-contrib` para `checkupdates` y `jq` para el preprocesado acotado de
  logs;
- comandos base de Arch (`bash`, `awk`, `systemctl`, `journalctl`, `pacman`,
  `du`, `env` y `df`) para las fuentes correspondientes. `grep` y `tail` solo
  se necesitan para recuperar la fecha de la última actualización completa;
  si faltan, la tarjeta de Updates sigue disponible con fecha desconocida.

La caché de pacman excluye directorios privados `download-*`. Los eventos de
logs se limitan a los que el usuario actual puede leer, y la recopilación solo
mantiene el diagnóstico en memoria. El alcance, las reglas de producto y las
decisiones pendientes están en [`docs/PROJECT.md`](./docs/PROJECT.md). Los
cambios notables se registran en [`CHANGELOG.md`](./CHANGELOG.md).

## Licencia

[MIT](./LICENSE)
