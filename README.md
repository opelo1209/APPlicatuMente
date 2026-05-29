# Front APTM

Frontend Flutter web de Aplicate Por Tu Mente.

## Ejecutar con Docker

No necesitas tener Flutter instalado en la computadora o servidor. Docker usa la
imagen `ghcr.io/cirruslabs/flutter:stable` para descargar dependencias y compilar
el build web dentro del contenedor.

Desde la carpeta `aplicate_por_tu_mente`:

```bash
docker compose up --build frontend
```

La app queda disponible en `http://localhost:8080`.

Puedes cambiar la URL del backend al compilar:

```bash
API_BASE_URL=http://localhost:8001 docker compose up --build frontend
```

## Ejecutar en local

Si tienes Flutter instalado, este script solo instala dependencias y ejecuta el
comando pedido. Si no tienes Flutter, usa Docker para `build` o `pub-get`.

```bash
./scripts/flutter_web.sh pub-get
./scripts/flutter_web.sh build
./scripts/flutter_web.sh run
```
