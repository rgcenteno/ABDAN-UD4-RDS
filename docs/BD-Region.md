# Región, residencia de los datos y replicación

![image](imgs/BD-replicacion-niveles.png)

Antes de crear una base de datos en la nube hay que decidir **dónde** van a residir los datos. Es una decisión que se toma al principio y que es costosa de cambiar: una instancia RDS o una tabla DynamoDB pertenecen a una región concreta, y trasladarlas a otra exige copiar o replicar los datos. La elección de la región condiciona la **latencia** que perciben los usuarios, el **coste**, los **servicios disponibles** y el **cumplimiento normativo**. A continuación se decide **cuánta redundancia geográfica** se necesita: varias zonas de disponibilidad dentro de una región o varias regiones.

---

## Regiones y zonas de disponibilidad

| Concepto | Descripción | Ejemplo |
| --- | --- | --- |
| **Región** | Área geográfica independiente con varios centros de datos. Los datos **no salen de la región** salvo que el cliente lo configure | `eu-south-2` (España), `eu-west-3` (París), `us-east-1` (Norte de Virginia) |
| **Zona de disponibilidad (AZ)** | Uno o varios centros de datos con alimentación, refrigeración y red independientes, conectados con baja latencia a las demás zonas de la región | `eu-south-2a`, `eu-south-2b`, `eu-south-2c` |
| **Zona local** (*Local Zone*) | Extensión de una región situada cerca de grandes ciudades para cargas de latencia muy baja | — |

España dispone de la región **Europa (España), `eu-south-2`**, situada en Aragón, con tres zonas de disponibilidad. El Learner Lab de AWS Academy, en cambio, limita los recursos a las regiones `us-east-1` y `us-west-2`, por lo que los criterios de este apartado deben entenderse aplicados a un entorno real.

---

## Criterios para elegir la región

| Criterio | Qué valorar |
| --- | --- |
| **Residencia de los datos y normativa** | Requisitos legales o contractuales sobre la ubicación de los datos (ver apartado siguiente). Suele ser el criterio **eliminatorio** |
| **Latencia** | Cercanía a los usuarios y, sobre todo, a los **servidores de aplicación**: la base de datos debe estar en la misma región que la aplicación que la consulta |
| **Disponibilidad de servicios y funcionalidades** | No todas las regiones ofrecen todos los motores, versiones, clases de instancia o funcionalidades (por ejemplo, Aurora DSQL, Limitless o determinadas clases Graviton) |
| **Coste** | Los precios de instancias, almacenamiento y transferencia **varían entre regiones**. La misma instancia puede costar sensiblemente más en una región que en otra |
| **Número de zonas de disponibilidad** | Determina las opciones de alta disponibilidad (los clústeres Multi-AZ de RDS necesitan tres zonas) |
| **Recuperación ante desastres** | Disponer de una segunda región adecuada, cercana pero suficientemente separada, para las copias o réplicas |
| **Sostenibilidad** | AWS publica información sobre el origen de la energía de sus regiones, un criterio cada vez más presente en las organizaciones |

### Medir la latencia

La latencia entre un cliente y una región puede estimarse midiendo el tiempo de conexión con el punto de enlace de un servicio en esa región. Dentro de AWS, como referencia orientativa, la latencia entre zonas de una misma región es del orden de **milisegundos de un solo dígito**, mientras que entre regiones de continentes distintos puede superar los **100 ms**. Por eso, situar la aplicación y la base de datos en regiones distintas penaliza cada consulta.

---

## Residencia de los datos

La **residencia de los datos** (*data residency*) es el requisito de que la información se almacene y procese en una ubicación geográfica concreta. En el contexto europeo y español conviene distinguir:

- **Reglamento General de Protección de Datos (RGPD)**. No obliga a que los datos personales residan en la Unión Europea, pero **regula las transferencias internacionales** fuera del Espacio Económico Europeo, que solo pueden realizarse con garantías adecuadas (decisiones de adecuación, cláusulas contractuales tipo, etc.). Elegir una región de la UE simplifica notablemente el cumplimiento.
- **Esquema Nacional de Seguridad (ENS)**. Obligatorio para el sector público español y sus proveedores; exige que los servicios en la nube estén certificados para el nivel correspondiente.
- **Requisitos sectoriales o contractuales**: banca, sanidad o administraciones pueden exigir que los datos no salgan del país o de la UE.
- **Soberanía digital**: algunas organizaciones exigen, además, que la infraestructura esté **operada** por personal residente en la UE y sometida a la legislación europea. Para estos casos, AWS lanzó en enero de 2026 la **AWS European Sovereign Cloud**, una infraestructura separada del resto de regiones, con su primera región (`eusc-de-east-1`) en Brandeburgo (Alemania).

### Cómo garantizar la residencia en AWS

| Mecanismo | Descripción |
| --- | --- |
| Elegir la región | AWS no traslada los datos de una región a otra por iniciativa propia |
| Revisar las funciones que copian datos | Réplicas entre regiones, tablas globales, copias de instantáneas entre regiones, Global Database o planes de AWS Backup con copia a otra región **sacan los datos de la región**. Deben configurarse solo hacia regiones permitidas |
| Restringir regiones con políticas | Una **SCP** de AWS Organizations con la condición `aws:RequestedRegion` impide crear recursos fuera de las regiones autorizadas |
| Auditar | AWS Config y CloudTrail permiten detectar recursos creados en regiones no autorizadas |

