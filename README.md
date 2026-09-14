# VitaLife Pilates — Infraestrutura (LocalStack)

Emulação local da infraestrutura AWS do projeto Estúdio VitaLife Pilates, usando [LocalStack] Community

Cria, via IaC (`awslocal`), a rede da arquitetura definida com o professor (VPC, subnets, route tables, security groups) e o bucket S3 de backup — tudo o que o LocalStack Community realmente emula. ALB e EFS não estão aqui porque exigem LocalStack Pro (pago) e não têm emulação real no plano gratuito.

## Como rodar

Pré-requisito: Docker Desktop aberto.

```bash
docker compose up -d
```

O script `localstack-init/init-aws.sh` roda sozinho assim que o container fica pronto. Para conferir o que foi criado:

```bash
docker compose logs localstack | grep -A 20 "== Resumo =="
```

## O que é criado

| Recurso | Valor |
|---|---|
| VPC | `10.0.0.0/22` |
| Subnet pública us-east-1a | `10.0.1.0/25` |
| Subnet pública us-east-1b | `10.0.0.128/25` |
| Subnet privada us-east-1a | `10.0.2.0/25` |
| Internet Gateway | anexado à VPC, rota `0.0.0.0/0` na route table pública |
| Route table privada | sem rota de saída pra internet |
| Security Group `sg-web` | HTTP (80) público, SSH (22) só de dentro da VPC |
| Security Group `sg-app-db` | 8080/3306 só a partir do `sg-web` |
| Bucket S3 | `vitalife-backup` |

## Parar e limpar

```bash
docker compose down
rm -rf localstack-data
```
