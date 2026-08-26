# Changelog

Todos los cambios notables de este proyecto se documentarán en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
y el proyecto seguirá [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
cuando comience a publicar versiones.

## Unreleased

### Added

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
- Licencia MIT y flujo de integración continua para GitHub.

### Changed

- El panel explica qué módulo impide completar el diagnóstico, distingue la
  primera carga de un resultado incompleto y aclara los ámbitos de `systemd`
  comprobados por Services.
- Los controles y colores del panel siguen las proporciones y los roles de
  paleta nativos de Noctalia para adaptarse al tema activo; la hora del último
  diagnóstico respeta también el formato configurado por el usuario.

### Fixed

- Updates reduce la salida procesada a un único recuento y una sola línea de
  `pacman.log`, para respetar el presupuesto de CPU de los callbacks de
  Noctalia.
- Un watchdog de 35 segundos termina las recopilaciones atascadas, publica el
  diagnóstico incompleto y vuelve a habilitar Refresh; los callbacks tardíos no
  pueden alterar una recopilación posterior.
- Un fallo al comprobar unidades de usuario ya no se presenta como un
  diagnóstico completo.
- El patrón que analiza la salida de `checkupdates` ya no contiene un escape
  inválido para el analizador de Luau.
