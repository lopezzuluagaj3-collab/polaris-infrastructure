# POLARIS Logistics — Infraestructura como Código (IaC + CaC)

> **Repositorio 1 de 3** — Aprovisionamiento de infraestructura en AWS y arranque del clúster Kubernetes para la plataforma ETL de POLARIS Logistics.

[Visión general](#visión-general) • [Arquitectura](#arquitectura) • [Requisitos previos](#requisitos-previos) • [Configuración](#configuración) • [Despliegue paso a paso](#despliegue-paso-a-paso) • [Verificación](#verificación) • [CI/CD](#cicd) • [Estructura del proyecto](#estructura-del-proyecto) • [Troubleshooting](#troubleshooting--lecciones-aprendidas) • [Seguridad](#seguridad)

---

## Visión general

**POLARIS Logistics** es un proyecto de portafolio que demuestra una pipeline DevOps y Data Engineering empresarial completa. Este repositorio — la capa de **Infraestructura** — aprovisiona todos los recursos de AWS usando **Terraform** (IaC) y arranca un clúster **K3s Kubernetes** autoadministrado usando **Ansible** (CaC), incluyendo el registro automatizado de un GitHub Actions self-hosted runner y de un Deploy Key SSH para clonar el repo de la plataforma.

La plataforma procesa el dataset de Olist Brazilian E-Commerce diariamente mediante una pipeline ETL de Airflow + RabbitMQ + Celery, cargando los datos limpios en PostgreSQL sobre Kubernetes para su consumo en Power BI.

| Área | Herramienta |
|---|---|
| Cloud | AWS (us-east-1) |
| IaC | Terraform >= 1.5 |
| CaC | Ansible |
| Contenedores | Docker |
| Orquestación | K3s (Kubernetes ligero) |
| CNI | Cilium (eBPF) |
| Ingress | NGINX Ingress |
| CI/CD self-hosted | GitHub Actions Runner (automatizado vía Ansible) |
| Calidad | TFLint, Checkov, Infracost, SonarCloud |
| CI/CD (infra) | GitHub Actions + OIDC |

---

## Arquitectura

```
                            Internet
                                │
                      ┌───────────┴───────────┐
                      │   Internet Gateway    │
                      └───────────┬───────────┘
                                  │
                      ┌───────────┴───────────┐
                      │   Subnet Pública      │  12.0.1.0/24
                      │ (Route Table: 0.0.0.0/0 → IGW)
                      │
              ┌───────┴───────┐
              │   EC2-1       │  svr-proxy  (Bastión + NGINX Ingress + EIP)
              │ c7i-flex.large│  SG: sg_proxy
              └───────┬───────┘
                      │
              ┌───────┴───────┐
              │  NAT Gateway   │  (EIP para salida de subnet privada)
              └───────┬───────┘
                      │
                      └───────────┬───────────┐
                                  │
                      ┌───────────┴───────────┐
                      │    Subnet Privada     │  12.0.2.0/24
                      │ (Route Table: 0.0.0.0/0 → NAT GW)
                      │
        ┌──────────────┼──────────────┬──────────────┬──────────────┐
        │              │              │              │              │
   ┌────┴────┐   ┌────┴────┐    ┌────┴────┐   ┌────┴────┐    ┌────┴────┐
   │EC2-2    │   │EC2-3    │    │EC2-4a   │   │EC2-4b   │    │EC2-5    │
   │svr-     │   │svr-     │    │svr-     │   │svr-     │    │svr-     │
   │airflow  │   │rabbitmq │    │celery-1 │   │celery-2 │    │db       │
   │(K3s CP) │   │(Worker) │    │(Worker) │   │(Worker) │    │(Worker) │
   └─────────┘   └─────────┘    └─────────┘   └─────────┘    └─────────┘
```

`svr-airflow` (control plane K3s) es además el nodo donde corren el **GitHub Actions Runner** y el clon del repo de la plataforma vía **Deploy Key**, ambos configurados automáticamente por Ansible.

### Inventario de instancias

| Instancia | Host | Función | Subnet | Security Group | Rol K8s |
|---|---|---|---|---|---|
| EC2-1 | `svr-proxy` | Bastión + controlador NGINX Ingress | Pública | `sg_proxy` | — |
| EC2-2 | `svr-airflow` | **Plano de control K3s** + Airflow + GitHub Runner | Privada | `sg_airflow` | Control plane |
| EC2-3 | `svr-rabbitmq` | Broker de mensajería RabbitMQ | Privada | `sg_rabbitMQ` | Worker |
| EC2-4 (×2) | `svr-celery-1`, `svr-celery-2` | Workers Celery | Privada | `sg_celery` | Worker |
| EC2-5 | `svr-db` | Base de datos PostgreSQL | Privada | `sg_db` | Worker |

Todas las instancias utilizan:
- **AMI**: `ami-0b6d9d3d33ba97d99`
- **Tipo de instancia**: `c7i-flex.large`
- **IMDSv2**: forzado (`http_tokens = required`)
- **Volúmenes EBS**: encriptados (gp3), `delete_on_termination = true`

### Topología de red

- **VPC**: `12.0.0.0/16` con DNS hostnames habilitado
- **Subnet pública**: `12.0.1.0/24` — proxy, EIP del NAT, IGW
- **Subnet privada**: `12.0.2.0/24` — nodos K8s, salida vía NAT Gateway
- **EIP**: asignado al NAT Gateway y a la instancia proxy (bastión)

### Estado de Terraform

| Configuración | Valor |
|---|---|
| Bucket | `sirius-terraform-state-022784797877` |
| Key | `airflow/terraform.tfstate` |
| Región | `us-east-1` |
| Encriptación | AES-256 |

---

## Requisitos previos

### Herramientas locales

| Herramienta | Versión | Instalación |
|---|---|---|
| Terraform | >= 1.5.0 | [terraform.io](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) |
| AWS CLI | >= 2.0 | [docs.aws.amazon.com](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install-open.html) |
| Ansible | >= 9.0 | `pip install ansible` |
| Colección `community.crypto` | última | `ansible-galaxy collection install community.crypto` (requerida para generar el Deploy Key SSH) |
| TFLint | >= 0.55.0 | [github.com/terraform-linters/tflint](https://github.com/terraform-linters/tflint) |
| Infracost | última | [infracost.io](https://www.infracost.org/install/) |

### Requisitos en AWS

1. **Cuenta AWS** con permisos para crear VPCs, instancias EC2, roles/políticas IAM, EIPs y buckets S3.
2. **Proveedor OIDC** + **rol IAM** para GitHub Actions (el pipeline de CI/CD de este repo asume este rol vía el secreto `AWS_ROLE_ARN`). Ver sección [CI/CD](#cicd).
3. **Pares de llaves SSH** — dos pares deben existir en la consola de AWS:
   - `proxy_key` — para la instancia bastión (pública)
   - `general_key` — para todas las instancias privadas
4. **Bucket S3 para el backend** ya existe (`sirius-terraform-state-022784797877`). Terraform no lo administra.

### Requisitos en GitHub

1. **Personal Access Token (PAT)** con permiso **Administration: Read and write** sobre el repositorio de la plataforma (`polaris-kubernetes` o el que corresponda). Este permiso es el que habilita:
   - Generar tokens de registro para el self-hosted runner.
   - Registrar el Deploy Key SSH.
2. Repositorio destino con **Actions habilitado**.

> ⚠️ El PAT es un secreto de alto privilegio. Nunca lo pegues en commits, PRs, issues, ni lo compartas en texto plano. Ver [Seguridad](#seguridad).

### Configurar credenciales de AWS (local)

```bash
aws configure
# o usar SSO / perfiles nombrados
```

---

## Configuración

### 1. Variables de Terraform

```bash
cp terraform.tfvars.example terraform.tfvars
```

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `aws_region` | `"us-east-1"` | Región de AWS |
| `allowed_ssh_cidr` | `"0.0.0.0/0"` | CIDR permitido para SSH al proxy — **restringir a tu IP** |

### 2. Variables de entorno (`.env`) — sin Ansible Vault

Este proyecto prioriza **reproducibilidad sin intervención manual**: los secretos que necesita Ansible se inyectan como variables de entorno vía `lookup('env', ...)` en `group_vars/all.yml`, cargadas desde un archivo `.env` local que **nunca se commitea**.

```bash
cp .env.example .env
```

Completa `.env` con:

```bash
# Personal Access Token de GitHub (scope Administration: Read and write sobre el repo destino)
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxx

# IP privada del control plane K3s (svr-airflow) — la asigna Terraform en cada apply,
# se actualiza aquí después de cada rebuild
IP_PANEL=12.0.2.171
```

> **Importante**: guarda `.env` con terminadores de línea **LF** (Unix), no CRLF. Si lo editas desde Windows/VS Code en una carpeta montada de Windows (`/mnt/d/...` en WSL), verifica el formato con `file .env` o normalízalo con `sed -i 's/\r$//' .env` antes de usarlo — CRLF causa errores como `Invalid header value ...\r'` al llamar a la API de GitHub.

Confirma que `.env` esté en `.gitignore`:
```bash
grep -qxF '.env' .gitignore || echo '.env' >> .gitignore
```

### 3. Inventario de Ansible

`inventory.ini` define los grupos de hosts por **alias** (no por IP):

```ini
[bastion]
proxy

[data_pipeline]
svr-airflow
svr-rabbit
svr-celery-1
svr-celery-2

[databases]
svr-db

[all:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-F ./ansible_ssh_config -o StrictHostKeyChecking=no'
ansible_python_interpreter=/usr/bin/python3
```

> No agregues `ansible_host=` a estos hosts — la conexión SSH se resuelve vía `ansible_ssh_config` con `ProxyJump` al bastión. Definir `ansible_host` rompería ese enrutamiento (Ansible conectaría directo a la IP en vez de por el alias).

El archivo `ansible_ssh_config` (gitignored) enruta el SSH a través del bastión y debe regenerarse después de cada `terraform apply`:

```
Host proxy
    HostName <EIP_DEL_PROXY>
    User ubuntu
    IdentityFile ~/.ssh/proxy_key.pem
    ForwardAgent yes

Host svr* proxy
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m

Host svr*
    IdentityFile ~/.ssh/general_key.pem
    User ubuntu

Host svr-airflow
    HostName <IP_PRIVADA_AIRFLOW>
    ProxyJump proxy

Host svr-rabbit
    HostName <IP_PRIVADA_RABBIT>
    ProxyJump proxy

Host svr-celery-1
    HostName <IP_PRIVADA_CELERY_1>
    ProxyJump proxy

Host svr-celery-2
    HostName <IP_PRIVADA_CELERY_2>
    ProxyJump proxy

Host svr-db
    HostName <IP_PRIVADA_DB>
    ProxyJump proxy
```

---

## Despliegue paso a paso

### Paso 1 — Aprovisionar infraestructura con Terraform

```bash
terraform init
terraform fmt -check
terraform validate

tflint --init
tflint -f compact
checkov -d .

terraform plan -out=tfplan
terraform apply tfplan
```

### Paso 2 — Extraer las IPs de los outputs

```bash
terraform output -raw proxy_public_ip
terraform output -raw airflow_private_ip
terraform output -raw rabbitMQ_private_ip
terraform output -json celery_private_ip
terraform output -raw db_private_ip
```

### Paso 3 — Actualizar `ansible_ssh_config` y `.env`

1. Reemplaza los placeholders de `ansible_ssh_config` con las IPs del paso anterior.
2. Actualiza `IP_PANEL` en `.env` con la IP privada de `svr-airflow` (`airflow_private_ip`) — **esta IP cambia en cada `terraform apply`**, es el único valor manual que debes sincronizar por rebuild.

### Paso 4 — Cargar variables de entorno y validar

```bash
set -a; source .env; set +a

# Valida que las variables lleguen bien a Ansible antes de correr todo el playbook
ansible -i inventory.ini all -m debug -a "var=k3s_control_plane_ip" --limit svr-airflow
ansible -i inventory.ini all -m ping
```

### Paso 5 — Ejecutar el playbook completo

```bash
ansible-playbook -i inventory.ini site.yml
```

Esto ejecuta, en orden:
1. **`k8s_master`** — instala el control plane K3s en `svr-airflow` (sin CNI por defecto).
2. **`k8s_worker`** — une `svr-rabbit`, `svr-celery-1`, `svr-celery-2`, `svr-db` al clúster.
3. **`helm`** — instala Helm + Cilium CLI, despliega Cilium (CNI eBPF) en el control plane.
4. **`github_runner`** — registra y arranca el self-hosted runner de GitHub Actions en `svr-airflow`.
5. **`deploy_key`** — genera y registra un Deploy Key SSH, clona el repo de la plataforma en la instancia.

---

## Verificación

```bash
ssh svr-airflow
export KUBECONFIG=$HOME/.kube/config

kubectl get nodes          # los 5 nodos deben estar en Ready
kubectl get pods -A        # sin CrashLoopBackOff / Pending por red
cilium status               # DaemonSets cilium y cilium-envoy en X/X Ready
sudo systemctl status 'actions.runner.*'   # runner activo (running)
ls ~/polaris-kubernetes     # repo clonado vía deploy key
```

En GitHub, confirma en **Settings → Actions → Runners** que el runner aparece **Idle/Online**, no *offline*.

---

## Ciclo de vida del ambiente

```bash
# Destruir toda la infraestructura
terraform destroy -auto-approve
```

Tras un `destroy` + `apply` nuevo, **las IPs privadas cambian**. Antes de volver a correr Ansible:
1. Regenera `ansible_ssh_config` con las IPs nuevas (Paso 3).
2. Actualiza `IP_PANEL` en `.env` con la nueva IP de `svr-airflow`.
3. Si algún worker quedó en un intento de join previo fallido, límpialo antes de reintentar:
   ```bash
   ssh svr-rabbit   # (o el worker que corresponda)
   sudo /usr/local/bin/k3s-agent-uninstall.sh
   ```

---

## CI/CD

El workflow de GitHub Actions (`.github/workflows/deploy.yml`) implementa un patrón **plan-and-apply** con aprobación manual.

### Etapas del pipeline (en cada push / PR a `main`)

| Etapa | Herramienta | Propósito |
|---|---|---|
| Checkout | actions/checkout | Obtener el código |
| Auth | aws-actions/configure-aws-credentials | Federación OIDC (sin credenciales de larga duración) |
| Init | terraform | Inicializar backend + proveedores |
| Lint | TFLint | Linting de Terraform |
| Validate | terraform | Validación de sintaxis e internos |
| Security | Checkov | Escaneo de seguridad de IaC |
| Costos | Infracost | Estimación de costos (comentada en PRs) |
| Calidad | SonarCloud | Quality gate de código |
| Plan | terraform | Generar plan de ejecución |
| Notificar | Mail action | Email con todos los reportes |

### Etapa de apply

- Requiere **aprobación manual** vía GitHub Environments (`production`).
- Reutiliza el artifact `tfplan` guardado en el job de plan.
- Ejecuta `terraform apply tfplan`.

### Secretos de GitHub requeridos

| Secreto | Descripción |
|---|---|
| `AWS_ROLE_ARN` | ARN del rol IAM para OIDC assume-role en AWS |
| `AWS_REGION` | Región de AWS |
| `INFRACOST_API_KEY` | API key de Infracost |
| `SONAR_TOKEN` | Token de autenticación de SonarCloud |
| `SMTP_USERNAME` / `SMTP_PASSWORD` | Credenciales de email para notificaciones |
| `NOTIFY_EMAIL` | Correo del destinatario |
| `cidr_admin` | CIDR de administrador para SSH |

### Rol IAM de OIDC requerido

- **Entidad de confianza**: proveedor OIDC de GitHub (`token.actions.githubusercontent.com`)
- **Condición**: `StringEquals` sobre `token.actions.githubusercontent.com:sub` coincidiendo con `repo:lopezzuluagaj3-collab/polaris-infrastructure:*`
- **Política**: permisos necesarios de EC2, IAM, VPC y S3.

---

## Estructura del proyecto

```
polaris-infrastructure/
├── .github/workflows/deploy.yml
├── modules/
│   ├── networking/        # VPC, subnets, IGW, NAT, route tables
│   ├── security_gruops/   # 5 security groups (typo preservado del código original)
│   ├── iam/                # Rol, policy, instance profile, usuario, access key
│   └── compute/            # 5 instancias EC2
├── roles/
│   ├── k8s_master/          # Instalar K3s control plane (sin flannel)
│   ├── k8s_worker/          # Unir workers al clúster (K3S_URL con puerto :6443 explícito)
│   ├── helm/                 # Helm + Cilium CLI + Cilium CNI (install/upgrade condicional por `helm status`)
│   ├── github_runner/        # Registro dinámico + arranque del self-hosted runner
│   └── deploy_key/           # Generación + registro de Deploy Key SSH + clonado del repo
├── site.yml                  # Entrypoint del playbook (5 plays en orden)
├── inventory.ini
├── ansible_ssh_config         # gitignored
├── .env                        # gitignored — GITHUB_PAT, IP_PANEL
├── .env.example                 # plantilla versionada
├── main.tf / variables.tf / terraform.tfvars
├── .tflint.hcl
└── .terraform.lock.hcl
```

---

## Troubleshooting / Lecciones aprendidas

Problemas reales encontrados en ciclos de destroy/rebuild de este proyecto, y su causa raíz:

| Síntoma | Causa | Fix |
|---|---|---|
| `kubectl get node` pide sudo o falla con `permission denied` | `kubectl` es symlink a `k3s`, que ignora `~/.kube/config` salvo que `KUBECONFIG` esté exportado | `export KUBECONFIG=$HOME/.kube/config`; en tareas Ansible con `become_user`, declarar `environment: {KUBECONFIG: ...}` explícitamente (no heredan `.bashrc`) |
| `"cilium" has no deployed releases` al hacer `cilium upgrade` | Clúster nuevo sin instalación previa de Cilium | Separar en tareas `install`/`upgrade` condicionadas por `helm status cilium -n kube-system` (no por `cilium status`, que refleja salud, no existencia) |
| `cannot reuse a name that is still in use` al hacer `cilium install` | El release de Helm ya existía pero `cilium status` dio código de error por un momentáneo estado no saludable (ej. tras un rejoin de workers) | Usar `helm status` para el chequeo de existencia, no `cilium status` |
| Workers en `NotReady` indefinidamente, `10250: Connection refused` | `K3S_URL` en el join del worker sin puerto explícito (`https://<ip>` en vez de `https://<ip>:6443`) | Agregar `:6443` explícito en la URL de `curl -sfL https://get.k3s.io \| K3S_URL=...` |
| Workers no se unen tras un rebuild aunque el token es correcto | IP del control plane hardcodeada en el comando de Cilium/join, pero Terraform asigna IPs nuevas en cada `apply` | Centralizar la IP en una sola variable (`k3s_control_plane_ip`, vía `.env`/`IP_PANEL`) en vez de repetirla en cada tarea |
| `hostvars[...]['ansible_host']` undefined | El inventario no define `ansible_host`; la conexión SSH depende de `ansible_ssh_config` por alias | No usar `ansible_host` para las IPs de K8s (rompe el `ProxyJump`); usar variables de entorno o una var custom en su lugar |
| GitHub Runner queda "offline" tras registrarse | Tarea duplicada de `config.sh` en el role (una con token dinámico correcto, otra con variable inexistente) ejecutándose ambas | Eliminar la tarea duplicada; verificar que `site.yml` realmente invoque el role (`github_runner` puede existir sin estar en ningún play) |
| `403 Resource not accessible by personal access token` al pedir el token de registro del runner | PAT sin el permiso **Administration: Read and write** sobre el repo | Ajustar permisos del PAT (fine-grained) o usar scope `repo` completo (classic) |
| `Invalid header value b'Bearer ...\r'` | `.env` con terminadores CRLF (típico al editar desde Windows/VS Code en carpetas `/mnt/`) | `sed -i 's/\r$//' .env`; agregar `\| trim` al `lookup('env', ...)` en Ansible como defensa adicional |
| `sudo: interactive authentication is required` en una tarea `delegate_to: localhost` | La tarea hereda `become: true` del play y pide sudo en la máquina de control, no en el servidor remoto | Agregar `become: false` explícito en tareas delegadas a `localhost` que no lo necesiten |
| Deploy Key generado pero `git clone` falla con `Permission denied (publickey)` | La tarea de registro del deploy key en GitHub tenía `when: deploy_keypair.changed`; en una corrida posterior la llave ya existía (`changed: false`) y el registro se saltó | Quitar el `when` de la tarea de registro (es idempotente por el `status_code: [201, 422]`) |

---

## Seguridad

- **Checkov** escanea todo el código Terraform en busca de misconfigurations.
- **Trivy** se usa en el repo complementario `polaris-platform` para escaneo de imágenes contenedor.
- **IMDSv2** forzado en todas las instancias EC2.
- **Volúmenes EBS** encriptados por defecto.
- **Autenticación OIDC** para CI/CD de infraestructura — sin credenciales de larga duración en GitHub.
- **Secretos de Ansible vía `.env`** (no Vault): el PAT de GitHub y la IP del control plane se inyectan como variables de entorno, nunca se commitea `.env`. Trade-off consciente: prioriza reproducibilidad sin contraseña de vault, a cambio de que la protección del secreto depende enteramente de que `.env` nunca se suba a git.
- **Deploy Key con `read_only: true`** — la instancia solo puede clonar/pull, no puede hacer push al repo.
- **Principio de mínimos privilegios** en security groups.
- **Aislamiento de red** — solo el bastión tiene EIP público.

### Rotación de credenciales pendiente / recurrente

Si en algún momento un PAT, Access Key de AWS, o contraseña de Postgres/Airflow quedó expuesta en texto plano (chat, log, commit), **rótala de inmediato**:
- GitHub PAT: Settings → Developer settings → Tokens → Delete/Regenerate.
- AWS Access Key: IAM → Users → Security credentials → Deactivate + Create new.
- Postgres/Airflow: actualizar la contraseña en el secret/values correspondiente y redeployar.

### Problemas conocidos y oportunidades de mejora

| # | Problema | Ubicación |
|---|---|---|
| 1 | Las variables `key_proxy` y `key_general` se declaran pero las instancias usan el nombre hardcodeado `"proxy_key"` / `"general_key"` | `modules/compute/main.tf` |
| 2 | El recurso de usuario IAM + access key crea credenciales de larga duración | `modules/iam/main.tf` |
| 3 | `IP_PANEL` en `.env` sigue siendo manual por cada rebuild (no se lee automáticamente de `terraform output`) | `.env` / `group_vars/all.yml` |

---

## Licencia

Este es un proyecto de portafolio. Todo el código se proporciona sin garantía para fines educativos y de demostración.