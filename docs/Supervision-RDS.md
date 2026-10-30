# AWS RDS Monitoring: Guía de Métricas para Operaciones

## Introducción

El apartado **Supervisión (Monitoring)** de Amazon RDS permite analizar el estado, rendimiento y consumo de la instancia de base de datos. La mayoría de los problemas de rendimiento, costes o indisponibilidad pueden detectarse revisando periódicamente estas métricas.

**Objetivo del administrador SysOps:**

- Detectar cuellos de botella.
- Identificar recursos infrautilizados o saturados.
- Anticipar escalados.
- Evitar degradaciones de servicio.
- Optimizar costes.

---

# 1. CPU Utilization (%)

## ¿Qué mide?

Porcentaje de uso de CPU de la instancia RDS.

## Valores recomendados

| Valor          | Estado     |
| -------------- | ---------- |
| 0-40%          | Normal     |
| 40-70%         | Vigilancia |
| 70-85%         | Alto       |
| >85% sostenido | Crítico    |

## Qué revisar

- Picos continuos.
- Consultas lentas.
- Procesos de mantenimiento.
- Falta de índices.

## Penalizaciones

* Latencias elevadas.
- Consultas más lentas.

- Puede forzar escalado vertical.

- Incremento de costes.

---

# 2. Database Connections

## ¿Qué mide?

Número de conexiones activas a la base de datos.

## Valores recomendados

Dependen del motor y tamaño de instancia.

Como referencia:

- Menos del 70% del máximo → Correcto.
- Más del 80% → Revisar.

### Valores máximos orientativos:

| Instancia    | Max Connections |
| ------------ | --------------- |
| db.t3.micro  | ~60             |
| db.t3.small  | ~150            |
| db.t3.medium | ~300            |
| db.t3.large  | ~600            |
| db.r5.large  | ~1000           |
| db.r5.xlarge | ~2000           |

## Qué revisar

- Aplicaciones que no cierran conexiones.
- Pooling mal configurado.
- Picos de usuarios.

## Penalizaciones

- Rechazo de nuevas conexiones.

- Errores de aplicación.

- Saturación de memoria.

---

# 3. Freeable Memory

## ¿Qué mide?

Memoria RAM disponible para procesos nuevos.

## Valores recomendados

Debe mantenerse siempre con margen. No debe tener un valor cercano a 0.

## Qué revisar

- Conexiones excesivas.
- Grandes operaciones de ordenación.
- Cachés mal dimensionadas.

## Penalizaciones

- Uso intensivo de swap.

- Consultas lentas.

- Posibles reinicios.

---

# 4. Free Storage Space

## ¿Qué mide?

Almacenamiento disponible en la instancia.

## Valores recomendados

Mantener:

- \> 20% libre.

Alarma recomendada:

- 15% libre.

Crítico:

- <10%.

## Qué revisar

- Crecimiento de tablas.
- Logs.
- Backups temporales.

## Penalizaciones

- Parada del crecimiento de datos.

- Errores de escritura.

- Posible caída del servicio.

---

# 5. Read IOPS

## ¿Qué mide?

Operaciones de lectura por segundo.

## Valores óptimos

No existe un valor universal.

Debe ser coherente con la carga.

## Qué revisar

Picos elevados pueden indicar:

- Falta de caché.
- Escaneos completos de tablas.
- Índices ausentes.

## Penalizaciones

- Saturación del almacenamiento.

- Incremento de latencia.

- Mayor coste en IOPS aprovisionadas.

---

# 6. Write IOPS

## ¿Qué mide?

Operaciones de escritura por segundo.

## Valores óptimos

Deben mantenerse estables para la carga esperada.

## Qué revisar

- Procesos batch.
- Replicaciones.
- Aplicaciones que escriben excesivamente.

## Penalizaciones

- Cuellos de botella de disco.

- Incremento de tiempo de respuesta.

---

# 7. Read Throughput

## ¿Qué mide?

Cantidad de datos leídos por segundo (MB/s).

## Valores óptimos

Dependen totalmente de la aplicación.

## Qué revisar

Si aumenta mucho:

- Consultas pesadas.
- Exportaciones.
- Problemas de índices.

## Penalizaciones

- Saturación de almacenamiento.

- Latencia.

---

# 8. Write Throughput

## ¿Qué mide?

Datos escritos por segundo.

## Valores óptimos

Debe ser acorde al patrón de negocio.

## Qué revisar

- Importaciones masivas.
- Aplicaciones mal diseñadas.
- Logs excesivos.

## Penalizaciones

- Saturación del volumen.

- Retrasos en confirmaciones (commit).

