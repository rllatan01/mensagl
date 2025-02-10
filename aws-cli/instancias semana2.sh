#!/bin/bash

# Definir variables
key_name="ssh-mensagl-2025-rufino"
ami_Ubuntu_22_04="ami-0e1bed4f06a3b463d"
ami_Ubuntu_24_04="ami-04b4f1a9cf54c11d0"  # Reemplaza con el ID de la AMI de Ubuntu que desees usar
instance_type="t2.micro"
region="us-east-1"

# Desactivar paginación en AWS CLI
export AWS_PAGER=""

# Obtener IDs de subredes y VPC
vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-mensagl-2025-rufino" --query "Vpcs[0].VpcId" --output text)
subnet_public1_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-rufino-subnet-public1-us-east-1a" --query "Subnets[0].SubnetId" --output text)
subnet_public2_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-rufino-subnet-public2-us-east-1b" --query "Subnets[0].SubnetId" --output text)
subnet_private1_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-rufino-subnet-private1-us-east-1a" --query "Subnets[0].SubnetId" --output text)
subnet_private2_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-rufino-subnet-private2-us-east-1b" --query "Subnets[0].SubnetId" --output text)

# Crear grupos de seguridad
sg_matrix_synapse_id=$(aws ec2 create-security-group --group-name "sg_Matrix-Synapse" --description "Security group for Matrix-Synapse" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 8008 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 8448 --cidr 0.0.0.0/0

sg_wordpress_id=$(aws ec2 create-security-group --group-name "sg_wordpress" --description "Security group for Wordpress" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_wordpress_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_wordpress_id" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_wordpress_id" --protocol tcp --port 443 --cidr 0.0.0.0/0

sg_postgres_id=$(aws ec2 create-security-group --group-name "sg_postgres" --description "Security group for Postgres" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_postgres_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_postgres_id" --protocol tcp --port 5432 --cidr 0.0.0.0/0

# Crear instancias Matrix-Synapse en subredes publicas con IP privada y pública
instance_matrix1_id=$(aws ec2 run-instances --image-id "$ami_Ubuntu_24_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --subnet-id "$subnet_public1_id" --private-ip-address "10.215.1.20" --associate-public-ip-address --security-group-ids "$sg_matrix_synapse_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Matrix-Synapse1}]' --query 'Instances[0].InstanceId' --output text --user-data file://../aws-user-data/matrixdns.sh)

# Crear instancias Wordpress en subredes publicas con IP privada y pública
instance_wordpress1_id=$(aws ec2 run-instances --image-id "$ami_Ubuntu_24_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --subnet-id "$subnet_public2_id" --private-ip-address "10.215.2.20" --associate-public-ip-address --security-group-ids "$sg_wordpress_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Wordpress1}]' --query 'Instances[0].InstanceId' --output text --user-data file://../aws-user-data/ticketsdns.sh)

# Crear instancias Postgres con IP privada
instance_postgres1_id=$(aws ec2 run-instances --image-id "$ami_Ubuntu_22_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --subnet-id "$subnet_private1_id" --private-ip-address "10.215.3.100" --security-group-ids "$sg_postgres_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Postgres1}]' --query 'Instances[0].InstanceId' --output text)
instance_postgres2_id=$(aws ec2 run-instances --image-id "$ami_Ubuntu_22_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --subnet-id "$subnet_private1_id" --private-ip-address "10.215.3.101" --security-group-ids "$sg_postgres_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Postgres2}]' --query 'Instances[0].InstanceId' --output text)

# Crear grupo de seguridad para RDS
sg_rds_id=$(aws ec2 create-security-group --group-name "sg_rds_mysql" --description "Security group for RDS MySQL" --vpc-id "$vpc_id" --query 'GroupId' --output text)

# Permitir conexiones solo desde el grupo de seguridad de Wordpress al RDS
aws ec2 authorize-security-group-ingress --group-id "$sg_rds_id" --protocol tcp --port 3306 --source-group "$sg_wordpress_id"

# Crear un grupo de subred RDS para la subred privada 2
aws rds create-db-subnet-group --db-subnet-group-name "rds-subnet-group-mensagl" --db-subnet-group-description "Subnet group for RDS MySQL" --subnet-ids "$subnet_private1_id" "$subnet_private2_id"

# Creación de la RDS de MySQL
aws rds create-db-instance \
    --db-instance-identifier "rds-mensagl-mysql" \
    --db-instance-class "db.t3.micro" \
    --engine "mysql" \
    --allocated-storage 20 \
    --master-username "admin" \
    --master-user-password "Password123" \
    --vpc-security-group-ids "$sg_rds_id" \
    --db-subnet-group-name "rds-subnet-group-mensagl" \
    --backup-retention-period 7 \
    --storage-type "gp2" \
    --multi-az \
    --no-publicly-accessible

echo "Instancias creadas y configuradas con IPs privadas y públicas."

