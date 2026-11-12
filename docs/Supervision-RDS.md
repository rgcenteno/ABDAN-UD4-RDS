# Referencia de métricas de RDS

Este anexo recoge las **métricas de Amazon CloudWatch** que publica Amazon RDS y que se consultan en la pestaña **Supervisión** (*Monitoring*) de cada instancia. Para cada métrica se indica qué mide, qué valores pueden considerarse orientativos, qué conviene revisar cuando se desvía y qué consecuencias tiene ignorarla.

Es un documento de **consulta**. El método para analizar un problema de rendimiento (medir, identificar la causa, actuar y verificar), el análisis de las consultas con Database Insights y `EXPLAIN` y la monitorización de DynamoDB se explican en el apartado [Monitorización del rendimiento y optimización](BD-Rendimiento.md).

La revisión periódica de estas métricas permite al administrador:

- Detectar cuellos de botella.
- Identificar recursos infrautilizados o saturados.
- Anticipar la necesidad de escalar.
- Evitar degradaciones del servicio.
- Optimizar los costes.

!!! note "Valores orientativos"
    Los umbrales de este anexo son **orientativos**. Cada sistema debe compararse con su propio comportamiento habitual (su *línea base*): un 60 % de CPU puede ser normal en una instancia y una anomalía en otra.

---

## Resumen

| Categoría | Métricas |
| --- | --- |
| **Rendimiento** | `CPUUtilization`, `ReadIOPS`/`WriteIOPS`, `ReadThroughput`/`WriteThroughput`, `ReadLatency`/`WriteLatency`, `DiskQueueDepth` |
| **Capacidad** | `FreeStorageSpace`, `FreeableMemory`, `SwapUsage`, `DatabaseConnections`, `CPUCreditBalance`, `BurstBalance` |
| **Red** | `NetworkReceiveThroughput`, `NetworkTransmitThroughput` |
| **Disponibilidad y replicación** | `ReplicaLag`, `Deadlocks` |
| **Coste** | `TotalBackupStorageBilled`, infrautilización de CPU y memoria |

---

## Métricas de rendimiento

### Utilización de CPU (`CPUUtilization`)

**Qué mide**: porcentaje de uso de la CPU de la instancia.

| Valor | Estado |
| --- | --- |
| 0–40 % | Normal |
| 40–70 % | Vigilancia |
| 70–85 % | Alto |
| > 85 % sostenido | Crítico |

**Qué revisar**: picos continuos, consultas lentas, procesos de mantenimiento, índices ausentes.

**Consecuencias**: latencias elevadas, consultas más lentas, necesidad de escalar verticalmente e incremento de costes.

### Operaciones de lectura por segundo (`ReadIOPS`)

**Qué mide**: número medio de operaciones de lectura en disco por segundo.

**Valores**: no existe un valor universal; debe ser coherente con la carga. Hay que compararlo con las IOPS que admite el volumen (por ejemplo, el valor base de `gp3` o las IOPS aprovisionadas).

**Qué revisar**: un aumento puede indicar falta de memoria para la caché, recorridos completos de tablas o índices ausentes.

**Consecuencias**: saturación del almacenamiento, aumento de la latencia y mayor coste si se aprovisionan IOPS adicionales.

### Operaciones de escritura por segundo (`WriteIOPS`)

**Qué mide**: número medio de operaciones de escritura en disco por segundo.

**Valores**: deben mantenerse estables para la carga esperada.

**Qué revisar**: procesos por lotes, replicación, aplicaciones que escriben en exceso.

**Consecuencias**: cuellos de botella de disco y aumento del tiempo de respuesta.

### Rendimiento de lectura (`ReadThroughput`)

**Qué mide**: bytes leídos del disco por segundo.

**Valores**: dependen de la aplicación.

**Qué revisar**: si aumenta mucho, consultas pesadas, exportaciones o problemas de indexación.

**Consecuencias**: saturación del almacenamiento y aumento de la latencia.

### Rendimiento de escritura (`WriteThroughput`)

**Qué mide**: bytes escritos en disco por segundo.

**Valores**: deben ser acordes al patrón de uso del negocio.

**Qué revisar**: importaciones masivas, aplicaciones mal diseñadas, registros excesivos.

**Consecuencias**: saturación del volumen y retrasos en la confirmación de transacciones (`COMMIT`).

### Latencia de lectura (`ReadLatency`)

**Qué mide**: tiempo medio que tarda cada operación de lectura en disco.

| Latencia | Estado |
| --- | --- |
| < 10 ms | Excelente |
| 10–20 ms | Buena |
| 20–50 ms | Revisar |
| > 50 ms | Problema |

