#!/usr/bin/env bash
# Diagnóstico de un servidor candidato para APTM (Semana 5).
#
# SOLO LEE: no instala, no reinicia y no cambia nada. Tampoco usa sudo con
# contraseña (sudo -n solo pregunta qué se permitiría).
#
# Uso, ya dentro del servidor:
#   bash diagnostico_servidor.sh > diagnostico_$(hostname -s).txt 2>&1
# Desde tu computadora, sin copiar el archivo:
#   ssh -t USUARIO@mathonline.izt.uam.mx 'bash -s' < scripts/diagnostico_servidor.sh > diagnostico.txt
#
# Qué responde: si cabe APTM completo (PostgreSQL + backend + pysentimiento +
# Serena con Qwen 1,5B), si cabría un modelo de 3B, y qué falta pedir al
# administrador del servidor.

export LC_ALL=C  # lscpu y free en inglés: los filtros buscan esos nombres

seccion() { printf '\n===== %s =====\n' "$1"; }
hay() { command -v "$1" >/dev/null 2>&1; }

seccion "SISTEMA"
hostname -f 2>/dev/null || hostname
grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
uname -r
uptime

seccion "PROCESADOR"
lscpu | grep -E '^(Model name|CPU\(s\)|Thread|Core|Socket|Hypervisor)'
# llama.cpp aprovecha AVX2/AVX-512; sin AVX2 el modelo es varias veces más lento.
for f in avx2 avx512f avx512_vnni fma; do
  grep -qw "$f" /proc/cpuinfo && echo "  $f: sí" || echo "  $f: no"
done

seccion "MEMORIA"
free -h
# Límite real si es un contenedor o una VM con cgroups.
cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null

seccion "DISCO"
df -h -x tmpfs -x devtmpfs

seccion "GPU"
if hay nvidia-smi; then nvidia-smi; else echo "nvidia-smi: no está"; fi
lspci 2>/dev/null | grep -iE 'vga|3d|nvidia' || echo "lspci: sin GPU dedicada (o sin lspci)"

seccion "SOFTWARE"
for p in python3 python3.12 python3.11 pip3 psql postgres nginx httpd docker podman git gcc make cmake curl; do
  if hay "$p"; then printf '  %-10s %s\n' "$p" "$("$p" --version 2>&1 | head -1)"; else printf '  %-10s no\n' "$p"; fi
done

seccion "SERVICIOS"
systemctl list-units --type=service --state=running --no-pager 2>/dev/null | grep -iE 'postgres|nginx|httpd|docker|podman|aptm|uvicorn' || echo "  ninguno de los que usa APTM"
ss -ltnp 2>/dev/null | awk 'NR==1 || /:(80|443|5432|8000|8080|55433)\b/'

seccion "PERMISOS"
id
sudo -n -l 2>&1 | head -20
getenforce 2>/dev/null && echo "  (SELinux: si es Enforcing, nginx necesita permisos para hablar con el backend)"
systemctl is-active firewalld 2>/dev/null && firewall-cmd --list-all 2>/dev/null

seccion "SALIDA A INTERNET"
# pip, Hugging Face (pysentimiento y Qwen) y GitHub (actualizador automático).
for u in https://pypi.org https://huggingface.co https://github.com https://api.github.com; do
  code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$u")
  printf '  %-28s %s\n' "$u" "${code:-sin respuesta}"
done

seccion "FIN"
date -Is
