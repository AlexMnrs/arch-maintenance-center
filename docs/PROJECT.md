# Fundamentos del proyecto

Este documento conserva el alcance, el comportamiento implementado y las
decisiones de producto de Arch Maintenance Center. La documentación pública
resume este contrato; este archivo mantiene el detalle necesario para
desarrollarlo sin ampliar el alcance por accidente.

## Estado actual

La versión `0.3.0` del plugin `alexmnrs/arch-maintenance-center` implementa una
arquitectura de servicio + widget + panel para Noctalia v5 con plugin API 24.
La primera versión funcional es de solo lectura y cubre actualizaciones,
servicios fallidos, uso del disco, información de limpieza y errores recientes
del journal. La interfaz inicial está en inglés mediante Noctalia Translate.

## Visión

Crear un centro de mantenimiento para Arch Linux integrado en Noctalia que
condense el estado del sistema en una lectura rápida y accionable. Debe ser útil
tanto para el uso diario como para aprender qué ocurre realmente en el equipo,
sin ocultar la evidencia ni automatizar acciones arriesgadas.

## Usuario y contexto inicial

El caso de uso que da origen al proyecto es un usuario de Arch Linux con interés
en administración de sistemas que quiere observar y mantener su portátil desde
su entorno de escritorio. El producto no debe quedar acoplado a un modelo de
hardware concreto.

## Objetivos y alcance de la versión 0.3.0

1. Resumir la salud del sistema con severidad y causas comprensibles.
2. Reunir actualizaciones, servicios, logs y almacenamiento en una vista única.
3. Ordenar las señales por urgencia y utilidad, no por su origen técnico.
4. Permitir copiar un diagnóstico reproducible y comandos de inspección.
5. Enseñar suficiente contexto para que el usuario pueda decidir con criterio.

La red aparece como una posibilidad futura, no como una capacidad de esta
versión.

## Fuera de alcance actual

- Ejecutar automáticamente actualizaciones, limpiezas o reparaciones.
- Solicitar o conservar credenciales de administrador.
- Sustituir a `pacman`, `systemctl`, `journalctl` u otras herramientas del
  sistema.
- Prometer soporte para otras distribuciones antes de validar Arch Linux.
- Aceptar derivadas de Arch solo por declarar `ID_LIKE=arch`.
- Consultar AUR, calcular tamaños de descarga o estimar espacio recuperable.
- Convertir warnings genéricos o eventos del journal en incidencias sin una
  regla explícita.
- Añadir red, diagnóstico predictivo o monitorización continua.
- Interpretar logs de forma generativa sin una política explícita de privacidad
  y calidad.

## Reglas fundamentales

### Seguridad antes que comodidad

- La observación será de solo lectura siempre que sea posible.
- Ningún botón ambiguo debe producir cambios en el sistema.
- Los comandos sugeridos se mostrarán completos antes de que el usuario los
  copie o ejecute por su cuenta.
- Cada acción potencialmente destructiva deberá explicar alcance, riesgo y
  reversibilidad.
- Los fallos al recopilar datos degradarán el módulo afectado; nunca se
  presentarán como un sistema saludable por defecto.

### Evidencia antes que conclusiones

- Un estado global debe poder rastrearse hasta señales concretas.
- Se distinguirán error, advertencia, información y dato no disponible.
- No se tratará el número de actualizaciones como una emergencia por sí solo.
- Los resúmenes de logs conservarán hora, origen y acceso al evento original.
- El diagnóstico copiable evitará secretos y datos personales por defecto.

### Interfaz y experiencia

- La información crítica debe entenderse en unos segundos.
- El color reforzará el significado, pero nunca será el único indicador.
- Los módulos compartirán estados de carga, vacío, error y dato no disponible.
- La vista compacta responderá “qué mirar”; el detalle responderá “por qué”.
- El diseño seguirá las convenciones visuales y de interacción de Noctalia.

## Áreas del producto

| Área | Estado | Señales y resultado |
| --- | --- | --- |
| Estado global | Implementado | Severidad agregada, completitud y causas priorizadas |
| Updates | Implementado | Actualizaciones de repositorios oficiales, muestra de paquetes y última actualización completa |
| Services | Implementado | Unidades `systemd` fallidas de sistema y usuario, con acceso al detalle |
| Disk & Cleanup | Implementado | Uso de `/`, caché de pacman, huérfanos y almacenamiento del journal |
| System Logs | Implementado | Eventos `err` o superiores del arranque actual que el usuario puede leer |
| Red | Futuro | Conectividad, DNS y latencia; requiere definir fuentes y permisos mínimos |