**Consecuencias**: consultas lentas y retrasos percibidos por los usuarios.

### Latencia de escritura (`WriteLatency`)

**Qué mide**: tiempo medio que tarda cada operación de escritura en disco.

| Latencia | Estado |
| --- | --- |
| < 10 ms | Ideal |
| > 20–30 ms sostenido | Crítico |

**Consecuencias**: lentitud de las transacciones, bloqueos y retrasos en la replicación.

### Profundidad de la cola de disco (`DiskQueueDepth`)

**Qué mide**: número de operaciones de E/S que esperan acceso al disco.

| Valor | Estado |
| --- | --- |
| Cercano a 0 | Ideal |
| > 10 sostenido | Alarma |

**Qué indica**: el almacenamiento no puede seguir el ritmo de la carga.

**Consecuencias**: aumento de la latencia y saturación de las IOPS.

---

## Métricas de capacidad

### Espacio de almacenamiento libre (`FreeStorageSpace`)

**Qué mide**: almacenamiento disponible en la instancia, en bytes.

| Espacio libre | Estado |
| --- | --- |
| > 20 % | Correcto |
| 15 % | Umbral de alarma recomendado |
| < 10 % | Crítico |

**Qué revisar**: crecimiento de las tablas, registros, objetos temporales. Conviene activar el **autoescalado del almacenamiento** (véase [Ciclo de vida](BD-CicloVida.md)).

**Consecuencias**: imposibilidad de seguir almacenando datos, errores de escritura y posible caída del servicio.

### Memoria disponible (`FreeableMemory`)

**Qué mide**: memoria RAM disponible en la instancia.

**Valores**: debe mantenerse siempre con margen; un valor cercano a 0 es crítico.

**Qué revisar**: exceso de conexiones, grandes operaciones de ordenación, cachés mal dimensionadas.

**Consecuencias**: uso intensivo de *swap*, consultas lentas y posibles reinicios.

### Uso de memoria de intercambio (`SwapUsage`)

**Qué mide**: memoria de intercambio (*swap*) utilizada.

**Valores**: idealmente 0; cualquier uso significativo debe revisarse.

**Consecuencias**: caída importante del rendimiento. Es una señal de memoria insuficiente.

### Conexiones a la base de datos (`DatabaseConnections`)

**Qué mide**: número de conexiones de clientes abiertas.

**Valores**: dependen del motor y de la clase de instancia, porque el máximo (`max_connections`) se calcula por defecto en función de la memoria de la clase.

| Uso respecto al máximo | Estado |
| --- | --- |
| < 70 % | Correcto |
| > 80 % | Revisar |

Valores máximos orientativos en RDS for MySQL con la configuración predeterminada:

| Clase | `max_connections` aproximado |
| --- | --- |
| db.t3.micro | ~60 |
| db.t3.small | ~150 |
| db.t3.medium | ~300 |
| db.t3.large | ~600 |
| db.r5.large | ~1 000 |
| db.r5.xlarge | ~2 000 |

**Qué revisar**: aplicaciones que no cierran conexiones, agrupación de conexiones mal configurada, picos de usuarios. **RDS Proxy** es la solución habitual ante muchas conexiones cortas (véase [RDS Proxy](RDS-Proxy.md)).

**Consecuencias**: rechazo de nuevas conexiones, errores de aplicación y saturación de la memoria.

### Créditos de CPU (`CPUCreditBalance`)

*(Solo clases ampliables `db.t3`, `db.t4g`)*

**Qué mide**: créditos acumulados que permiten superar el rendimiento base de la CPU.

**Valores**: un saldo que tiende a 0 indica que la instancia trabaja por encima de su rendimiento base de forma sostenida.

**Consecuencias**: si los créditos se agotan, la CPU queda limitada a su rendimiento base (o se factura el uso adicional en modo ilimitado). Es la métrica a vigilar en las instancias pequeñas de los laboratorios.

### Saldo de ráfaga del almacenamiento (`BurstBalance`)

*(Solo volúmenes `gp2`)*

**Qué mide**: porcentaje de créditos de E/S disponibles para superar el rendimiento base del volumen.

| Valor | Estado |
| --- | --- |
| > 80 % | Excelente |
| 50–80 % | Normal |
| < 20 % | Riesgo |
| 0 % | Crítico |

**Consecuencias**: limitación automática del rendimiento del disco y lecturas y escrituras lentas. Los volúmenes `gp3` no utilizan créditos, por lo que migrar a `gp3` elimina este problema.

---

