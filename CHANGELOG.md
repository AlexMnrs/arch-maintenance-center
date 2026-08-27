# Changelog

Todos los cambios notables de este proyecto se documentarán en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
y el proyecto seguirá [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
cuando comience a publicar versiones.

El plugin y el catálogo declaran actualmente la versión `0.3.0`. Mientras no
exista una release publicada, los cambios permanecen bajo `Unreleased`.

## Unreleased

### Added

- Lista compacta y navegable de acciones recomendadas para actualizaciones,
  unidades fallidas, poco espacio en `/` y paquetes huérfanos.
- Comprobación previa de `/etc/os-release` que limita el diagnóstico a Arch
  Linux confirmado mediante `ID=arch`.
- Vistas de detalle navegables para Updates, Services, Disk & Cleanup y System
  Logs, sin cambiar el tamaño ni la API del panel.
- Muestra acotada de paquetes oficiales pendientes y de unidades fallidas, con
  indicadores cuando hay más elementos de los que se muestran.
- Información de caché de pacman, paquetes huérfanos y espacio del journal.
- Eventos de error recientes y visibles del journal de sistema y de usuario,
  limitados por ámbito y presentados como evidencia informativa.
- Botón específico para copiar el comando de actualización, con aviso explícito
  de que modifica el sistema y no se ejecuta desde el plugin.
- Pruebas de formato de bytes, limpieza, logs, truncamiento y redacción del
  diagnóstico.
- Definición inicial de la visión, el alcance y los principios de seguridad del
  proyecto.
- README público y referencia visual de la primera versión.
- Instrucciones locales para agentes de desarrollo.
- Plugin funcional para Noctalia v5 con widget de salud, panel y servicio de
  monitorización.
- Comprobaciones de actualizaciones, unidades fallidas y uso del disco raíz.
- Diagnóstico redactado y comandos de inspección copiables.
- Configuración de refresco periódico, IPC de refresco y pruebas automatizadas
  en Luau.
- Herramientas de desarrollo opcionales con diez fixtures visuales para revisar
  estados saludables, recomendaciones, advertencias, errores, carga y
  plataformas incompatibles sin tocar el sistema.
- Licencia MIT y flujo de integración continua para GitHub.

### Changed

- La documentación pública y del proyecto queda sincronizada con el contrato
  implementado en `0.3.0`: módulos, límites de recopilación, estados,
  recomendaciones, ajustes, fixtures, comandos, refresco y validación en CI.
- El mantenimiento recomendado se calcula mediante acciones concretas en vez
  de contar todos los módulos informativos; los errores del journal ya no
  elevan por sí solos el resumen de mantenimiento.
- El diagnóstico copiable incluye la plataforma y las acciones recomendadas,
  y deja de ofrecer comandos de Arch cuando la plataforma no es compatible.
- El resumen global distingue mantenimiento disponible de advertencias y
  condiciones críticas; una cantidad de actualizaciones no se convierte por sí
  sola en alerta.
- Los snapshots distinguen datos reales de fixtures demo; el selector temporal
  se reinicia a `Real system` al recargar el plugin y mantiene panel y widget
  sincronizados.
- Updates muestra una fecha y hora absoluta para la última actualización
  completa y para la comprobación disponible, en lugar de solo días
  transcurridos.
- El diagnóstico copiable incorpora conteos y disponibilidad de Cleanup y Logs
  sin incluir mensajes libres del journal.
- El panel explica qué módulo impide completar el diagnóstico, distingue la
  primera carga de un resultado incompleto y aclara los ámbitos de `systemd`
  comprobados por Services.
- Los controles y colores del panel siguen las proporciones y los roles de
  paleta nativos de Noctalia para adaptarse al tema activo; la hora del último
  diagnóstico respeta también el formato configurado por el usuario.

### Fixed

- Logs preprocesa una única muestra JSON acotada por ámbito antes del callback,
  evitando exceder el presupuesto de CPU de Luau al decodificar eventos.
- La medición de caché omite los directorios privados `download-*` creados por
  pacman, que antes hacían fallar `du` pese a producir un tamaño válido.
- El estado de mantenimiento deja de usar roles de color no reconocidos por
  Noctalia API 24.
- Los ámbitos de logs disponibles ya no conservan detalles de error residuales
  en el estado compartido.
- El encabezado prioriza un diagnóstico incompleto sobre mantenimiento
  informativo, y Disk & Cleanup deja visible qué fuentes de limpieza no se
  pudieron consultar.
- La recopilación de logs normaliza los mensajes localmente en vez de depender
  de una opción opcional de `journalctl`, mejorando la compatibilidad.
- La recopilación de Updates, Services y paquetes huérfanos limita el volumen
  que llega a los callbacks de Noctalia.
- Updates reduce la salida procesada a un único recuento y una sola línea de
  `pacman.log`, para respetar el presupuesto de CPU de los callbacks de
  Noctalia.
- Un watchdog de 35 segundos termina las recopilaciones atascadas, publica el
  diagnóstico incompleto y vuelve a habilitar Refresh; los callbacks tardíos no
  pueden alterar una recopilación posterior.
- Un fallo al comprobar unidades de usuario ya no se presenta como un
  diagnóstico completo.
- Los entrypoints usan rutas `require` literales compatibles con Noctalia API
  24, sin fallbacks que oculten errores; el widget ya no depende de la cadena
  de construcción de fixtures demo.
- El patrón que analiza la salida de `checkupdates` ya no contiene un escape
  inválido para el analizador de Luau.

### Security

- Los fixtures no ejecutan colectores ni habilitan comandos de inspección o
  actualización; el diagnóstico sintético se identifica explícitamente como
  demo antes de copiarse.
