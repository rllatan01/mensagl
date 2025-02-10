#!/bin/bash

# Desactivar paginación en AWS CLI
export AWS_PAGER=""
# Crear VPC
vpc_id=$(aws ec2 create-vpc --cidr-block "10.215.0.0/16" --instance-tenancy "default" --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino}]' --query 'Vpc.VpcId' --output text)

# Habilitar DNS Hostnames
aws ec2 modify-vpc-attribute --vpc-id "$vpc_id" --enable-dns-hostnames '{"Value":true}'

# Crear subredes
subnet_public1_id=$(aws ec2 create-subnet --vpc-id "$vpc_id" --cidr-block "10.215.1.0/24" --availability-zone "us-east-1a" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino-subnet-public1-us-east-1a}]' --query 'Subnet.SubnetId' --output text)
subnet_public2_id=$(aws ec2 create-subnet --vpc-id "$vpc_id" --cidr-block "10.215.2.0/24" --availability-zone "us-east-1b" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino-subnet-public2-us-east-1b}]' --query 'Subnet.SubnetId' --output text)
subnet_private1_id=$(aws ec2 create-subnet --vpc-id "$vpc_id" --cidr-block "10.215.3.0/24" --availability-zone "us-east-1a" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino-subnet-private1-us-east-1a}]' --query 'Subnet.SubnetId' --output text)
subnet_private2_id=$(aws ec2 create-subnet --vpc-id "$vpc_id" --cidr-block "10.215.4.0/24" --availability-zone "us-east-1b" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino-subnet-private2-us-east-1b}]' --query 'Subnet.SubnetId' --output text)

# Crear y asociar Internet Gateway
igw_id=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino-igw}]' --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id"

# Pausa para esperar que el Internet Gateway esté completamente operativo
sleep 10

# Crear tabla de rutas pública
rtb_public_id=$(aws ec2 create-route-table --vpc-id "$vpc_id" --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino-rtb-public}]' --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$rtb_public_id" --destination-cidr-block "0.0.0.0/0" --gateway-id "$igw_id"

# Asociar tabla de rutas pública con subredes públicas
aws ec2 associate-route-table --route-table-id "$rtb_public_id" --subnet-id "$subnet_public1_id"
aws ec2 associate-route-table --route-table-id "$rtb_public_id" --subnet-id "$subnet_public2_id"

# Crear Elastic IP y NAT Gateway (sin --tag-specifications)
eipalloc_id=$(aws ec2 allocate-address --domain "vpc" --query 'AllocationId' --output text)
nat_id=$(aws ec2 create-nat-gateway --subnet-id "$subnet_public1_id" --allocation-id "$eipalloc_id" --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino-nat-public1-us-east-1a}]' --query 'NatGateway.NatGatewayId' --output text)

# Pausa para esperar que el NAT Gateway esté completamente operativo
sleep 10

# Crear tablas de rutas privadas
rtb_private1_id=$(aws ec2 create-route-table --vpc-id "$vpc_id" --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino-rtb-private1-us-east-1a}]' --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$rtb_private1_id" --destination-cidr-block "0.0.0.0/0" --nat-gateway-id "$nat_id"
aws ec2 associate-route-table --route-table-id "$rtb_private1_id" --subnet-id "$subnet_private1_id"

rtb_private2_id=$(aws ec2 create-route-table --vpc-id "$vpc_id" --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=vpc-mensagl-2025-rufino-rtb-private2-us-east-1b}]' --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$rtb_private2_id" --destination-cidr-block "0.0.0.0/0" --nat-gateway-id "$nat_id"
aws ec2 associate-route-table --route-table-id "$rtb_private2_id" --subnet-id "$subnet_private2_id"

# Describir VPC y tablas de rutas
aws ec2 describe-vpcs --vpc-ids "$vpc_id"
aws ec2 describe-route-tables --route-table-ids "$rtb_private1_id" "$rtb_private2_id"

