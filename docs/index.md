Bienvenid@ a la documentación de la Unidad Didáctica 4 del módulo: Administración de bases de datos y almacenamiento en la nube

# Administración de bases de datos en la nube

En esta unidad se estudian los servicios de bases de datos administradas de AWS:

- **Amazon RDS**: bases de datos relacionales administradas (MySQL, MariaDB, PostgreSQL, Oracle, SQL Server y Db2), en las que AWS se encarga del hardware, la instalación, las copias de seguridad y la aplicación de parches.
- **Amazon Aurora**: motor relacional compatible con MySQL y PostgreSQL, diseñado para la nube, con almacenamiento distribuido entre tres zonas de disponibilidad.
- **Amazon DynamoDB**: base de datos NoSQL de clave-valor y documentos, sin servidor, con rendimiento constante a cualquier escala.

En las unidades anteriores se trabajó con el almacenamiento de objetos, bloques y ficheros. En esta se pasa a administrar **sistemas de bases de datos**: elegir dónde residen los datos, crearlos y securizarlos, aplicar cambios durante su ciclo de vida, protegerlos con copias y réplicas, y supervisar y optimizar su rendimiento.

---

## Resultado de aprendizaje

**RA4.** Administra los sistemas de bases de datos, utilizando tanto herramientas gráficas como de línea de comandos, API, y/o IaC, garantizando el almacenamiento, la seguridad digital, y los patrones de uso que mejor se ajusten a los requisitos.

### Criterios de evaluación y dónde se trabajan

| Criterio | Contenido | Apartados |
| --- | --- | --- |
| **a)** Región geográfica y replicación entre zonas o regiones, con latencia y costes eficientes y teniendo en cuenta la residencia de los datos | Regiones y zonas, residencia de los datos (RGPD, ENS), Multi-AZ, réplicas de lectura, Global Database, tablas globales | [Elección de la región](BD-Region.md), [Visión general de RDS](RDS-Introduccion.md), [Replicación y recuperación ante desastres](BD-Replicacion.md) |
| **b)** Cifrado, con claves de cifrado específicas, mediante IaC | AWS KMS, claves administradas por el cliente, plantillas de CloudFormation | [Infraestructura como código](BD-IaC.md), [Cifrado en reposo](RDS-Seguridad.md#5-cifrado-en-reposo) |
| **c)** Visibilidad, acceso, seguridad, monitorización, observabilidad y auditoría, para que solo accedan los perfiles y aplicaciones autorizados | Subredes privadas, grupos de seguridad, IAM, Secrets Manager, RDS Proxy, políticas basadas en recursos, puntos de enlace de VPC, auditoría | [Redes y conectividad](Crear-RDS-03.md), [Securización de RDS y Aurora](RDS-Seguridad.md), [RDS Proxy](RDS-Proxy.md), [Acceso y securización de DynamoDB](DynamoDB-05.md), [Supervisión en la creación](Crear-RDS-04.md) |
| **d)** Cambios del ciclo de vida: tamaño, capacidad de cómputo o configuración | Modificación de instancias, grupos de parámetros, detener e iniciar, cambios en Aurora y DynamoDB | [Ciclo de vida](BD-CicloVida.md) |
| **e)** Replicación y copias de seguridad recuperables en tiempo y forma | Copias automáticas, instantáneas, restauración a un momento dado, PITR de DynamoDB, RPO y RTO | [Copias de seguridad en la creación](Crear-RDS-04.md), [Ciclo de vida](BD-CicloVida.md), [Replicación y recuperación ante desastres](BD-Replicacion.md) |
| **f)** Monitorización del rendimiento de inserciones, actualizaciones y consultas | CloudWatch, Database Insights, registro de consultas lentas, `EXPLAIN`, alarmas, métricas de DynamoDB | [Monitorización del rendimiento](BD-Rendimiento.md) |
| **g)** Optimizaciones no complejas de configuración, esquema o distribución de los datos | Clase de instancia, índices, réplicas de lectura, diseño de claves e índices secundarios de DynamoDB, modo de capacidad | [Monitorización del rendimiento y optimización](BD-Rendimiento.md#3-optimizaciones-no-complejas), [Clave primaria y tipos de atributos](DynamoDB-04.md), [Características y arquitectura de DynamoDB](DynamoDB-02.md#particionado-y-distribucion-de-los-datos) |

---

## Material audiovisual

Los apartados siguen el mismo orden que las sesiones grabadas:

| Sesión | Apartados relacionados |
| --- | --- |
| Visión general de Amazon RDS | [Visión general de Amazon RDS](RDS-Introduccion.md) |
| Amazon Aurora | Bloque **Amazon Aurora** |

!!! info "Núcleo y contenido opcional"
    Las secciones del menú forman el **núcleo** de la unidad: lo que piden los criterios de evaluación y usan las prácticas. Algunas páginas terminan con un apartado **Para saber más**, con bloques plegables que amplían ese mismo tema. La sección **Ampliación (opcional)** del menú reúne temas independientes (opciones de despliegue de Aurora y la referencia de métricas de RDS). Ninguno de estos contenidos es necesario para las prácticas.

!!! tip "Consola AWS y AWS CLI"
    Las operaciones sobre los recursos de AWS se muestran en dos pestañas: **Consola AWS**, con los pasos en la consola web, y **AWS CLI**, con los comandos equivalentes. Al elegir una pestaña, todas las del sitio cambian a la misma opción. Los nombres de menús y botones corresponden a la consola en **español** (entre paréntesis se indica a veces el nombre en inglés) y pueden variar ligeramente cuando AWS actualiza la interfaz.

    Los comandos que se ejecutan **en la instancia o en el cliente de base de datos** (`mysql`, `psql`, sentencias SQL, scripts…) no tienen equivalente en la consola y se muestran sin pestañas. La [chuleta de comandos](Chuleta.md) reúne únicamente la versión de línea de comandos.

!!! note "Región de los ejemplos"
    Los diagramas y algunos ejemplos utilizan la región de **España** (`eu-south-2`) y otras regiones europeas para ilustrar la elección de región, la residencia de los datos y la recuperación ante desastres. Los comandos de los laboratorios utilizan **`us-east-1`**, la región del AWS Academy Learner Lab.
