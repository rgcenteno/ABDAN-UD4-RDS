# Solución paso a paso (consola AWS)

## Tarea 0. Preparar la red (Sólo si no tienes creado LabVPC)

1. Descarga el fichero [inicializar-entorno.sh](https://rgcenteno.github.io/ABDAN-PracticasUD3/#script-que-crea-vpc-con-subred-publica-y-subred-privada).
2. Inicia el Learner Lab y abre la consola. Comprueba arriba a la derecha que la región es **N. Virginia (us-east-1)**.
3. Abre **CloudShell** (icono `>_` de la barra superior). En *Actions → Upload file* sube `inicializar-entorno.sh`.
4. Ejecuta:

```bash
chmod +x inicializar-entorno.sh
./inicializar-entorno.sh
```

4. Tarda 2-3 minutos porque espera al NAT Gateway. Copia el resumen final a un fichero de notas.
5. En **VPC → Your VPCs** verifica `LabVPC` (10.0.0.0/16). En **Subnets**, `PublicSubnet` y `PrivateSubnet` en la misma AZ. En **Route tables**, la pública tiene `0.0.0.0/0 → igw-…` y la privada `0.0.0.0/0 → nat-…`.

> Nota: el script asigna IP pública automática en `PublicSubnet`. El NAT Gateway no es necesario para esta práctica (el endpoint no lo usa), pero se mantiene porque forma parte del entorno base. Recuerda que tiene coste por hora.

## Tarea 1. Grupos de seguridad

**SG-EC2-Publica**

1. **VPC → Security groups → Create security group**.
2. *Security group name*: `SG-EC2-Publica`. *Description*: `SSH a la EC2 cliente`. *VPC*: `LabVPC`.
3. *Inbound rules → Add rule*: Type **SSH**, Source **My IP**.
4. *Add rule*: Type **SSH**, Source **Custom** y escribe `com.amazonaws.us-east-1.ec2-instance-connect` (es una *prefix list* gestionada por AWS; permite conectarse desde el navegador).
5. *Outbound rules*: deja la regla por defecto (todo el tráfico). **Create security group**.

**SG-Endpoint-DynamoDB**

1. **Create security group**. Nombre `SG-Endpoint-DynamoDB`, descripción `HTTPS desde la EC2 al endpoint`, VPC `LabVPC`.
2. *Inbound rules → Add rule*: Type **HTTPS** (TCP 443), Source **Custom** y selecciona `SG-EC2-Publica` (empieza a escribir `sg-` y elige por nombre).
3. **Create security group**.

Referenciar un grupo de seguridad como origen, en lugar de un CIDR, hace que solo las instancias con ese grupo puedan hablar con el endpoint.

## Tarea 2. Endpoint de DynamoDB en la subred privada

1. **VPC → PrivateLink and Lattice → Endpoints → Create endpoint**.
2. *Name tag*: `vpce-dynamodb-privado`. *Type* (o *Service category*): **AWS services**.
3. En el buscador de servicios escribe `dynamodb`. Aparecen dos filas con el mismo nombre `com.amazonaws.us-east-1.dynamodb`: elige la de **Type = Interface** (la otra es *Gateway*).
4. *VPC*: `LabVPC`.
5. *Additional settings*: deja **desmarcado** *Enable DNS name*. DynamoDB no admite DNS privado en endpoints de interfaz; se accede con el nombre DNS propio del endpoint ([documentación AWS](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/privatelink-interface-endpoints.html)).
6. *Subnets*: marca la AZ donde está la red y elige **PrivateSubnet**. *IP address type*: IPv4.
7. *Security groups*: marca solo `SG-Endpoint-DynamoDB`.
8. *Policy*: **Full access** (la restricción la haremos en la tabla, tarea 6).
9. **Create endpoint** y espera a que el estado pase de *Pending* a **Available** (1-2 minutos).
10. En la pestaña **Details**, anota el *Endpoint ID* (`vpce-0abc…`) y el **primer nombre DNS** (el regional, sin letra de zona), con este formato: `vpce-0abc123def456-xyz789.dynamodb.us-east-1.vpce.amazonaws.com`. Si aparece con `*.` delante, quítalo.
11. En la pestaña **Subnets** verás la ENI y su IP privada, por ejemplo `10.0.2.57`. Esa es la "presencia" de DynamoDB en la subred privada.

## Tarea 3. Tabla DynamoDB

1. Abre **DynamoDB → Tables → Create table**.
2. *Table name*: `Productos`.
3. *Partition key*: `categoria`, tipo **String**.
4. *Sort key*: `id_producto`, tipo **String**.
5. *Table settings*: **Customize settings** → *Read/write capacity settings*: **On-demand**. Deja el resto por defecto.
6. **Create table** y espera al estado **Active**.
7. Ve a **Explore items** → selecciona `Productos` → **Create item**.
8. Pulsa **JSON view** con *View DynamoDB JSON* desactivado, pega el primer elemento y **Create item**. Repite con los otros dos:

```json
{"categoria": "Portatiles", "id_producto": "P-001", "nombre": "Portátil 14\" i5", "precio": 749, "stock": 10}
```

```json
{"categoria": "Portatiles", "id_producto": "P-002", "nombre": "Portátil 16\" i7", "precio": 1099, "stock": 4}
```

```json
{"categoria": "Monitores", "id_producto": "M-001", "nombre": "Monitor 27\" QHD", "precio": 289, "stock": 25}
```

Alternativa sin JSON: en *Form*, rellena las claves y usa **Add new attribute** para `nombre` (String), `precio` (Number) y `stock` (Number).

9. Comprueba en *Explore items* que hay 3 elementos.

## Tarea 4. Instancia cliente

1. **EC2 → Instances → Launch instances**.
2. *Name*: `EC2-Cliente-DynamoDB`. *AMI*: **Amazon Linux 2023**. *Instance type*: `t3.micro`. *Key pair*: `vockey`.
3. *Network settings → Edit*: VPC `LabVPC`, Subnet `PublicSubnet`, *Auto-assign public IP* **Enable**. *Firewall*: **Select existing security group** → `SG-EC2-Publica`.
4. *Advanced details → IAM instance profile*: `LabInstanceProfile`. Sin este rol la EC2 no tiene credenciales para llamar a DynamoDB.
5. **Launch instance** y espera a *Running* con *Status check* 2/2.

> En una cuenta propia (fuera del Learner Lab) habría que crear antes un rol IAM para EC2 con la política `AmazonDynamoDBFullAccess` o, mejor, una política limitada a la tabla `Productos`.

## Tarea 5. Trabajar con DynamoDB a través del endpoint

Todos los comandos de esta tarea se ejecutan **dentro de la EC2** con la AWS CLI v2, que ya viene instalada en Amazon Linux 2023. Las credenciales las proporciona el rol `LabRole` a través de `LabInstanceProfile`, así que no hay que ejecutar `aws configure` con claves.

### 5.0 Conectarse a la EC2

**Opción A, desde el navegador:** selecciona la instancia → **Connect → EC2 Instance Connect → Connect**.

**Opción B, por SSH desde tu equipo:** en el Learner Lab, *AWS Details → Download PEM* descarga `labsuser.pem` (la clave privada de `vockey`). Obtén la IP pública desde CloudShell y conéctate:

```bash
 En CloudShell: IP pública de la instancia por su etiqueta Name
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=EC2-Cliente-DynamoDB" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' --output text
```

```bash
 En tu equipo (Linux, macOS o PowerShell de Windows)
chmod 400 labsuser.pem
ssh -i labsuser.pem ec2-user@<IP_PUBLICA>
```

La regla SSH desde *My IP* de `SG-EC2-Publica` es la que permite esta conexión.

### 5.1 Preparar la CLI y las variables del endpoint

```bash
aws configure set region us-east-1    región por defecto
aws configure set output json         formato de salida por defecto
aws sts get-caller-identity           ¿con qué identidad trabajo?
```

Salida esperada (el ARN debe contener `assumed-role/LabRole`):

```json
{
    "UserId": "AROA...:i-0123456789abcdef0",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/LabRole/i-0123456789abcdef0"
}
```

En lugar de copiar a mano el nombre DNS del endpoint, se puede obtener con la CLI:

```bash
 ID del endpoint a partir de su etiqueta Name
VPCE_ID=$(aws ec2 describe-vpc-endpoints \
  --filters "Name=tag:Name,Values=vpce-dynamodb-privado" \
  --query 'VpcEndpoints[0].VpcEndpointId' --output text)

 Primer nombre DNS = el regional (se quita un posible "*." inicial)
VPCE_DNS=$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $VPCE_ID \
  --query 'VpcEndpoints[0].DnsEntries[0].DnsName' --output text)
VPCE_DNS=${VPCE_DNS#\*.}

EP="https://$VPCE_DNS"
echo $VPCE_ID; echo $EP

 Guardar las variables para próximas sesiones
echo "export VPCE_ID=$VPCE_ID VPCE_DNS=$VPCE_DNS EP=$EP" >> ~/.bashrc
```

Si `describe-vpc-endpoints` devuelve `None` o un error de permisos, asigna las variables a mano con los valores anotados en la tarea 2: `VPCE_DNS="vpce-...dynamodb.us-east-1.vpce.amazonaws.com"`.

### 5.2 Comprobar la resolución DNS y el puerto 443

```bash
getent hosts $VPCE_DNS
```

Salida esperada: una IP de la subred privada, la misma que viste en la pestaña *Subnets* del endpoint.

```text
10.0.2.57       vpce-0abc123def456-xyz789.dynamodb.us-east-1.vpce.amazonaws.com
```

Comprueba además que el grupo de seguridad del endpoint deja pasar HTTPS (sin instalar nada, con la redirección `/dev/tcp` de bash):

```bash
timeout 5 bash -c "</dev/tcp/$VPCE_DNS/443" && echo "Puerto 443 accesible" || echo "Sin conexión: revisa SG-Endpoint-DynamoDB"
```

### 5.3 Listar y describir tablas

El parámetro `--endpoint-url` hace que la CLI envíe la petición al endpoint privado en vez de al endpoint público `dynamodb.us-east-1.amazonaws.com`.

```bash
aws dynamodb list-tables --endpoint-url $EP
```

```json
{
    "TableNames": [
        "Productos"
    ]
}
```

```bash
aws dynamodb describe-table --endpoint-url $EP --table-name Productos \
  --query 'Table.{Estado:TableStatus,Claves:KeySchema,Modo:BillingModeSummary.BillingMode}'
```

Debe mostrar `ACTIVE`, la clave `categoria` como `HASH` (partición), `id_producto` como `RANGE` (ordenación) y el modo `PAY_PER_REQUEST` (bajo demanda). La opción `--query` usa JMESPath para filtrar la respuesta.

### 5.4 Insertar dos productos (`put-item`)

La CLI usa el formato *DynamoDB JSON*: cada valor indica su tipo (`S` = String, `N` = Number). Los números van entre comillas, como texto.

```bash
aws dynamodb put-item --endpoint-url $EP --table-name Productos \
  --item '{
    "categoria":   {"S": "Perifericos"},
    "id_producto": {"S": "PE-001"},
    "nombre":      {"S": "Teclado mecanico"},
    "precio":      {"N": "79.90"},
    "stock":       {"N": "15"}
  }' \
  --condition-expression "attribute_not_exists(id_producto)"

aws dynamodb put-item --endpoint-url $EP --table-name Productos \
  --item '{
    "categoria":   {"S": "Perifericos"},
    "id_producto": {"S": "PE-002"},
    "nombre":      {"S": "Raton inalambrico"},
    "precio":      {"N": "24.50"},
    "stock":       {"N": "40"}
  }' \
  --condition-expression "attribute_not_exists(id_producto)"
```

Si todo va bien, `put-item` no muestra nada. `put-item` sobrescribe un elemento con la misma clave; la condición `attribute_not_exists` lo evita. Si repites el comando, obtendrás `ConditionalCheckFailedException`.

**Alternativa: varios elementos a la vez con `batch-write-item`** (hasta 25 por llamada), leyendo un fichero:

```bash
cat > perifericos.json << 'EOF'
{
  "Productos": [
    {"PutRequest": {"Item": {"categoria": {"S": "Perifericos"}, "id_producto": {"S": "PE-003"}, "nombre": {"S": "Webcam Full HD"}, "precio": {"N": "49.00"}, "stock": {"N": "8"}}}}
  ]
}
EOF

aws dynamodb batch-write-item --endpoint-url $EP --request-items file://perifericos.json
```

Salida esperada: `{"UnprocessedItems": {}}`, es decir, ningún elemento pendiente. (Este elemento extra es opcional; los resultados de abajo suponen que **no** lo has insertado.)

### 5.5 Leer un producto por su clave completa (`get-item`)

`get-item` necesita la clave primaria completa: partición **y** ordenación.

```bash
aws dynamodb get-item --endpoint-url $EP --table-name Productos \
  --key '{"categoria": {"S": "Portatiles"}, "id_producto": {"S": "P-001"}}' \
  --consistent-read
```

```json
{
    "Item": {
        "categoria": {"S": "Portatiles"},
        "id_producto": {"S": "P-001"},
        "nombre": {"S": "Portátil 14\" i5"},
        "precio": {"N": "749"},
        "stock": {"N": "10"}
    }
}
```

`--consistent-read` fuerza una lectura fuertemente consistente (devuelve siempre el último dato escrito). Para traer solo algunos atributos, añade `--projection-expression "nombre, precio"`.

### 5.6 Consultar todos los portátiles (`query`)

`query` lee únicamente los elementos de una partición. La condición sobre la clave usa marcadores (`:c`) cuyos valores se pasan aparte:

```bash
aws dynamodb query --endpoint-url $EP --table-name Productos \
  --key-condition-expression "categoria = :c" \
  --expression-attribute-values '{":c": {"S": "Portatiles"}}' \
  --projection-expression "id_producto, nombre, precio, stock" \
  --output table
```

Devuelve P-001 y P-002, con `Count = 2` y `ScannedCount = 2`: solo se han leído los elementos de esa partición. Variantes útiles:

```bash
 Solo contar
aws dynamodb query --endpoint-url $EP --table-name Productos \
  --key-condition-expression "categoria = :c" \
  --expression-attribute-values '{":c": {"S": "Portatiles"}}' --select COUNT

 Condición sobre la clave de ordenación: periféricos cuyo id empieza por "PE-"
aws dynamodb query --endpoint-url $EP --table-name Productos \
  --key-condition-expression "categoria = :c AND begins_with(id_producto, :p)" \
  --expression-attribute-values '{":c": {"S": "Perifericos"}, ":p": {"S": "PE-"}}'
```

### 5.7 Restar stock solo si hay suficiente (`update-item` condicional)

```bash
aws dynamodb update-item --endpoint-url $EP --table-name Productos \
  --key '{"categoria": {"S": "Portatiles"}, "id_producto": {"S": "P-002"}}' \
  --update-expression "SET stock = stock - :n" \
  --condition-expression "stock >= :n" \
  --expression-attribute-values '{":n": {"N": "2"}}' \
  --return-values UPDATED_NEW
```

| Ejecución | Stock antes | Resultado                                                                            |
| --------- | ----------- | ------------------------------------------------------------------------------------ |
| 1.ª       | 4           | `{"Attributes": {"stock": {"N": "2"}}}`                                              |
| 2.ª       | 2           | `{"Attributes": {"stock": {"N": "0"}}}`                                              |
| 3.ª       | 0           | `ConditionalCheckFailedException`: la condición no se cumple y el elemento no cambia |

- `--update-expression` describe el cambio (`SET`, `REMOVE`, `ADD`).
- `--condition-expression` hace la escritura atómica y condicional: evita vender stock que no existe.
- `--return-values UPDATED_NEW` devuelve solo los atributos modificados, con su nuevo valor.

Para dejar el stock en 4 y que los resultados siguientes coincidan:

```bash
aws dynamodb update-item --endpoint-url $EP --table-name Productos \
  --key '{"categoria": {"S": "Portatiles"}, "id_producto": {"S": "P-002"}}' \
  --update-expression "SET stock = :s" \
  --expression-attribute-values '{":s": {"N": "4"}}'
```

### 5.8 Productos de más de 300 € (`scan` con filtro)

```bash
aws dynamodb scan --endpoint-url $EP --table-name Productos \
  --filter-expression "precio > :p" \
  --expression-attribute-values '{":p": {"N": "300"}}' \
  --projection-expression "categoria, id_producto, nombre, precio" \
  --output table
```

Devuelve P-001 (749) y P-002 (1099). Fíjate en los contadores: `Count = 2` pero `ScannedCount = 5`. El `scan` ha leído (y cobrado) toda la tabla y luego ha descartado lo que no cumple el filtro. Por eso `query` es preferible siempre que se pueda usar.

### 5.9 Borrar un periférico (`delete-item`)

```bash
aws dynamodb delete-item --endpoint-url $EP --table-name Productos \
  --key '{"categoria": {"S": "Perifericos"}, "id_producto": {"S": "PE-002"}}' \
  --return-values ALL_OLD
```

`--return-values ALL_OLD` muestra el elemento tal como era antes de borrarlo. Para verificar el borrado:

```bash
aws dynamodb get-item --endpoint-url $EP --table-name Productos \
  --key '{"categoria": {"S": "Perifericos"}, "id_producto": {"S": "PE-002"}}'
 Sin salida: el elemento ya no existe

aws dynamodb scan --endpoint-url $EP --table-name Productos --select COUNT
 "Count": 4
```

### Atajo opcional

Para no repetir `--endpoint-url` en cada comando, se puede crear un alias. Úsalo solo después de haber entendido los comandos completos:

```bash
alias ddb="aws dynamodb --endpoint-url $EP"
ddb scan --table-name Productos --select COUNT
```

## Tarea 6. Hacer la tabla privada

Hasta ahora, la tabla también se puede usar sin pasar por el endpoint. Compruébalo en la EC2:

```bash
aws dynamodb scan --table-name Productos --select COUNT    sin --endpoint-url: funciona, sale por el Internet Gateway
```

1. Obtén tu ID de cuenta (menú de usuario, arriba a la derecha) y el ID del endpoint (`vpce-…`).
2. **DynamoDB → Tables → Productos → pestaña Permissions → Create table policy** (política basada en recursos).
3. Pega esta política, sustituyendo `CUENTA` y `vpce-XXXXXXXX`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SoloDesdeEndpointPrivado",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "dynamodb:GetItem", "dynamodb:BatchGetItem",
        "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem",
        "dynamodb:BatchWriteItem", "dynamodb:Query", "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-east-1:CUENTA:table/Productos",
        "arn:aws:dynamodb:us-east-1:CUENTA:table/Productos/index/*"
      ],
      "Condition": {
        "StringNotEquals": { "aws:SourceVpce": "vpce-XXXXXXXX" }
      }
    }
  ]
}
```

4. **Create policy**. Solo se deniegan operaciones de datos, no las de administración: así puedes seguir editando o borrando la política desde la consola.
5. Comprobaciones:

```bash
 Con endpoint: funciona
