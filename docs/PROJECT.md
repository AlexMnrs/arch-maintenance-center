# Fundamentos del proyecto

Este documento conserva el alcance y las reglas de producto de Arch Maintenance
Center. Describe lo que se sabe hoy; no convierte decisiones pendientes en
hechos.

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

## Objetivos de la primera versión

1. Resumir la salud del sistema con severidad y causas comprensibles.
2. Reunir actualizaciones, servicios, logs, almacenamiento y red en una vista.
3. Ordenar las señales por urgencia y utilidad, no por su origen técnico.
4. Permitir copiar un diagnóstico reproducible y comandos de mantenimiento.
5. Enseñar suficiente contexto para que el usuario pueda decidir con criterio.

## Fuera de alcance inicialmente

- Ejecutar automáticamente actualizaciones, limpiezas o reparaciones.
- Solicitar o conservar credenciales de administrador.
- Sustituir a `pacman`, `systemctl`, `journalctl` u otras herramientas del
  sistema.
- Prometer soporte para otras distribuciones antes de validar Arch Linux.
- Aceptar derivadas de Arch solo por declarar `ID_LIKE=arch`.
- Diagnóstico predictivo o interpretación generativa de logs sin una política
  explícita de privacidad y calidad.

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

## Módulos candidatos

| Módulo | Señales iniciales | Resultado esperado |
| --- | --- | --- |
| Estado global | Severidad agregada y causas | Resumen priorizado |
| Actualizaciones | Pendientes y última actualización | Contexto, no alarmismo |
| Servicios | Unidades fallidas | Nombre, estado y acceso al detalle |
| Logs | Eventos relevantes recientes | Resumen con evidencia original |
| Disco y limpieza | Uso, caché y huérfanos | Oportunidades seguras de mantenimiento |
| Red | Conectividad, DNS y latencia | Estado básico y fallos visibles |

## Decisiones pendientes

### Decisiones técnicas cerradas

- Plataforma: Arch Linux con `systemd` sobre Noctalia v5 beta.
- Compatibilidad mínima: Noctalia `v5.0.0-beta.9`, plugin API 24.
- Plataforma comprobada: el servicio lee `/etc/os-release` de forma asíncrona
  y solo recopila datos cuando `ID=arch`; una plataforma incompatible o no
  verificable no ejecuta colectores ni ofrece comandos de Arch.
- Lenguaje: Luau con módulos puros comprobables fuera de Noctalia.
- Arquitectura: servicio de recopilación, estado compartido en memoria, widget
  de barra y panel declarativo.
- Distribución: repositorio fuente con `catalog.toml` y plugin instalable en su
  propio subdirectorio.
- Licencia: MIT.
- Idioma inicial de la interfaz: inglés mediante Noctalia Translate.
- Referencia de estructura: el plugin GitHub Activity de AlexMnrs.
- Herramientas demo: ajuste avanzado desactivado por defecto, selector temporal
  de fixtures dentro del panel y vuelta a `Real system` al recargar el plugin.
  Los snapshots sintéticos se marcan como `source.kind=fixture`, alimentan el
  widget y el panel por la misma ruta que los datos reales, no ejecutan
  colectores y no habilitan comandos copiables.

### Recopilación implementada

Todas las comprobaciones son de solo lectura, se ejecutan como el usuario y
tienen un tiempo de espera acotado. Noctalia limita a 25 ms el tiempo de CPU de
cada callback de comando, por lo que los callbacks reciben y analizan
únicamente datos pequeños y acotados. Un timeout, callback perdido o ámbito no disponible
deja el módulo afectado como incompleto; no se convierte en un estado saludable.

| Módulo | Fuente | Ámbito y límite |
| --- | --- | --- |
| Actualizaciones | `checkupdates --nocolor` resumido por una canalización estática y última línea relevante de `/var/log/pacman.log` | Repositorios oficiales, sin `sudo`; conserva el total y como máximo ocho nombre/versiones; 30 s para `checkupdates` |
| Servicios | `systemctl --failed` y `systemctl --user --failed`, resumidos por una canalización estática | Unidades fallidas de sistema y usuario; conserva como máximo veinte por ámbito; 5 s por ámbito |
| Disco | Estadísticas nativas de Noctalia, con `df` como alternativa | Sistema de archivos raíz `/`, 5 s para la alternativa |
| Limpieza | `du --summarize --block-size=1 --exclude='download-*' /var/cache/pacman/pkg`, `pacman -Qtdq` y `journalctl --disk-usage` | Caché, excluyendo directorios privados de descargas temporales que el usuario no puede leer; huérfanos y journal sin `sudo`; conserva ocho huérfanos como máximo; 5 s por fuente |
| Logs | `journalctl` y `journalctl --user` del arranque actual con prioridad `err` o superior, resumidos por una expresión estática de `jq` | Como máximo once eventos por ámbito y diez mostrados; la salida entregada a Luau ya contiene solo fecha, prioridad, origen de 128 caracteres y mensaje de 240; 5 s por ámbito |

Services no comprueba que todas las unidades estén activas ni intenta reparar o
reiniciar servicios: informa únicamente de unidades que `systemd` ya considera
fallidas. Si el ámbito de usuario no puede leerse, conserva el resultado del
ámbito del sistema pero marca el diagnóstico global como parcial.

Cleanup conserva por separado el resultado de caché, huérfanos y journal. Los
huérfanos son una señal informativa de mantenimiento; la caché y el journal se
exponen como contexto hasta que existan umbrales configurables y documentados.

Logs recoge solamente eventos de error o prioridad superior que el usuario
actual puede leer. Se muestra la evidencia normalizada, pero los mensajes libres
no se copian al diagnóstico: este contiene únicamente conteos, truncamiento y
disponibilidad de los ámbitos.

El estado global distingue la severidad de los datos de mantenimiento: una
señal `info` no produce por sí sola una recomendación, mientras que solo
`warning` y `critical` elevan la atención. Las acciones recomendadas se derivan
de señales concretas: actualizaciones pendientes, unidades fallidas, disco raíz
por encima del 80 % y paquetes huérfanos. Los errores recientes del journal,
la caché y el tamaño del journal se mantienen como evidencia o contexto. Una
actualización pendiente es informativa, pero pasa a advertencia tras 14 días
desde la última actualización completa. Los módulos incompletos se declaran en
el resumen junto a la severidad conocida.

Los detalles de Updates incluyen el comando `sudo pacman -Syu` únicamente
como texto copiable y con advertencia; no se añade a los comandos generales de
inspección ni se ejecuta desde el plugin.

El servicio se activa internamente cada segundo para separar la programación
automática del refresco de la vigilancia. Cada recopilación tiene una generación
y un plazo defensivo de 35 segundos. Al vencerlo, completa los módulos
pendientes con `collection_deadline`, publica un diagnóstico incompleto y libera
el refresco; callbacks duplicados o tardíos de una generación previa se ignoran.
El botón Refresh solo permanece deshabilitado mientras esa recopilación válida
está activa.

### Decisiones futuras

Antes de ampliar la primera versión deben investigarse y registrarse:

- la evolución de la fórmula del estado global y sus umbrales configurables;
- el soporte de gestores auxiliares del AUR;
- la interpretación de warnings genéricos antes de tratarlos como incidencias;
- las fuentes de datos y permisos mínimos de red;
- tamaños reales de descarga y cualquier acción correctiva.

Las decisiones firmes deberán añadirse a este documento con su justificación.
Los cambios visibles para usuarios deberán añadirse también al changelog.
