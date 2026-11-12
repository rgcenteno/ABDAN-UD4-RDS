# Chuleta de comandos

Recopilación de los comandos más habituales de la unidad, como orientación para los laboratorios. Los valores entre `< >` deben sustituirse por los propios. Todos los comandos de la AWS CLI se ejecutan en la región configurada (`aws configure set region us-east-1`).

!!! tip "Antes de empezar"
    - `aws sts get-caller-identity` indica con qué identidad se está trabajando.
    - Añadir `--query` (sintaxis JMESPath) y `--output table` hace la salida mucho más legible.
    - Con `aws <servicio> <comando> help` se consulta la ayuda de cualquier comando.

---

## Red para la base de datos

```bash
# Subredes privadas en dos zonas de disponibilidad
aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.0.3.0/24 --availability-zone us-east-1a
aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.0.4.0/24 --availability-zone us-east-1b

# Grupo de subredes de base de datos
aws rds create-db-subnet-group --db-subnet-group-name tienda-subredes \
  --db-subnet-group-description "Subredes privadas BD" \
  --subnet-ids <subnet-a> <subnet-b>

# Grupo de seguridad que solo admite MySQL desde el grupo de los servidores web
aws ec2 create-security-group --group-name rds-mysql-sg \
  --description "MySQL desde servidores web" --vpc-id <vpc-id>
aws ec2 authorize-security-group-ingress --group-id <sg-bd> \
  --protocol tcp --port 3306 --source-group <sg-web>
```

---

## Amazon RDS

### Crear, consultar y esperar

```bash
aws rds create-db-instance \
  --db-instance-identifier mydb-server \
  --engine mysql --db-instance-class db.t3.micro \
  --allocated-storage 20 --max-allocated-storage 100 --storage-type gp3 \
  --storage-encrypted \
  --master-username admin --manage-master-user-password \
  --db-subnet-group-name tienda-subredes \
  --vpc-security-group-ids <sg-bd> \
  --no-publicly-accessible \
  --backup-retention-period 7

aws rds wait db-instance-available --db-instance-identifier mydb-server

aws rds describe-db-instances --db-instance-identifier mydb-server \
  --query "DBInstances[0].[DBInstanceStatus,Endpoint.Address,DBInstanceClass,MultiAZ,StorageEncrypted]" \
  --output table

# Versiones de motor disponibles
aws rds describe-db-engine-versions --engine mysql \
  --query "DBEngineVersions[].EngineVersion" --output text
```

### Contraseña del usuario maestro en Secrets Manager

```bash
SECRETO=$(aws rds describe-db-instances --db-instance-identifier mydb-server \
  --query "DBInstances[0].MasterUserSecret.SecretArn" --output text)
aws secretsmanager get-secret-value --secret-id "$SECRETO" \
  --query SecretString --output text
```

### Modificar, reiniciar, detener

```bash
# Cambiar la clase (con interrupción) de inmediato
aws rds modify-db-instance --db-instance-identifier mydb-server \
  --db-instance-class db.t3.small --apply-immediately

# Ver cambios pendientes
aws rds describe-db-instances --db-instance-identifier mydb-server \
  --query "DBInstances[0].PendingModifiedValues"

# Activar Multi-AZ y la protección contra eliminación
aws rds modify-db-instance --db-instance-identifier mydb-server \
  --multi-az --deletion-protection --apply-immediately

aws rds reboot-db-instance --db-instance-identifier mydb-server
aws rds stop-db-instance  --db-instance-identifier mydb-server   # se reinicia sola a los 7 días
aws rds start-db-instance --db-instance-identifier mydb-server

# Eventos recientes (útil para diagnosticar)
aws rds describe-events --source-identifier mydb-server \
  --source-type db-instance --duration 60
```

### Grupos de parámetros

