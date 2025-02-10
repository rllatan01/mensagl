#!/bin/bash

# Definir variables
key_name="ssh-mensagl-2025-rufino"
ami_idmatrix="ami-0e1bed4f06a3b463d"
ami_idticket="ami-04b4f1a9cf54c11d0"  # Reemplaza con el ID de la AMI de Ubuntu que desees usar
instance_type="t2.micro"
region="us-east-1"
bucket_name="copias-seguridad-unique-name-$(date +%s)"  # Usa un nombre único

# Desactivar paginación en AWS CLI
export AWS_PAGER=""

# Crear un par de claves
aws ec2 create-key-pair --key-name "$key_name" --query 'KeyMaterial' --output text > "${key_name}.pem"
chmod 400 "${key_name}.pem"

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

# Crear interfaces de red con IPs privadas específicas y asociarlas con las instancias
interface_matrix_id=$(aws ec2 create-network-interface --subnet-id "$subnet_public1_id" --private-ip-address "10.215.1.2" --description "Interface for Matrix-Synapse" --query 'NetworkInterface.NetworkInterfaceId' --output text)
interface_wordpress_id=$(aws ec2 create-network-interface --subnet-id "$subnet_public2_id" --private-ip-address "10.215.2.2" --description "Interface for Wordpress" --query 'NetworkInterface.NetworkInterfaceId' --output text)

# Crear instancias Matrix-Synapse en subredes publicas con IP pública
instance_matrix_id=$(aws ec2 run-instances --image-id "$ami_idmatrix" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_matrix_synapse_id" --network-interface "NetworkInterfaceId=$interface_matrix_id,DeviceIndex=0,AssociatePublicIpAddress=true" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Matrix-Synapse1}]' --query 'Instances[0].InstanceId' --output text --user-data file://../EC2-User/matrixdns.sh)

# Crear instancias Wordpress en subredes publicas con IP pública
instance_wordpress_id=$(aws ec2 run-instances --image-id "$ami_idticket" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_wordpress_id" --network-interface "NetworkInterfaceId=$interface_wordpress_id,DeviceIndex=0,AssociatePublicIpAddress=true" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Wordpress1}]' --query 'Instances[0].InstanceId' --output text --user-data file://../EC2-User/ticketsdns.sh)

echo "Instancias creadas y configuradas con IPs privadas específicas y IP pública."
