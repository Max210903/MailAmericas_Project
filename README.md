# mailamericas_project

Proyecto de datos con tres piezas independientes:

- **`apache_airflow/`**: ambiente local de Apache Airflow 2.10.5 (CeleryExecutor, PostgreSQL y Redis) sobre Docker Compose y WSL. Se maneja con `apache_airflow/airflow.sh`.
- **`postgres/`**: base de datos PostgreSQL 16 del proyecto, con su propio Docker Compose. Se maneja con `postgres/postgres.sh`.
- **`dbt/`**: proyecto dbt que transforma los datos de esa base. Airflow lo ejecuta desde un DAG.

## Requisitos

- WSL2 con Docker Desktop y la integración con WSL activada
- Al menos 4 GB de memoria asignados a Docker

## Inicio rápido

```bash
./postgres/postgres.sh start        # base de datos del proyecto
./apache_airflow/airflow.sh init    # Airflow
```

Al terminar, la interfaz de Airflow queda en http://localhost:8080 (usuario `airflow`, clave `airflow`) y la base de datos en `localhost:5432`.

## Uso de `airflow.sh`

```bash
./apache_airflow/airflow.sh <comando> [-y]
```

El script se puede ejecutar desde cualquier carpeta; siempre trabaja sobre `apache_airflow/`.

| Comando | Qué hace | ¿Borra datos? |
|---|---|---|
| `init` | Construye la imagen, migra la base de datos, crea el usuario admin y levanta los servicios | No |
| `start` | Levanta los servicios de un ambiente ya inicializado | No |
| `stop` | Detiene los servicios | No |
| `restart` | Baja y vuelve a levantar los servicios, conservando la base de datos | No |
| `status` | Muestra el estado de los contenedores | No |
| `logs [servicio]` | Sigue los logs de todos los servicios o de uno solo | No |
| `destroy` | Elimina contenedores, la base de datos, la imagen y el contenido de `logs/` | Sí |
| `reset` | Ejecuta `destroy` y luego `init`: ambiente nuevo desde cero | Sí |

`destroy` y `reset` piden confirmación. Con `-y` se omite:

```bash
./apache_airflow/airflow.sh reset -y
```

Ninguno de los dos toca `dags/`, `plugins/` ni `config/`. Lo que sí se pierde es todo lo guardado en la base de datos de Airflow: historial de ejecuciones, conexiones, variables y usuarios.

### Casos comunes

```bash
# Primera vez, o después de un destroy
./apache_airflow/airflow.sh init

# Apagar al terminar el día y volver a encender
./apache_airflow/airflow.sh stop
./apache_airflow/airflow.sh start

# Agregaste una librería a requirements-airflow.txt o requirements-dbt.txt
./apache_airflow/airflow.sh init

# Algo quedó colgado
./apache_airflow/airflow.sh restart

# Ver por qué falla un servicio
./apache_airflow/airflow.sh logs airflow-scheduler

# Empezar de cero
./apache_airflow/airflow.sh reset
```

Los servicios disponibles para `logs` son `airflow-webserver`, `airflow-scheduler`, `airflow-worker`, `airflow-triggerer`, `postgres` y `redis`.

## Base de datos del proyecto

Vive en `postgres/` y no depende de Airflow: tiene su propio proyecto de Docker Compose (`mailamericas-postgres`), su contenedor y su volumen. `airflow.sh destroy` y `reset` no la tocan.

```bash
./postgres/postgres.sh <comando>
```

| Comando | Qué hace |
|---|---|
| `start` | Levanta la base de datos y espera a que esté lista |
| `stop` | Apaga la base de datos sin borrar los datos |
| `restart` | Reinicia la base de datos conservando los datos |
| `status` | Muestra el estado del contenedor |

Ningún comando del script borra datos. Para eliminar la base por completo, incluido su volumen:

```bash
docker compose -f postgres/docker-compose.postgres.yaml down -v
```

| | Desde tu máquina (DBeaver, psql, dbt) | Desde los contenedores de Airflow |
|---|---|---|
| Host | `localhost` | `host.docker.internal` |
| Puerto | `5432` | `5432` |
| Base de datos | `mailamericas` | `mailamericas` |
| Usuario / clave | `mailamericas` / `mailamericas` | `mailamericas` / `mailamericas` |

## dbt

El proyecto dbt está en `dbt/`. Los modelos se crean en el esquema `analytics` de la base de datos del proyecto.

Cómo se integra con Airflow:

- La imagen de Airflow incluye dbt en un entorno virtual propio (`/opt/airflow/dbt_venv`), con las versiones de `apache_airflow/requirements-dbt.txt`.
- La carpeta `dbt/` se monta en los contenedores en `/opt/airflow/dbt`; los cambios en los modelos se ven sin reconstruir la imagen.
- `dbt/profiles.yml` lee la conexión de las variables de entorno `DBT_*`, que define el compose de Airflow.
- El DAG `transformaciones_dbt` (`apache_airflow/dags/transformaciones_dbt.py`) ejecuta `dbt run` y luego `dbt test` con `BashOperator`. No tiene horario: se lanza a mano desde la interfaz.

La base de datos tiene que estar levantada antes de ejecutar el DAG.

Para ejecutar dbt a mano dentro de Airflow:

```bash
docker exec docker_configuration-airflow-worker-1 /opt/airflow/dbt_venv/bin/dbt run \
  --project-dir /opt/airflow/dbt --profiles-dir /opt/airflow/dbt
```

Para ejecutarlo desde tu máquina, instala `dbt-core` y `dbt-postgres` en tu entorno virtual y corre `dbt run --profiles-dir .` dentro de `dbt/`; `profiles.yml` usa `localhost` por defecto.

`dbt/models/ejemplo/` es un modelo de prueba; bórralo cuando tengas modelos propios.

## Estructura

```
.
├── README.md
├── apache_airflow/
│   ├── airflow.sh                      # Gestión del ambiente de Airflow
│   ├── requirements-airflow.txt        # Librerías de Python que se instalan en la imagen
│   ├── requirements-dbt.txt            # dbt y su adaptador (entorno virtual aparte en la imagen)
│   ├── dags/                           # DAGs (se montan en los contenedores)
│   ├── plugins/                        # Plugins de Airflow
│   ├── config/                         # Configuración adicional de Airflow
│   ├── logs/                           # Logs generados por Airflow (fuera de git)
│   └── docker_configuration/
│       ├── Dockerfile.airflow          # Imagen: apache/airflow:2.10.5-python3.12 + requirements + dbt
│       ├── docker-compose.airflow.yaml # Definición de los servicios de Airflow
│       └── .env                        # AIRFLOW_UID y AIRFLOW_PROJ_DIR (fuera de git)
├── postgres/
│   ├── postgres.sh                     # Gestión de la base de datos
│   └── docker-compose.postgres.yaml    # Base de datos del proyecto
└── dbt/
    ├── dbt_project.yml                 # Configuración del proyecto dbt
    ├── profiles.yml                    # Conexión a la base de datos (por variables de entorno)
    └── models/                         # Modelos SQL
```

## Notas

- Los DAGs de ejemplo están desactivados (`AIRFLOW__CORE__LOAD_EXAMPLES: 'false'`); solo aparecen los que pongas en `apache_airflow/dags/`.
- Un archivo nuevo en `apache_airflow/dags/` puede tardar hasta unos minutos en aparecer en la interfaz; no hace falta reiniciar.
- `apache_airflow/docker_configuration/.env` no se versiona. Si falta, `airflow.sh` lo crea con tu UID.
- La configuración es para desarrollo local, no para producción.