```bash
aws rds create-db-parameter-group --db-parameter-group-name tienda-mysql84 \
  --db-parameter-group-family mysql8.4 --description "Parametros de la tienda"

aws rds modify-db-parameter-group --db-parameter-group-name tienda-mysql84 \
  --parameters "ParameterName=require_secure_transport,ParameterValue=ON,ApplyMethod=immediate" \
               "ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate"

aws rds modify-db-instance --db-instance-identifier mydb-server \
  --db-parameter-group-name tienda-mysql84 --apply-immediately
```

### Copias de seguridad y restauración

```bash
aws rds create-db-snapshot --db-instance-identifier mydb-server \
  --db-snapshot-identifier tienda-antes-cambio

aws rds describe-db-snapshots --db-instance-identifier mydb-server \
  --query "DBSnapshots[].[DBSnapshotIdentifier,SnapshotCreateTime,Status]" --output table

# Último instante restaurable
aws rds describe-db-instances --db-instance-identifier mydb-server \
  --query "DBInstances[0].LatestRestorableTime"

# Restaurar a un momento dado (crea una instancia NUEVA)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier mydb-server \
  --target-db-instance-identifier mydb-restaurada \
  --restore-time 2026-11-10T09:45:00Z \
  --db-subnet-group-name tienda-subredes --vpc-security-group-ids <sg-bd>

# Restaurar desde una instantánea
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier mydb-desde-snap \
  --db-snapshot-identifier tienda-antes-cambio \
  --db-subnet-group-name tienda-subredes --vpc-security-group-ids <sg-bd>

# Copiar una instantánea a otra región
aws rds copy-db-snapshot --region us-west-2 --source-region us-east-1 \
  --source-db-snapshot-identifier arn:aws:rds:us-east-1:<cuenta>:snapshot:tienda-antes-cambio \
  --target-db-snapshot-identifier tienda-copia-oeste --kms-key-id <clave-en-us-west-2>
```

### Eliminar

```bash
aws rds modify-db-instance --db-instance-identifier mydb-server \
  --no-deletion-protection --apply-immediately
aws rds delete-db-instance --db-instance-identifier mydb-server \
  --final-db-snapshot-identifier tienda-final          # o --skip-final-snapshot en laboratorios
```

### Registros

```bash
aws rds describe-db-log-files --db-instance-identifier mydb-server --output table
aws rds download-db-log-file-portion --db-instance-identifier mydb-server \
  --log-file-name slowquery/mysql-slowquery.log --output text
```

---

## Amazon Aurora

```bash
# Clúster (almacenamiento) + instancia de escritura
aws rds create-db-cluster --db-cluster-identifier mydb-aurora \
  --engine aurora-mysql --master-username admin --manage-master-user-password \
  --db-subnet-group-name tienda-subredes --vpc-security-group-ids <sg-bd> \
  --storage-encrypted

aws rds create-db-instance --db-instance-identifier mydb-aurora-1 \
  --db-cluster-identifier mydb-aurora --engine aurora-mysql \
  --db-instance-class db.t4g.medium

# Añadir una réplica
aws rds create-db-instance --db-instance-identifier mydb-aurora-2 \
  --db-cluster-identifier mydb-aurora --engine aurora-mysql \
  --db-instance-class db.t4g.medium

# Puntos de enlace de escritura y lectura
aws rds describe-db-clusters --db-cluster-identifier mydb-aurora \
  --query "DBClusters[0].[Endpoint,ReaderEndpoint]" --output table

# Forzar una conmutación por error (pruebas)
aws rds failover-db-cluster --db-cluster-identifier mydb-aurora
```

---

## RDS Proxy

```bash
aws rds create-db-proxy --db-proxy-name tienda-proxy --engine-family MYSQL \
  --auth '[{"AuthScheme":"SECRETS","SecretArn":"<arn-secreto>","IAMAuth":"DISABLED"}]' \
  --role-arn <arn-rol-proxy> --vpc-subnet-ids <subnet-a> <subnet-b> \
  --vpc-security-group-ids <sg-proxy> --require-tls

aws rds register-db-proxy-targets --db-proxy-name tienda-proxy \
  --db-instance-identifiers mydb-server

aws rds describe-db-proxies --db-proxy-name tienda-proxy \
  --query "DBProxies[0].[Status,Endpoint]" --output table
```