## Decisiones técnicas cerradas

- **Plataforma:** Arch Linux con `systemd` sobre Noctalia v5 beta.
- **Compatibilidad mínima:** Noctalia `v5.0.0-beta.9`, plugin API 24.
- **Comprobación de plataforma:** el servicio lee `/etc/os-release` de forma
  asíncrona, con un máximo de 64 KiB, y solo recopila datos cuando encuentra un
  `ID=arch` válido. No usa `ID_LIKE` como sustituto. Una plataforma
  incompatible o no verificable no ejecuta colectores ni ofrece comandos de
  Arch.
- **Lenguaje:** Luau, con módulos puros comprobables fuera de Noctalia.
- **Arquitectura:** servicio de recopilación, estado compartido en memoria,
  widget de barra y panel declarativo.
- **Distribución:** repositorio fuente con `catalog.toml` y plugin instalable en
  su propio subdirectorio.
- **Licencia:** MIT.
- **Idioma inicial de la interfaz:** inglés mediante Noctalia Translate.
- **Referencia de estructura:** el plugin GitHub Activity de AlexMnrs.
- **Privacidad:** no se guarda el diagnóstico en disco; el diagnóstico copiable
  excluye stdout crudo y mensajes libres del journal, y conserva únicamente
  valores acotados, estados, conteos, disponibilidad y nombres de unidades
  validados.
- **Herramientas demo:** ajuste avanzado desactivado por defecto, selector
  temporal de fixtures dentro del panel y vuelta a `Real system` al recargar el
  plugin. Los snapshots sintéticos se marcan como `source.kind=fixture`,
  alimentan el widget y el panel por la misma ruta que los datos reales, no
  ejecutan colectores y no habilitan comandos copiables.

## Recopilación implementada

Todas las comprobaciones son de solo lectura, se ejecutan como el usuario y
tienen un tiempo de espera acotado. Noctalia limita a 25 ms el tiempo de CPU de
cada callback de comando, por lo que los callbacks reciben y analizan
únicamente datos pequeños y acotados. Un timeout, callback perdido o ámbito no
disponible deja el módulo afectado como incompleto; no se convierte en un
estado saludable.

| Módulo | Fuente | Ámbito y límite |
| --- | --- | --- |
| Actualizaciones | `checkupdates --nocolor` resumido por una canalización estática y la última línea relevante de `/var/log/pacman.log` | Repositorios oficiales, sin `sudo`; conserva el total y como máximo ocho nombre/versiones; 30 s para `checkupdates`; si faltan `grep` o `tail`, la fecha queda desconocida |
| Servicios | `systemctl --failed` y `systemctl --user --failed`, resumidos por una canalización estática | Unidades fallidas de sistema y usuario; conserva como máximo veinte por ámbito; 5 s por ámbito; si el ámbito de usuario falla, conserva el sistema y marca el módulo incompleto |
| Disco | Estadísticas nativas de Noctalia, con `df` como alternativa | Sistema de archivos raíz `/`; la alternativa tiene 5 s de timeout |
| Limpieza | `du --summarize --block-size=1 --exclude='download-*' /var/cache/pacman/pkg`, `pacman -Qtdq` y `journalctl --disk-usage` | Caché, excluyendo directorios privados de descargas temporales; huérfanos con una muestra máxima de ocho; fuentes independientes, 5 s por fuente |
| Logs | `journalctl` y `journalctl --user` del arranque actual con prioridad `err` o superior, resumidos por una expresión estática de `jq` | Como máximo once eventos por ámbito y diez mostrados tras mezclar; la salida entregada a Luau ya contiene solo fecha, prioridad, origen de 128 caracteres y mensaje de 240 |

La ausencia de `pacman-contrib` deja Updates como no disponible, pero no oculta
los demás módulos. La ausencia de `jq` deja Logs como error. Las fuentes de
Cleanup se conservan por separado, de modo que una fuente inaccesible se marca
sin ocultar las otras. El ámbito de usuario de Services y Logs también puede
ser parcial mientras el resultado del sistema permanece visible.

Services no comprueba que todas las unidades estén activas ni intenta reparar o
reiniciar servicios: informa únicamente de unidades que `systemd` ya considera
fallidas.