Ejemplo de SCP que limita el uso de RDS y DynamoDB a dos regiones europeas:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SoloRegionesEuropeas",
      "Effect": "Deny",
      "Action": ["rds:*", "dynamodb:*"],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": { "aws:RequestedRegion": ["eu-south-2", "eu-west-3"] }
      }
    }
  ]
}
```

---

## Niveles de replicación

Una vez elegida la región, se decide el nivel de redundancia. Cuanto más amplio es el ámbito, mayor es la protección, pero también la latencia de replicación, la complejidad y el coste.

| Nivel | Protege frente a | RDS | Aurora | DynamoDB |
| --- | --- | --- | --- | --- |
| **Una zona** | Fallo de un disco o un servidor (con recuperación lenta) | Instancia Single-AZ | Clúster con una sola instancia (los datos ya están en 3 AZ) | — |
| **Varias zonas** | Caída de un centro de datos | Instancia Multi-AZ, clúster Multi-AZ | Réplicas de Aurora en otras AZ | **Siempre**: 3 zonas por defecto |
| **Varias regiones (lectura)** | Desastre regional; lecturas cercanas a usuarios lejanos | Réplica de lectura entre regiones | Global Database | — |
| **Varias regiones (escritura)** | Desastre regional sin interrupción de escrituras | — | Aurora DSQL multirregión | Tablas globales |
| **Copias en otra región** | Pérdida de la región o borrado accidental | Copia de instantáneas y de copias automáticas entre regiones | Copia de instantáneas | Copias con AWS Backup entre regiones |

### Replicación síncrona y asíncrona

| | Síncrona | Asíncrona |
| --- | --- | --- |
| Confirmación de la escritura | Cuando la copia remota la ha recibido | Antes de que la copia remota la reciba |
| Pérdida de datos ante un fallo (RPO) | Nula | Los datos aún no replicados (segundos) |
| Impacto en la latencia | Mayor, aumenta con la distancia | Mínimo |
| Uso típico | Entre zonas de una región (Multi-AZ) | Entre regiones (réplicas, Global Database, tablas globales MREC) |

La replicación síncrona entre regiones lejanas penalizaría cada escritura con la latencia de la distancia; por eso la replicación entre regiones suele ser asíncrona, con excepciones diseñadas específicamente para ello, como las tablas globales con consistencia fuerte multirregión o Aurora DSQL.

---

## Consideraciones de coste

- **Multi-AZ** duplica (instancia) o triplica (clúster) el coste de cómputo y almacenamiento, aunque la transferencia de datos de la replicación entre zonas no se factura en RDS.
- La **transferencia de datos entre regiones** se factura por GB, tanto en réplicas como en copias de instantáneas.
- La **transferencia entre zonas de disponibilidad** del tráfico de la aplicación (por ejemplo, un servidor web en `us-east-1a` que consulta una base de datos en `us-east-1b`) también tiene coste.
- En **DynamoDB**, cada réplica de una tabla global factura las escrituras replicadas y su almacenamiento.
- En **Aurora Global Database**, se factura la E/S replicada y la transferencia hacia las regiones secundarias.

Las tablas de precios de cada servicio, y la **Calculadora de precios de AWS**, permiten estimar estos costes antes de decidir.

---

## Guía de decisión

| Requisito | Opción recomendada |
| --- | --- |
| Entorno de desarrollo o pruebas | Una región, una zona (Single-AZ) |
| Producción con alta disponibilidad | Una región, varias zonas (Multi-AZ, Aurora con réplicas o DynamoDB) |
| Recuperación ante desastres con RPO de horas | Copias de instantáneas en otra región |
| Recuperación ante desastres con RPO de segundos | Réplica entre regiones o Aurora Global Database |
| Usuarios en varios continentes con lecturas locales | Aurora Global Database o réplicas entre regiones |
| Escrituras activas en varias regiones | DynamoDB tablas globales o Aurora DSQL |
| Datos personales con requisitos de residencia en la UE | Regiones de la UE y restricción con SCP; AWS European Sovereign Cloud si se exige soberanía |

---

## Referencias

- AWS. *Regions and Availability Zones* — [Infraestructura global de AWS](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/)
- AWS. *AWS Europe (Spain) Region* — [Región de España](https://aws.amazon.com/local/spain/region/)
- AWS. *Choosing the AWS Region for your workload* — [What to consider when selecting a Region for your workloads](https://aws.amazon.com/blogs/architecture/what-to-consider-when-selecting-a-region-for-your-workloads/)
- AWS News Blog. *Opening the AWS European Sovereign Cloud* (14/01/2026) — [Anuncio](https://aws.amazon.com/blogs/aws/opening-the-aws-european-sovereign-cloud)
- AWS. *Data protection and privacy at AWS / GDPR Center* — [Centro RGPD de AWS](https://aws.amazon.com/compliance/gdpr-center/)
- AWS. *Esquema Nacional de Seguridad (ENS)* — [Cumplimiento ENS](https://aws.amazon.com/compliance/esquema-nacional-de-seguridad/)
- AWS. *Example SCPs: deny access to AWS based on the requested AWS Region* — [Restricción de regiones con SCP](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples_general.html)
- AWS. *Working with DB instance read replicas: cross-Region* — [Réplicas entre regiones](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.XRgn.html)
- AWS. *Copying a DB snapshot* — [Copia de instantáneas entre regiones](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CopySnapshot.html)
- AWS. *Amazon RDS pricing* — [Precios de RDS](https://aws.amazon.com/rds/pricing/)
- AWS. *AWS Pricing Calculator* — [Calculadora de precios](https://calculator.aws/)