---

## Clientes de base de datos

```bash
# Paquete de certificados de la CA de RDS (para verificar el servidor)
curl -o global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# MySQL / MariaDB con TLS y verificación del servidor
mysql -h <endpoint> -P 3306 -u admin -p \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=global-bundle.pem

# PostgreSQL
psql "host=<endpoint> port=5432 dbname=tienda user=postgres sslmode=verify-full sslrootcert=global-bundle.pem"

# Autenticación IAM: el token sustituye a la contraseña (válido 15 minutos)
TOKEN=$(aws rds generate-db-auth-token --hostname <endpoint> --port 3306 --username app_user)
mysql -h <endpoint> -u app_user --password="$TOKEN" --enable-cleartext-plugin \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=global-bundle.pem

# Volcado y restauración lógica
mysqldump -h <origen> -u admin -p --databases tienda --single-transaction > tienda.sql
mysql -h <endpoint> -u admin -p --ssl-mode=VERIFY_IDENTITY --ssl-ca=global-bundle.pem < tienda.sql
```

!!! note "Clientes antiguos"
    Algunos clientes MySQL antiguos no reconocen `--ssl-mode` y usan `--ssl` o `--ssl-verify-server-cert`, como en la práctica evaluable. `--ssl-mode=REQUIRED` cifra pero **no verifica** el servidor.

### SQL de administración útil

```sql
-- MySQL / MariaDB
SHOW DATABASES;
SHOW PROCESSLIST;                                   -- sesiones activas
SHOW GRANTS FOR 'tienda_user'@'10.0.%';
SHOW VARIABLES LIKE 'require_secure_transport';
SHOW STATUS LIKE 'Ssl_cipher';                      -- ¿mi conexión está cifrada?
EXPLAIN SELECT codigo, nombre, stock FROM producto WHERE stock < 60;

CREATE USER 'tienda_user'@'10.0.%' IDENTIFIED BY '<contraseña>' REQUIRE SSL;
GRANT SELECT, INSERT, UPDATE, DELETE ON tienda.* TO 'tienda_user'@'10.0.%';
```

```sql
-- PostgreSQL
\l                                                  -- bases de datos
\du                                                 -- roles
SELECT pid, usename, state, query FROM pg_stat_activity;
SELECT ssl, version FROM pg_stat_ssl WHERE pid = pg_backend_pid();
EXPLAIN ANALYZE SELECT codigo, nombre, stock FROM producto WHERE stock < 60;
```

---

## Amazon DynamoDB

```bash
# Crear una tabla con clave compuesta en modo bajo demanda
aws dynamodb create-table --table-name Productos \
  --attribute-definitions AttributeName=categoria,AttributeType=S AttributeName=id_producto,AttributeType=S \
  --key-schema AttributeName=categoria,KeyType=HASH AttributeName=id_producto,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
aws dynamodb wait table-exists --table-name Productos

# Operaciones de datos
aws dynamodb put-item --table-name Productos \
  --item '{"categoria":{"S":"Monitores"},"id_producto":{"S":"M-002"},"precio":{"N":"199"}}'
aws dynamodb get-item --table-name Productos \
  --key '{"categoria":{"S":"Monitores"},"id_producto":{"S":"M-002"}}'
aws dynamodb query --table-name Productos \
  --key-condition-expression "categoria = :c" \
  --expression-attribute-values '{":c":{"S":"Monitores"}}'
aws dynamodb scan --table-name Productos --select COUNT

# A través de un punto de enlace de VPC de tipo interfaz
aws dynamodb list-tables --endpoint-url https://<vpce-dns>

# Protección de los datos
aws dynamodb update-continuous-backups --table-name Productos \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
aws dynamodb update-table --table-name Productos --deletion-protection-enabled
aws dynamodb update-time-to-live --table-name sessions \
  --time-to-live-specification "Enabled=true,AttributeName=expires"
aws dynamodb create-backup --table-name Productos --backup-name productos-manual

# Restaurar (crea una tabla NUEVA)
aws dynamodb restore-table-to-point-in-time --source-table-name Productos \
  --target-table-name Productos-restaurada --use-latest-restorable-time

# Política basada en recursos de la tabla
aws dynamodb put-resource-policy \
  --resource-arn arn:aws:dynamodb:us-east-1:<cuenta>:table/Productos \
  --policy file://politica.json
aws dynamodb get-resource-policy \
  --resource-arn arn:aws:dynamodb:us-east-1:<cuenta>:table/Productos

aws dynamodb describe-table --table-name Productos \
  --query "Table.[TableStatus,BillingModeSummary.BillingMode,SSEDescription.SSEType,ItemCount]"
aws dynamodb delete-table --table-name Productos
```

