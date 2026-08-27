# Tutorial: Desplegar APTM en Google Cloud Platform (GCP)

> Estado real de referencia (ya desplegado con esta guía):
> - **Proyecto GCP:** `aptm-produccion`
> - **VM:** `aptm-server` (e2-small, 2 vCPU comp., 2 GB RAM) en `northamerica-south1-a` (Querétaro, México)
> - **IP estática:** `34.51.63.92`
> - **Frontend:** https://aptm-uami.duckdns.org
> - **Backend:** https://aptm-api-uami.duckdns.org
> - **Costo aprox.:** ~$13-15 USD/mes si la VM queda encendida 24/7 (ver §8 para apagarla y ahorrar).

Sigue el mismo patrón que el despliegue en GCP del proyecto de tesis (Compute Engine + Docker +
Nginx + Let's Encrypt + DuckDNS), adaptado a una app más ligera (Flutter Web + FastAPI + Postgres).

---

## 0. Arquitectura

```
Internet
   │
   ├── https://aptm-uami.duckdns.org      ─┐
   └── https://aptm-api-uami.duckdns.org  ─┤
                                            ▼
                              VM Compute Engine (aptm-server)
                              ┌──────────────────────────────┐
                              │ nginx (host, puerto 80/443)  │  ← certbot / Let's Encrypt
                              │   ├─ proxy → 127.0.0.1:8080  │  (frontend)
                              │   └─ proxy → 127.0.0.1:8001  │  (backend)
                              │                               │
                              │ docker compose (network_mode: host) │
                              │   ├─ aptm_frontend  (nginx+Flutter Web) :8080
                              │   ├─ aptm_backend   (FastAPI)           :8001
                              │   └─ aptm_postgres  (Postgres 16)       :55432
                              └──────────────────────────────┘
```

**Decisión clave (lección aprendida):** las imágenes Docker se **compilan en tu máquina local**
y se suben a **Artifact Registry**; la VM solo hace `docker pull` + `docker compose up`. Compilar
Flutter Web (`dart2js`) dentro de una VM de 2 GB de RAM la satura (llegamos a colgar SSH por
memoria agotada). Compilar localmente y desplegar imágenes ya construidas es más rápido, más
confiable y es la práctica estándar en CI/CD.

---

## 1. Prerrequisitos

- Cuenta de Google con facturación habilitada (tarjeta registrada; GCP no cobra sin tu
  confirmación explícita, pero la VM y la IP sí generan costo mientras estén activas).
- `gcloud` CLI instalado y autenticado en tu máquina:
  ```bash
  curl https://sdk.cloud.google.com | bash
  exec -l $SHELL
  gcloud init
  gcloud auth login
  ```
- Docker instalado localmente (para compilar y subir las imágenes).
- Una cuenta gratuita en [duckdns.org](https://www.duckdns.org) (login con Google/GitHub).

---

## 2. Crear el proyecto GCP y habilitar servicios

```bash
GC=gcloud   # o la ruta completa a tu binario, p.ej. ~/google-cloud-sdk/bin/gcloud

# Crear proyecto
"$GC" projects create aptm-produccion --name="APTM Produccion"
"$GC" config set project aptm-produccion

# Vincular facturación (obtén tu ACCOUNT_ID con: gcloud billing accounts list)
"$GC" billing projects link aptm-produccion --billing-account=TU_BILLING_ACCOUNT_ID

# Habilitar APIs necesarias
"$GC" services enable compute.googleapis.com artifactregistry.googleapis.com --project=aptm-produccion
```

---

## 3. Red: IP estática y firewall

```bash
REGION=northamerica-south1
ZONE=northamerica-south1-a

# IP pública fija (no cambia si apagas/enciendes la VM)
"$GC" compute addresses create aptm-ip --region=$REGION --project=aptm-produccion
"$GC" compute addresses describe aptm-ip --region=$REGION --project=aptm-produccion --format="value(address)"

# Firewall: solo SSH, HTTP y HTTPS públicos. Los puertos internos (8080/8001/55432)
# de los contenedores NUNCA se abren al público — solo nginx local habla con ellos.
"$GC" compute firewall-rules create aptm-allow-web \
  --project=aptm-produccion \
  --direction=INGRESS --action=ALLOW \
  --rules=tcp:22,tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=aptm-server
```

---

## 4. Crear la VM

```bash
"$GC" compute instances create aptm-server \
  --project=aptm-produccion \
  --zone=$ZONE \
  --machine-type=e2-small \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --boot-disk-type=pd-balanced \
  --tags=aptm-server \
  --address=aptm-ip
```

> **Tamaño de VM:** `e2-small` (2 GB RAM) es suficiente para *correr* los 3 contenedores ya
> compilados. Si más adelante conectas un backend de IA real para el chatbot "Serena" (modelos
> más pesados), sube a `e2-medium` o `e2-standard-2`.

---

## 5. Instalar Docker, Nginx y Certbot en la VM

```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion --command='
set -e
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg nginx certbot python3-certbot-nginx
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $(whoami)
sudo systemctl enable --now docker
'
```

**Swap de seguridad** (2 GB RAM es justo; sin swap, cualquier pico de memoria puede colgar la VM):

```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion --command='
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
'
```

---

## 6. DuckDNS (DNS gratuito) apuntando a la IP estática

1. Entra a https://www.duckdns.org e inicia sesión.
2. Crea dos subdominios, por ejemplo `aptm-uami` y `aptm-api-uami`.
3. Copia tu **token** (aparece arriba de la página) y actualiza los registros con la IP estática
   del paso 3 (¡ojo!: DuckDNS a veces detecta automáticamente tu IP local al visitar la página —
   verifica que quede apuntando a la IP de la VM, no a tu IP de casa):
   ```bash
   TOKEN=tu_token_duckdns
   curl "https://www.duckdns.org/update?domains=aptm-uami,aptm-api-uami&token=${TOKEN}&ip=34.51.63.92"
   ```
4. Verifica la propagación:
   ```bash
   getent hosts aptm-uami.duckdns.org
   getent hosts aptm-api-uami.duckdns.org
   ```

---

## 7. Compilar y subir las imágenes (desde tu máquina, NO en la VM)

```bash
"$GC" auth configure-docker northamerica-south1-docker.pkg.dev --quiet
"$GC" artifacts repositories create aptm-images \
  --repository-format=docker --location=$REGION --project=aptm-produccion

REGISTRY="northamerica-south1-docker.pkg.dev/aptm-produccion/aptm-images"
cd APPlicatuMente

# Frontend: el build-arg API_BASE_URL queda "horneado" dentro del JS compilado.
docker build --build-arg API_BASE_URL=https://aptm-api-uami.duckdns.org \
  -t "$REGISTRY/frontend:latest" .
docker push "$REGISTRY/frontend:latest"

# Backend
cd mock_backend
docker build -t "$REGISTRY/backend:latest" .
docker push "$REGISTRY/backend:latest"
```

> Si cambias el dominio del backend más adelante, **debes reconstruir el frontend** (el
> `API_BASE_URL` se compila dentro del JavaScript, no es una variable de entorno en runtime).

---

## 8. Desplegar en la VM

Copia `docker-compose.prod.yml` (incluido en este repo) y despliega:

```bash
SSH_OPTS="-i ~/.ssh/google_compute_engine -o StrictHostKeyChecking=no"
scp $SSH_OPTS docker-compose.prod.yml purpple-alien@34.51.63.92:~/aptm/

# Autenticar la VM contra Artifact Registry (token de corta duración, ~1h)
TOKEN=$("$GC" auth print-access-token)
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion \
  --command="echo \"$TOKEN\" | docker login -u oauth2accesstoken --password-stdin https://northamerica-south1-docker.pkg.dev"

"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion --command='
cd ~/aptm
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps
'
```

> **Nota sobre el login a Artifact Registry:** el token dura ~1 hora, suficiente para el `pull`
> inicial. Para no repetir esto en cada redeploy, la opción robusta es re-crear la VM con el scope
> `cloud-platform` y otorgar el rol `roles/artifactregistry.reader` a su cuenta de servicio; con
> eso, `gcloud auth configure-docker` funciona de forma permanente sin tokens manuales.

---

## 9. Nginx como reverse proxy + HTTPS con Let's Encrypt

Crea dos server blocks (uno por subdominio) que redirigen a los puertos internos de los
contenedores, y deja que Certbot añada TLS automáticamente:

`/etc/nginx/sites-available/aptm-uami.conf`:
```nginx
server {
    listen 80;
    server_name aptm-uami.duckdns.org;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

`/etc/nginx/sites-available/aptm-api-uami.conf` (igual, pero `proxy_pass http://127.0.0.1:8001;`).

```bash
sudo ln -sf /etc/nginx/sites-available/aptm-uami.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/aptm-api-uami.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Certificados HTTPS + redirect automático HTTP→HTTPS
sudo certbot --nginx -n --agree-tos -m tu_correo@ejemplo.com \
  -d aptm-uami.duckdns.org -d aptm-api-uami.duckdns.org --redirect
```

Certbot instala un **systemd timer** (`certbot.timer`) que renueva los certificados
automáticamente antes de que expiren — no requiere mantenimiento manual.

---

## 10. Verificación

```bash
curl -I https://aptm-uami.duckdns.org/                 # 200 OK, sirve el HTML de Flutter
curl https://aptm-api-uami.duckdns.org/salud            # {"status":"ok"}
curl -I http://aptm-uami.duckdns.org/                   # 301 → https (redirect funcionando)

# Los puertos internos NO deben responder desde fuera:
curl --max-time 5 http://34.51.63.92:8080/              # debe fallar / timeout
```

Abre `https://aptm-uami.duckdns.org` en el navegador y prueba registro + login end-to-end.

---

## 11. Operación día a día

**Ver logs:**
```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion \
  --command='cd ~/aptm && docker compose -f docker-compose.prod.yml logs --tail=50 backend'
```

**Redesplegar tras un cambio de código** (repite pasos 7 y luego):
```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion --command='
cd ~/aptm
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
'
```

**Apagar la VM para ahorrar crédito** (la IP estática se conserva, el disco sigue cobrando ~$1-2/mes):
```bash
"$GC" compute instances stop aptm-server --zone=$ZONE --project=aptm-produccion
# ... y para reactivar:
"$GC" compute instances start aptm-server --zone=$ZONE --project=aptm-produccion
```
Los contenedores tienen `restart: unless-stopped`, así que **vuelven a arrancar solos** cuando la
VM enciende — no hace falta repetir `docker compose up` manualmente.

**Backup de la base de datos:**
```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion \
  --command='docker exec aptm_postgres pg_dump -U postgres aptm_tmp' > backup_$(date +%F).sql
```

---

## 12. Pendientes de seguridad antes de usarlo con datos reales de estudiantes

- **CORS abierto (`allow_origins=["*"]`)** en el backend — restringir a los dominios reales del
  frontend antes de manejar datos sensibles.
- **Contraseña de Postgres por defecto** (`postgres`/`postgres`) — cambiarla; aunque el puerto
  55432 no es público, es buena práctica no dejar credenciales por defecto.
- El backend actual (`mock_backend`) es un **stub de desarrollo**: el chat de "Serena" solo
  responde un mensaje fijo, no hay rate limiting ni verificación real de JWT contra un proveedor
  de identidad. Antes de producción real con usuarios finales, sustituir por el backend
  definitivo del proyecto.
- Considera mover los tokens de DuckDNS y credenciales fuera de este repo si alguna vez se hace
  público.

---

## 13. Costos estimados (northamerica-south1, ago. 2026)

| Recurso | Costo aprox. |
|---|---|
| VM e2-small (24/7) | ~$13-14 USD/mes |
| VM e2-small (detenida) | ~$0 cómputo + ~$1-2 disco |
| IP estática (en uso) | Gratis mientras está asignada a una VM corriendo |
| IP estática (VM detenida) | ~$3-4 USD/mes (GCP cobra por IPs reservadas sin usar) |
| Artifact Registry (2 imágenes ~350MB) | Centavos/mes |
| DuckDNS, Let's Encrypt | Gratis |

> Recomendación: si no necesitas la app corriendo 24/7, apaga la VM cuando no la uses (§11) para
> minimizar el gasto del crédito de prueba.