Cleanup conserva por separado el resultado de caché, huérfanos y journal. Los
huérfanos son una señal informativa de mantenimiento; la caché y el journal se
exponen como contexto hasta que existan umbrales configurables y documentados.

Logs recoge solamente eventos de error o prioridad superior que el usuario
actual puede leer. Se muestra la evidencia normalizada en el panel, pero los
mensajes libres no se copian al diagnóstico: este contiene únicamente conteos,
truncamiento y disponibilidad de los ámbitos.

## Interpretación del estado

El estado global distingue la severidad de los datos de mantenimiento: una
señal `info` no produce por sí sola una recomendación de atención global,
mientras que solo `warning` y `critical` elevan la severidad. Las acciones
recomendadas se derivan de señales concretas:

- actualizaciones pendientes: recomendación `info`, que pasa a `warning` tras
  14 días desde la última actualización completa;
- unidades fallidas: recomendación `warning`;
- disco raíz por encima del 80 %: recomendación `warning`, y `critical` desde
  el 90 %;
- paquetes huérfanos: recomendación `info`.

Los errores recientes del journal, la caché y el tamaño del journal se mantienen
como evidencia o contexto. Los módulos con error, no disponibles o con un
ámbito incompleto se declaran en el resumen junto a la severidad conocida.

Los detalles de Updates incluyen el comando `sudo pacman -Syu` únicamente como
texto copiable y con advertencia; no se añade a los comandos generales de
inspección ni se ejecuta desde el plugin. Los comandos generales solo se ofrecen
cuando la plataforma es Arch compatible y los nombres de unidades se validan
antes de interpolarlos.

## Ciclo de vida y refresco

- Al activar el plugin, el servicio comprueba primero la plataforma y solo
  después inicia los cinco módulos.
- El panel y el menú contextual del widget solicitan un refresco mediante el
  estado compartido; el servicio también acepta el evento IPC `refresh`.
- El ajuste `refresh_interval_minutes` permite 15, 30 o 60 minutos. Un tick
  interno de un segundo vigila el watchdog y programa el siguiente refresco sin
  convertir cada tick en una recopilación.
- Solo una recopilación válida permanece activa. Las solicitudes concurrentes se
  encolan para ejecutar otra al finalizar la actual.
- Cada recopilación tiene una generación y un plazo defensivo de 35 segundos. Al
  vencerlo, los módulos pendientes reciben `collection_deadline`, se publica un
  diagnóstico incompleto y se libera el refresco; callbacks duplicados o
  tardíos de una generación previa se ignoran.
- El botón Refresh solo permanece deshabilitado mientras esa recopilación
  válida está activa.
- Con una fixture seleccionada, Refresh reconstruye datos sintéticos y no
  ejecuta colectores reales. Desactivar Developer tools o recargar el plugin
  devuelve el origen a `Real system`.

## Fixtures de desarrollo

El selector temporal expone diez ids para revisar estados sin tocar el sistema:

`healthy`, `recommendations`, `attention`, `critical`, `incomplete`,
`all_checks_failed`, `collecting`, `platform_checking`,
`platform_unsupported` y `platform_error`.

Las fixtures cubren estado saludable, recomendaciones informativas, atención,
condición crítica, fallos parciales, fallo total, carga y los tres resultados de
la comprobación de plataforma. Los comandos de inspección y actualización están
deshabilitados mientras una fixture está activa.

## Validación y CI

Los modelos de recopilación, clasificación, recomendaciones, diagnóstico,
fixtures y control de refresco se prueban fuera de Noctalia con Luau. CI:

1. instala Luau en un contenedor Arch;
2. compila todos los entrypoints, módulos y pruebas;
3. verifica que los `require` de módulos Noctalia sean literales y compatibles
   con API 24;
4. ejecuta todos los archivos `tests/*_spec.luau`.

## Decisiones futuras

Antes de ampliar la primera versión deben investigarse y registrarse:

- la evolución de la fórmula del estado global y sus umbrales configurables;
- el soporte de gestores auxiliares del AUR;
- la interpretación de warnings genéricos antes de tratarlos como incidencias;
- las fuentes de datos y permisos mínimos de red;
- tamaños reales de descarga y cualquier acción correctiva.

Las decisiones firmes deberán añadirse a este documento con su justificación.
Los cambios visibles para usuarios deberán añadirse también al changelog.
