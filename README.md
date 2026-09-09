# POLARIS Logistics — Infraestructura como Código (IaC + CaC)

> **Repositorio 1 de 3** — Aprovisionamiento de infraestructura en AWS y arranque del clúster Kubernetes para la plataforma ETL de POLARIS Logistics.

[Visión general](#visión-general) • [Arquitectura](#arquitectura) • [Requisitos previos](#requisitos-previos) • [Configuración](#configuración) • [Despliegue](#despliegue) • [CI/CD](#cicd) • [Estructura del proyecto](#estructura-del-proyecto) • [Outputs](#outputs) • [Seguridad](#seguridad) • [Licencia](#licencia)

---

## Visión general

**POLARIS Logistics** es un proyecto de portafolio que demuestra una pipeline DevOps y Data Engineering empresarial completa. Este repositorio — la capa de **Infraestructura** — aprovisiona todos los recursos de AWS usando **Terraform** (IaC) y arranca un clúster **K3s Kubernetes** autoadministrado usando **Ansible** (CaC).

La plataforma procesa el dataset de Olist Brazilian E-Commerce diariamente mediante una pipeline ETL de Airflow + RabbitMQ + Celery, cargando los datos limpios en PostgreSQL sobre Kubernetes para su consumo en Power BI.

| Área | Herramienta |
|---|---|
| Cloud | AWS (us-east-1) |
| IaC | Terraform >= 1.5 |
| CaC | Ansible |
| Contenedores | Docker |
| Orquestación | K3s (Kubernetes ligero, estilo kubeadm) |
| CNI | Cilium (eBPF) |
| Ingress | NGINX Ingress |
| Calidad | TFLint, Checkov, Infracost, SonarCloud |
| CI/CD | GitHub Actions + OIDC |

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
                      │
                      └───────────┬───────────┐
                                  │
                      ┌───────────┴───────────┐
                      │    Subnet Privada     │  12.0.2.0/24
                      │ (Route Table: 0.0.0.0/0 → NAT GW)
                      │
        ┌──────────────┼──────────────┬──────────────┐
        │              │              │              │
   ┌────┴────┐   ┌────┴────┐    ┌────┴────┐   ┌────┴────┐   ┌────┴────┐
   │EC2-2    │   │EC2-3    │    │EC2-4a   │   │EC2-4b   │   │EC2-5    │
   │svr-     │   │svr-     │    │svr-     │   │svr-     │   │svr-    │
   │airflow  │   │rabbit-  │    │celery-1 │   │celery-2 │   │db      │
   │(K3s CP) │   │MQ        │    │(Worker) │   │(Worker) │   │(Worker) │
   └────────┘   └────────┘    └────────┘   └────────┘   └────────┘
```

### Inventario de instancias

| Instancia | Host | Función | Subnet | Security Group | Rol K8s |
|---|---|---|---|---|---|
| EC2-1 | `svr-proxy` | Bastión + controlador NGINX Ingress | Pública | `sg_proxy` | — |
| EC2-2 | `svr-airflow` | **Plano de control K3s** + Airflow scheduler/webserver | Privada | `sg_airflow` | Control plane |
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
- **Subnet pública**: `12.0.1.0/24` — alberga el proxy, EIP del NAT, IGW
- **Subnet privada**: `12.0.2.0/24` — alberga todos los nodos K8s, salida vía NAT Gateway
- **EIP**: asignado al NAT Gateway y a la instancia proxy (bastión)

### Estado de Terraform

El estado se almacena de forma remota en un bucket S3 con encriptación:

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
| TFLint | >= 0.55.0 | [github.com/terraform-linters/tflint](https://github.com/terraform-linters/tflint) |
| Infracost | última | [infracost.io](https://www.infracost.org/install/) |

### Requisitos en AWS

1. **Cuenta AWS** con permisos para crear VPCs, instancias EC2, roles/políticas IAM, EIPs y buckets S3.
2. **Proveedor OIDC** + **rol IAM** para GitHub Actions (el pipeline de CI/CD asume este rol vía el secreto `AWS_ROLE_ARN`). Ver sección [CI/CD](#cicd).
3. **Pares de llaves SSH** — dos pares deben existir en la consola de AWS (o vía `aws ec2 create-key-pair`):
   - `proxy_key` — para la instancia bastión (pública)
   - `general_key` — para todas las instancias privadas
4. **Bucket S3 para el backend** ya existe (`sirius-terraform-state-022784797877`). El bucket debe estar pre-creado; Terraform no lo administra.

### Configurar credenciales de AWS (local)

```bash
aws configure
# o usar SSO / perfiles nombrados
```

---

## Configuración

### Variables de Terraform

Las variables se definen en `variables.tf` y en `modules/*/variables.tf`. Los valores por ambiente están en `terraform.tfvars` (está en `.gitignore` — copie el ejemplo):

```bash
cp terraform.tfvars.example terraform.tfvars
```

**`terraform.tfvars` — nivel raíz:**

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `aws_region` | `"us-east-1"` | Región de AWS |
| `allowed_ssh_cidr` | `"0.0.0.0/0"` | CIDR permitido para SSH al proxy (puerto 22) — **restringir a su IP en producción** |

> **Nota de seguridad**: `allowed_ssh_cidr = "0.0.0.0/0"` es permisivo para pruebas. Reemplace con su IP específica, ej. `"203.0.113.5/32"`. En CI/CD el valor se sobrescribe con el secreto `cidr_admin` vía `TF_VAR_allowed_ssh_cidr` en el workflow.

### Inventario de Ansible

El archivo `inventory.ini` define los grupos de hosts:

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

El archivo `ansible_ssh_config` configura el enrutamiento SSH a través del bastión (proxy) usando `ProxyJump`. **Este archivo está en `.gitignore`** y debe regenerarse después de provisionar con Terraform usando los outputs.

---

## Despliegue

### Paso 1 — Aprovisionar infraestructura con Terraform

```bash
# Inicializar (descarga proveedores, configura backend)
terraform init

# Validar y formatear
terraform fmt -check
terraform validate

# Lint y escaneo de seguridad (local)
tflint --init
tflint -f compact
checkov -d .

# Revisar y aplicar
terraform plan -out=tfplan
terraform apply tfplan
```

Después de `apply`, Terraform expone las IPs e IDs de las instancias. Úsalos para construir el SSH config de Ansible.

### Paso 2 — Arrancar el clúster Kubernetes con Ansible

```bash
# Generar ansible_ssh_config desde los outputs de Terraform (ver abajo)
# Ejecutar el playbook — instala K3s control plane, une workers, instala Cilium CNI + Helm
ansible-playbook -i inventory.ini site.yml
```

### Paso 3 — Verificar el clúster

```bash
kubectl get nodes
kubectl get pods -A
cilium status
```

### Generar el SSH config de Ansible

Después de `terraform apply`, extraiga el EIP del proxy y las IPs privadas de los outputs:

```bash
terraform output -raw proxy_public_ip      # ej. 3.226.53.129
terraform output -json celery_private_ip   # array de IPs
terraform output -raw airflow_private_ip
terraform output -raw rabbitMQ_private_ip
terraform output -raw db_private_ip
```

Actualice `ansible_ssh_config` con estos valores, reemplazando las IPs de placeholder.

### Ciclo de vida del ambiente

```bash
# Destruir toda la infraestructura
terraform destroy -auto-approve
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
| `AWS_REGION` | Región de AWS (ej. `us-east-1`) |
| `INFRACOST_API_KEY` | API key de Infracost |
| `SONAR_TOKEN` | Token de autenticación de SonarCloud |
| `SMTP_USERNAME` / `SMTP_PASSWORD` | Credenciales de email para notificaciones |
| `NOTIFY_EMAIL` | Correo del destinatario |
| `cidr_admin` | CIDR de administrador para SSH (ej. `"203.0.113.5/32"`) |

### Rol IAM de OIDC requerido

El workflow de GitHub Actions asume un rol IAM vía OIDC. Cree un rol en AWS con:

- **Entidad de confianza**: proveedor OIDC de GitHub (`token.actions.githubusercontent.com`)
- **Condición de confianza**: `StringEquals` sobre `token.actions.githubusercontent.com:sub` coincidiendo con `repo:lopezzuluagaj3-collab/polaris-infrastructure:*`
- **Política de permisos**: adjunte una política que otorgue a Terraform los permisos necesarios de EC2, IAM, VPC y S3.

---

## Estructura del proyecto

```
polaris-infrastructure/
├── .github/
│   └── workflows/
│       └── deploy.yml          # Pipeline de CI/CD
├── modules/
│   ├── networking/
│   │   ├── main.tf             # VPC, subnets, IGW, NAT, route tables
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security_gruops/        # (nota: typo "gruops" preservado del código original)
│   │   ├── main.tf             # 5 security groups
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── iam/
│   │   ├── main.tf             # Rol, policy, instance profile, usuario, access key
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── compute/
│       ├── main.tf             # 5 instancias EC2 (proxy, airflow, rabbit, celery x2, db)
│       ├── variables.tf
│       └── outputs.tf
├── roles/                      # Roles de Ansible
│   ├── k8s_master/
│   │   └── tasks/main.yml      # Instalar K3s control plane (sin flannel)
│   ├── k8s_worker/
│   │   └── tasks/main.yml      # Unir workers al clúster
│   ├── helm/
│   │   └── tasks/main.yml      # Instalar Helm + Cilium CLI + desplegar Cilium CNI
│   └── cilium_cli/
│       └── tasks/main.yml      # Cilium CLI standalone (no conectado a site.yml)
├── site.yml                    # Entrypoint del playbook de Ansible
├── inventory.ini               # Inventario de hosts de Ansible
├── ansible_ssh_config          # Config SSH (gitignored)
├── main.tf                     # Terraform raíz — llamadas a módulos + config de provider
├── variables.tf                # Variables raíz
├── terraform.tfvars            # Valores de ambiente (gitignored)
├── .tflint.hcl                 # Configuración de TFLint
├── .terraform.lock.hcl         # Archivo lock de proveedores
└── contexto-proyecto.md        # Contexto del proyecto (español)
```

---

## Outputs

| Output | Descripción |
|---|---|
| `proxy_public_ip` | IP pública fija del bastión (EIP) — punto de entrada SSH |
| `airflow_private_ip` | IP privada del control plane (también Airflow) |
| `rabbitMQ_private_ip` | IP privada de RabbitMQ |
| `celery_private_ip` | Lista de IPs privadas de los workers Celery |
| `db_private_ip` | IP privada de PostgreSQL |
| `all_instances_ids` | Mapa de nombre a ID de instancia |
| `all_instances_public_ips` | Mapa de nombre a IP pública |
| `vpc_id` / `vpc_cidr` | Identificador y CIDR de la VPC |
| `subnet_publica_id` / `subnet_privada_id` | IDs de subnets |
| `sg_*_id` | IDs de security groups |
| `instance_profile_name` / `role_arn` | Referencias IAM |
| `ebs_csi_access_key_id` / `ebs_csi_secret_access_key` | Credenciales de usuario IAM (**sensitivas**) |

---

## Seguridad

Este repositorio sigue buenas prácticas DevSecOps:

- **Checkov** escanea todo el código Terraform en busca de misconfigurations (CI exige `CKV_AWS_79` y salta falsos positivos conocidos).
- **Trivy** se usa en el repo complementario `polaris-platform` para escaneo de imágenes contenedor.
- **IMDSv2** está forzado en todas las instancias EC2 (`http_tokens = required`).
- **Volúmenes EBS** están encriptados por defecto.
- **Autenticación OIDC** para CI/CD — sin credenciales de larga duración almacenadas en GitHub.
- **Principio de mínimos privilegios** — los security groups restringen tráfico a fuentes específicas (CIDR de VPC, SG del proxy, CIDR de admin).
- **Aislamiento de red** — todas las instancias de aplicación están en subnets privadas; solo el bastión tiene un EIP público.

### Problemas conocidos y oportunidades de mejora

| # | Problema | Ubicación |
|---|---|---|
| 1 | Las variables `key_proxy` y `key_general` se declaran pero las instancias usan el nombre hardcodeado `"proxy_key"` / `"general_key"` | `modules/compute/main.tf` |
| 2 | `site.yml` invoca el rol `helm` para Cilium, pero existe un rol dedicado `cilium_cli` que no se referencia | `site.yml` |
| 3 | El recurso de usuario IAM + access key crea credenciales de larga duración | `modules/iam/main.tf:125` |

---

## Licencia

Este es un proyecto de portafolio. Todo el código se proporciona sin garantía para fines educativos y de demostración.

<!--
TODO: Conectar el rol `cilium_cli` en `site.yml`, usar las variables `key_proxy`/`key_general`
      en lugar de nombres hardcodeados en `modules/compute/main.tf`, y considerar reemplazar
      las access keys de usuarios IAM con IAM Roles for Service Accounts (IRSA) o roles de instancia.
-->
