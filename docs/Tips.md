# Tips y cosas a tener en cuenta en los laboratorios

## Creación de una instancia RDS

Al crear una instancia de base de datos de Amazon RDS en una VPC, debe disponer de **dos subredes privadas o dos subredes públicas*** para poder formar un **grupo de subredes** de base de datos. Por lo tanto, crea dos subredes privadas y luego un grupo de subredes de base de datos.

```sh
# Creamos la primera subred
aws ec2 create-subnet \
--vpc-id vpc_id \
--cidr-block 10.200.2.0/23 \
--availability-zone us-east-1a

# Creamos la segunda subred en otra zona de disponibilidad
aws ec2 create-subnet \
--vpc-id vpc_id \
--cidr-block 10.200.4.0/23 \
--availability-zone us-east-1b


# Creamos el grupo de subredes
aws rds create-db-subnet-group \
    --db-subnet-group-name "mydb-subnet-group" \
    --db-subnet-group-description "DB subnet group for My RDS" \
    --subnet-ids "subnet-0d8b03f3feef58e88" "subnet-06fb0627646fa4d55" "subnet-00be267229cecc438" \
    --tags "Key=Name,Value=MyDatabaseSubnetGroup"
```

## Crear un security group para la instancia

Con MariaDB y MySQL lo habitual es abrir el puerto 3306 para las peticiones que vengan desde las instancias con un SG que hayamos definido para dichas máquinas.

```sh
# Creamos el grupo de seguridad
aws ec2 create-security-group \
--group-name MySG --description "Security group para base de datos" \
--vpc-id $VPC_ID

# Creamos la regla de entrada
aws ec2 authorize-security-group-ingress \
--group-id $SECURITY_GROUP_ID \
--protocol tcp --port 3306 \
--source-group sg-origen-peticiones
```

## Crear la instancia

Datos a tener en cuenta:

- Identificador de instancia de base de datos: **MyDBInstance**

- Opción de motor: **MariaDB**

- Versión del motor de base de datos: **10.2.11 (opcional)**

- Clase de instancia de base de datos: **db.t3.micro**

- Almacenamiento asignado: **20 GB**

- Zona de disponibilidad: **zona de disponibilidad de MomPopCafeInstance**

- Grupo de subred de bases de datos:**Grupo de subred de MomPopCafeDB**

- Grupo de seguridad de la VPC:**MomPopCafeDatabaseSG**

- Accesibilidad pública: **No**

- Nombre de usuario: **root**

- Contraseña: **Re:Start!9**

```sh
aws rds create-db-instance \
--db-instance-identifier MyDBInstance \
--engine mariadb \
--engine-version 10.6.14 \
--db-instance-class db.t3.micro \
--allocated-storage 20 \
--availability-zone <MomPopCafeInstance Availability Zone> \
--db-subnet-group-name "MomPopCafeDB Subnet Group" \
--vpc-security-group-ids <MomPopCafeDatabaseSG Group ID> \
--no-publicly-accessible \
--master-username root --master-user-password 'Re:Start!9'
```

## Esperar a que la instancia esté lanzada

```sh
aws rds describe-db-instances \
--db-instance-identifier MyDBInstance \
--query "DBInstances[*].[Endpoint.Address,AvailabilityZone,PreferredBackupWindow,BackupRetentionPeriod,DBInstanceStatus]"
```

## Obtener volcado de base de datos origen (opcional)

```sh
mysqldump --user=root --password='Re:Start!9' \
--databases mom_pop_db --add-drop-database > my-backup.sql
```

## Importar contenido en la base de datos (opcional)

```sh
# Para clientes viejos sustituir --ssl-mode=REQUIRED por --ssl
mysql --user=root --password='Re:Start!9' \
--host=<RDS Instance Database Endpoint Address> \
--ssl-mode=REQUIRED
< my-backup.sql
```

## Conectarse

```sh
# Para clientes viejos sustituir --ssl-mode=REQUIRED por --ssl
mysql --user=root --password='Re:Start!9' \
--host=<RDS Instance Database Endpoint Address> \
--ssl-mode=REQUIRED
```