## Métricas de red

### Tráfico de red recibido (`NetworkReceiveThroughput`)

**Qué mide**: tráfico de red entrante, incluido el de los clientes y el de la replicación.

**Qué revisar**: réplicas, consultas remotas, aplicaciones con mucho tráfico.

**Consecuencias**: posibles cuellos de botella de red.

### Tráfico de red enviado (`NetworkTransmitThroughput`)

**Qué mide**: tráfico de red saliente.

**Qué revisar**: respuestas SQL muy grandes (por ejemplo, `SELECT *` sin paginar) y exportaciones masivas.

**Consecuencias**: saturación de la red y mayor latencia de respuesta.

---

## Métricas de disponibilidad y replicación

### Retraso de réplica (`ReplicaLag`)

*(Solo réplicas de lectura)*

**Qué mide**: retraso, en segundos, entre la instancia principal y la réplica.

| Valor | Estado |
| --- | --- |
| Segundos | Normal |
| Minutos | Alarma |

**Consecuencias**: datos desactualizados en las lecturas, problemas en la recuperación ante desastres y riesgo de inconsistencias.

### Interbloqueos (`Deadlocks`)

**Qué mide**: número de interbloqueos entre transacciones por segundo. Está disponible como métrica de CloudWatch en Aurora MySQL; en RDS for MySQL y MariaDB, los interbloqueos se consultan con `SHOW ENGINE INNODB STATUS` o en Database Insights.

**Valores**: cero o muy pocos.

**Qué revisar**: transacciones largas y accesos concurrentes a las mismas filas en distinto orden.

**Consecuencias**: errores de aplicación y cancelación automática de transacciones.

---

## Métricas de coste

### Almacenamiento de copias de seguridad (`TotalBackupStorageBilled`)

**Qué mide**: almacenamiento de copias de seguridad facturado (copias automáticas e instantáneas manuales que superan el almacenamiento gratuito).

**Qué revisar**: crecimiento continuo, periodos de retención excesivos, instantáneas manuales olvidadas.

**Consecuencias**: coste adicional.

### Infrautilización

Una CPU que se mantiene de forma sostenida por debajo del 10–20 % y una memoria libre abundante indican que la instancia está **sobredimensionada**. Reducir la clase es una de las optimizaciones de coste más sencillas.

---

## Alarmas recomendadas para producción

| Métrica | Condición de alarma |
| --- | --- |
| `CPUUtilization` | > 80 % durante 15 minutos |
| `FreeableMemory` | < 500 MB (o < 10 % de la memoria de la clase en instancias pequeñas) |
| `FreeStorageSpace` | < 15 % del almacenamiento asignado (la métrica se expresa en bytes) |
| `DiskQueueDepth` | > 10 |
| `ReadLatency` | > 20 ms |
| `WriteLatency` | > 20 ms |
| `BurstBalance` | < 20 % (solo `gp2`) |
| `CPUCreditBalance` | próximo a 0 (solo clases `db.t`) |
| `ReplicaLag` | > 60 segundos |
| `DatabaseConnections` | > 80 % de `max_connections` |

La creación de alarmas con la AWS CLI se muestra en [Monitorización del rendimiento y optimización](BD-Rendimiento.md#alarmas) y en la [chuleta de comandos](Chuleta.md#amazon-cloudwatch).

---

## Indicadores de necesidad de escalado

Los indicadores que antes anticipan la necesidad de escalar una instancia RDS son:

- CPU por encima del 80 % de forma sostenida, o créditos de CPU agotados.
- Memoria libre muy baja.
- Uso de *swap* creciente.
- Latencias elevadas.
- Cola de disco alta.
- Almacenamiento libre por debajo del 15 %.

Antes de escalar conviene comprobar, con las herramientas del apartado de rendimiento, que el problema no se resuelve con una optimización más barata, como crear un índice.

---

## Referencias

- AWS. *Amazon CloudWatch metrics for Amazon RDS* — [Métricas de CloudWatch para RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-metrics.html)
- AWS. *Amazon CloudWatch metrics for Amazon Aurora* — [Métricas de CloudWatch para Aurora](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraMonitoring.Metrics.html)
- AWS. *Viewing metrics in the Amazon RDS console* — [Pestaña Supervisión](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Monitoring.html)
- AWS. *Maximum number of database connections* — [`max_connections`](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html#RDS_Limits.MaxConnections)
- AWS. *Burstable performance instances* — [Créditos de CPU](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances.html)
- AWS. *Amazon RDS DB instance storage* — [Tipos de almacenamiento y BurstBalance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html)