aws dynamodb scan --endpoint-url $EP --table-name Productos --select COUNT

 Sin endpoint: AccessDeniedException ... with an explicit deny in a resource-based policy
aws dynamodb scan --table-name Productos --select COUNT
```

6. En la consola, **Explore items → Productos**: también aparece un error de acceso denegado. La consola llama a DynamoDB desde Internet, no desde tu endpoint.

> Si el Learner Lab no permite crear políticas de recursos, documenta el error obtenido y responde a la pregunta 5 de forma teórica.

## Tarea 7. Preguntas
### Preguntas de reflexión (con solución)

1. **¿Por qué no podemos "meter" la tabla DynamoDB en `PrivateSubnet` como hacemos con una EC2?** DynamoDB es un servicio gestionado y regional: AWS opera los servidores fuera de nuestra VPC. Lo que sí podemos colocar en la subred es un endpoint de interfaz, una ENI con IP privada que da acceso al servicio por la red de AWS.
2. **¿Qué ocurre si quitas la regla HTTPS de `SG-Endpoint-DynamoDB`?** Las llamadas con `--endpoint-url` se quedan esperando hasta agotar el tiempo (*timeout*), porque el grupo de seguridad bloquea el tráfico al puerto 443 de la ENI.
3. **¿Por qué, antes de la tarea 6, funcionaba `aws dynamodb scan` sin `--endpoint-url`?** Sin DNS privado, el nombre `dynamodb.us-east-1.amazonaws.com` resuelve a IPs públicas. La EC2 está en una subred pública y sale por el Internet Gateway. La petición está autenticada (rol `LabRole`), así que DynamoDB la acepta.
4. **Diferencias entre endpoint de tipo Gateway e Interface para DynamoDB.** El *Gateway* es gratuito, se asocia a tablas de rutas (añade una ruta a la *prefix list* de DynamoDB), no tiene IP ni grupo de seguridad y no es accesible desde fuera de la VPC. El de *Interface* crea una ENI con IP privada en la subred, admite grupos de seguridad, se puede usar desde redes locales (VPN o Direct Connect) y tiene coste por hora y por GB.
5. **¿Qué aporta la condición `aws:SourceVpce` en la política de la tabla?** Convierte la ruta de red en un requisito de acceso: aunque alguien tenga credenciales válidas, no puede leer ni escribir datos si la petición no entra por ese endpoint.
6. **¿Por qué la consulta de la tarea 5.5 es `Query` y la de 5.7 es `Scan`? ¿Cuál es más eficiente?** `Query` usa la clave de partición y solo lee esa partición. `Scan` recorre toda la tabla y filtra después, consumiendo más capacidad. Para buscar por precio de forma eficiente habría que crear un índice secundario global (GSI).
7. **¿Es necesario el NAT Gateway para esta práctica?** No. La EC2 está en la subred pública y el endpoint no necesita salida a Internet. El NAT solo serviría a instancias de la subred privada que necesiten Internet.