---

# 9. Read Latency

## ¿Qué mide?

Tiempo medio de lectura.

## Valores recomendados

| Latencia | Estado    |
| -------- | --------- |
| <10 ms   | Excelente |
| 10-20 ms | Buena     |
| 20-50 ms | Revisar   |
| >50 ms   | Problema  |

## Penalizaciones

- Consultas lentas.

- Usuarios perciben retrasos.

---

# 10. Write Latency

## ¿Qué mide?

Tiempo medio de escritura.

## Valores recomendados

Ideal:

- Menos de 10 ms.

Crítico:

- Más de 20-30 ms sostenidos.

## Penalizaciones

- Lentitud en transacciones.

- Bloqueos.

- Retrasos en replicación.

---

# 11. Disk Queue Depth

## ¿Qué mide?

Número de operaciones esperando acceso al disco.

## Valores recomendados

Ideal:

- Cercano a 0.

Alarma:

- \>10 sostenido.

## Qué indica

El almacenamiento no puede seguir el ritmo.

## Penalizaciones

- Aumento de latencia.

- Saturación de IOPS.

---

# 12. Network Receive Throughput

## ¿Qué mide?

Tráfico de red recibido.

## Qué revisar

- Réplicas.
- Consultas remotas.
- Aplicaciones con mucho tráfico.

## Penalizaciones

- Posibles cuellos de botella de red.

---

# 13. Network Transmit Throughput

## ¿Qué mide?

Tráfico enviado por la instancia.

## Qué revisar

- Grandes respuestas SQL.
- Exportaciones masivas.

## Penalizaciones

- Saturación de red.

- Mayor latencia de respuesta.

---

# 14. Swap Usage

## ¿Qué mide?

Uso de memoria swap.

## Valores recomendados

Ideal:

- 0 MB.

## Qué revisar

Cualquier uso significativo.

## Penalizaciones

- Caída importante del rendimiento.

- Señal de insuficiencia de RAM.

---

# 15. Burst Balance (%)

(Volúmenes GP2 y algunos GP3)

## ¿Qué mide?

Créditos disponibles de rendimiento.

## Valores recomendados

| Valor  | Estado    |
| ------ | --------- |
| >80%   | Excelente |
| 50-80% | Normal    |
| <20%   | Riesgo    |
| 0%     | Crítico   |

## Penalizaciones

- Limitación automática del rendimiento de disco.

- Lecturas y escrituras lentas.

---

# 16. Replica Lag

(Solo réplicas)

## ¿Qué mide?

Retraso entre principal y réplica.

## Valores recomendados

Ideal:

- Segundos.

Alarma:

- Minutos.

## Penalizaciones

- Datos desactualizados.

- Problemas en DR (Disaster Recovery).

- Riesgo de inconsistencia.

---

# 17. Deadlocks

## ¿Qué mide?

Número de bloqueos mutuos.

## Valores recomendados

- Cero o muy pocos.

## Qué revisar

- Transacciones largas.
- Accesos concurrentes.

## Penalizaciones

- Errores de aplicación.

- Cancelación automática de transacciones.

---

# 18. Backup Storage Used

## ¿Qué mide?

Espacio consumido por backups automáticos.

## Qué revisar

- Crecimiento continuo.
- Retención excesiva.

## Penalizaciones

- Coste adicional.

---

# Alertas recomendadas para producción

| Métrica            | Alarma              |
| ------------------ | ------------------- |
| CPU Utilization    | >80% durante 15 min |
| Freeable Memory    | <500 MB             |
| Free Storage Space | <15%                |
| Disk Queue Depth   | >10                 |
| Read Latency       | >20 ms              |
| Write Latency      | >20 ms              |
| Burst Balance      | <20%                |
| Replica Lag        | >60 segundos        |
| Connections        | >80% del límite     |

---

# Categorización

### Indicadores de rendimiento

- CPU Utilization
- Read/Write IOPS
- Read/Write Throughput
- Read/Write Latency
- Disk Queue Depth

### Indicadores de capacidad

- Free Storage Space
- Freeable Memory
- Connections
- Swap Usage

### Indicadores de costes

- Backup Storage Used
- Burst Balance
- Infrautilización de CPU

### Indicadores de disponibilidad

- Replica Lag
- Deadlocks
- Latency
- Connections

# Indicadores de necesidad de escalado

Estos son los indicadores que más rápidamente anticipan la necesidad de escalar una instancia RDS.

- CPU > 80%

- RAM libre muy baja

- Swap creciendo

- Latencias elevadas

- Queue Depth alta

- Storage < 15%
