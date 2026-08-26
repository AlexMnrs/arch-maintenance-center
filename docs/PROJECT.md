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
- Lenguaje: Luau con módulos puros comprobables fuera de Noctalia.
- Arquitectura: servicio de recopilación, estado compartido en memoria, widget
  de barra y panel declarativo.
- Distribución: repositorio fuente con `catalog.toml` y plugin instalable en su
  propio subdirectorio.
- Licencia: MIT.
- Idioma inicial de la interfaz: inglés mediante Noctalia Translate.
- Referencia de estructura: el plugin GitHub Activity de AlexMnrs.

### Decisiones futuras

Antes de ampliar la primera versión deben investigarse y registrarse:

- las fuentes de datos y permisos mínimos de cada módulo;
- la evolución de la fórmula del estado global y sus umbrales configurables;
- el soporte de gestores auxiliares del AUR;
- el formato seguro y redactado del diagnóstico;
- la incorporación de logs, red, caché y paquetes huérfanos.

Las decisiones firmes deberán añadirse a este documento con su justificación.
Los cambios visibles para usuarios deberán añadirse también al changelog.
