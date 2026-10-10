# mailamericas_project

Ambiente local de Apache Airflow 2.10.5 (CeleryExecutor, PostgreSQL y Redis) sobre Docker Compose y WSL. Todo lo relacionado con Airflow vive en `apache_airflow/` y el ciclo de vida del ambiente se maneja con `apache_airflow/airflow.sh`.

## Requisitos

- WSL2 con Docker Desktop y la integración con WSL activada
- Al menos 4 GB de memoria asignados a Docker

## Inicio rápido

```bash
./apache_airflow/airflow.sh init
```

Al terminar, la interfaz queda en http://localhost:8080 (usuario `airflow`, clave `airflow`).

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

# Agregaste una librería a apache_airflow/requirements-airflow.txt
./apache_airflow/airflow.sh init

# Algo quedó colgado
./apache_airflow/airflow.sh restart

# Ver por qué falla un servicio
./apache_airflow/airflow.sh logs airflow-scheduler

# Empezar de cero
./apache_airflow/airflow.sh reset
```

Los servicios disponibles para `logs` son `airflow-webserver`, `airflow-scheduler`, `airflow-worker`, `airflow-triggerer`, `postgres` y `redis`.

## Estructura

```
.
├── README.md
└── apache_airflow/
    ├── airflow.sh                      # Gestión del ambiente
    ├── requirements-airflow.txt        # Librerías de Python que se instalan en la imagen
    ├── dags/                           # DAGs (se montan en los contenedores)
    ├── plugins/                        # Plugins de Airflow
    ├── config/                         # Configuración adicional de Airflow
    ├── logs/                           # Logs generados por Airflow (fuera de git)
    └── docker_configuration/
        ├── Dockerfile.airflow          # Imagen: apache/airflow:2.10.5-python3.12 + requirements
        ├── docker-compose.airflow.yaml # Definición de los servicios
        └── .env                        # AIRFLOW_UID y AIRFLOW_PROJ_DIR (fuera de git)
```

## Notas

- Los DAGs de ejemplo están desactivados (`AIRFLOW__CORE__LOAD_EXAMPLES: 'false'`); solo aparecen los que pongas en `apache_airflow/dags/`.
- Un archivo nuevo en `apache_airflow/dags/` puede tardar hasta unos minutos en aparecer en la interfaz; no hace falta reiniciar.
- `apache_airflow/docker_configuration/.env` no se versiona. Si falta, `airflow.sh` lo crea con tu UID.
- La configuración es para desarrollo local, no para producción.
