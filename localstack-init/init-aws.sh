#!/bin/bash
# Roda automaticamente quando o LocalStack fica pronto (init-hook do container).
# Recria, via IaC (awslocal), a infraestrutura de rede da arquitetura AWS do projeto
# (VPC + subnets + route tables + security group) e o bucket S3 de backup.

set -e

REGION="us-east-1"

echo "== VPC =="
VPC_ID=$(awslocal ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region $REGION \
  --query 'Vpc.VpcId' --output text)
awslocal ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=vpc-pilates
echo "VPC criada: $VPC_ID (vpc-pilates)"

echo "== Internet Gateway =="
IGW_ID=$(awslocal ec2 create-internet-gateway --region $REGION \
  --query 'InternetGateway.InternetGatewayId' --output text)
awslocal ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
awslocal ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=vitalife-igw
echo "Internet Gateway criado: $IGW_ID"

echo "== Subnets =="
SUBNET_PUB_1A=$(awslocal ec2 create-subnet \
  --vpc-id $VPC_ID --cidr-block 10.0.1.0/25 \
  --availability-zone ${REGION}a \
  --query 'Subnet.SubnetId' --output text)
awslocal ec2 create-tags --resources $SUBNET_PUB_1A --tags Key=Name,Value=subnet-public
echo "Subnet pública us-east-1a: $SUBNET_PUB_1A (subnet-public, 10.0.1.0/25)"

SUBNET_PUB_1B=$(awslocal ec2 create-subnet \
  --vpc-id $VPC_ID --cidr-block 10.0.0.128/25 \
  --availability-zone ${REGION}b \
  --query 'Subnet.SubnetId' --output text)
awslocal ec2 create-tags --resources $SUBNET_PUB_1B --tags Key=Name,Value=subnet-public-substitutiva
echo "Subnet pública us-east-1b: $SUBNET_PUB_1B (subnet-public-substitutiva, 10.0.0.128/25)"

SUBNET_PRIV_1A=$(awslocal ec2 create-subnet \
  --vpc-id $VPC_ID --cidr-block 10.0.2.0/25 \
  --availability-zone ${REGION}a \
  --query 'Subnet.SubnetId' --output text)
awslocal ec2 create-tags --resources $SUBNET_PRIV_1A --tags Key=Name,Value=subnet-private-exemplo
echo "Subnet privada us-east-1a: $SUBNET_PRIV_1A (subnet-private-exemplo, 10.0.2.0/25)"

echo "== Route Tables =="
RT_PUBLICA=$(awslocal ec2 create-route-table --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)
awslocal ec2 create-tags --resources $RT_PUBLICA --tags Key=Name,Value=rt-publica
awslocal ec2 create-route --route-table-id $RT_PUBLICA \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
awslocal ec2 associate-route-table --route-table-id $RT_PUBLICA --subnet-id $SUBNET_PUB_1A
awslocal ec2 associate-route-table --route-table-id $RT_PUBLICA --subnet-id $SUBNET_PUB_1B
echo "Route table pública criada e associada: $RT_PUBLICA"

RT_PRIVADA=$(awslocal ec2 create-route-table --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)
awslocal ec2 create-tags --resources $RT_PRIVADA --tags Key=Name,Value=rt-privada
awslocal ec2 associate-route-table --route-table-id $RT_PRIVADA --subnet-id $SUBNET_PRIV_1A
echo "Route table privada criada e associada (sem rota de saída p/ internet): $RT_PRIVADA"

echo "== Security Groups =="
SG_WEB=$(awslocal ec2 create-security-group \
  --group-name sg-web --description "Web servers - HTTP publico, SSH restrito" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)
awslocal ec2 authorize-security-group-ingress --group-id $SG_WEB \
  --protocol tcp --port 80 --cidr 0.0.0.0/0
awslocal ec2 authorize-security-group-ingress --group-id $SG_WEB \
  --protocol tcp --port 22 --cidr 10.0.0.0/16
echo "Security group sg-web criado: $SG_WEB (80 público, 22 só dentro da VPC)"

SG_APP_DB=$(awslocal ec2 create-security-group \
  --group-name sg-app-db --description "App/DB - so aceita trafego do sg-web" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)
awslocal ec2 authorize-security-group-ingress --group-id $SG_APP_DB \
  --protocol tcp --port 8080 --source-group $SG_WEB
awslocal ec2 authorize-security-group-ingress --group-id $SG_APP_DB \
  --protocol tcp --port 3306 --source-group $SG_WEB
echo "Security group sg-app-db criado: $SG_APP_DB (8080/3306 só a partir do sg-web)"

echo "== S3 =="
awslocal s3 mb s3://vitalife-backup
echo "Bucket 'vitalife-backup' criado no LocalStack."

echo ""
echo "== Resumo =="
echo "VPC: $VPC_ID (vpc-pilates, 10.0.0.0/16)"
echo "Subnets: subnet-public=$SUBNET_PUB_1A subnet-public-substitutiva=$SUBNET_PUB_1B subnet-private-exemplo=$SUBNET_PRIV_1A"
echo "Security Groups: sg-web=$SG_WEB sg-app-db=$SG_APP_DB"