---

## AWS KMS

```bash
aws kms create-key --description "Clave para las bases de datos"
aws kms create-alias --alias-name alias/mi-clave-bd --target-key-id <key-id>
aws kms enable-key-rotation --key-id <key-id>
aws kms list-aliases --query "Aliases[?starts_with(AliasName,'alias/mi-clave')]"
aws kms schedule-key-deletion --key-id <key-id> --pending-window-in-days 7
```

---

## AWS CloudFormation

```bash
aws cloudformation validate-template --template-body file://bd.yaml
aws cloudformation deploy --stack-name mi-pila-bd --template-file bd.yaml \
  --parameter-overrides SubredesBD=<subnet-a>,<subnet-b> GrupoSeguridadBD=<sg-bd>
aws cloudformation describe-stacks --stack-name mi-pila-bd \
  --query "Stacks[0].Outputs" --output table
aws cloudformation describe-stack-events --stack-name mi-pila-bd --max-items 15
aws cloudformation detect-stack-drift --stack-name mi-pila-bd
aws cloudformation delete-stack --stack-name mi-pila-bd
```

---

## Amazon CloudWatch

```bash
# CPU media de la última hora en intervalos de 5 minutos
aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=mydb-server \
  --start-time $(date -u -d '-1 hour' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Average --output table

# Peticiones limitadas en DynamoDB
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB --metric-name ThrottledRequests \
  --dimensions Name=TableName,Value=Productos Name=Operation,Value=PutItem \
  --start-time $(date -u -d '-1 hour' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Sum

# Alarma de espacio libre bajo (menos de 2 GiB)
aws cloudwatch put-metric-alarm --alarm-name mydb-espacio \
  --namespace AWS/RDS --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=mydb-server \
  --statistic Average --period 300 --evaluation-periods 1 \
  --threshold 2147483648 --comparison-operator LessThanThreshold
```

---

## Limpieza al terminar un laboratorio

Orden recomendado para no dejar recursos con coste:

1. Pilas de CloudFormation (`delete-stack`), que eliminan todo lo que crearon.
2. RDS Proxy (`delete-db-proxy`).
3. Instancias y clústeres de RDS y Aurora (desactivar antes la protección contra eliminación).
4. Instantáneas manuales que ya no se necesiten (`delete-db-snapshot`).
5. Tablas de DynamoDB y copias bajo demanda.
6. Puntos de enlace de VPC de tipo interfaz y NAT Gateway.
7. Claves de KMS (`schedule-key-deletion`).

---

## Referencias

- AWS. *AWS CLI Command Reference: rds* — [Comandos de RDS](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/rds/index.html)
- AWS. *AWS CLI Command Reference: dynamodb* — [Comandos de DynamoDB](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/dynamodb/index.html)
- AWS. *AWS CLI Command Reference: kms* — [Comandos de KMS](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/kms/index.html)
- AWS. *AWS CLI Command Reference: cloudformation* — [Comandos de CloudFormation](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/cloudformation/index.html)
- AWS. *Filtering AWS CLI output (--query)* — [Uso de JMESPath](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html)
- AWS. *Using SSL/TLS to encrypt a connection to a DB instance or cluster* — [Certificados de RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html)
