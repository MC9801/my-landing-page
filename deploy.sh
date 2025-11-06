#!/bin/bash

# Configuración
STACK_NAME="my-landing-page-dev"
REGION="us-east-1"
MAIN_TEMPLATE="main.yaml"

# Crear bucket único para templates
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="cf-templates-$ACCOUNT_ID-$REGION"

echo "🚀 Configurando despliegue con S3..."

# Crear bucket si no existe
if ! aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "✅ Bucket $BUCKET_NAME ya existe"
else
    echo "📦 Creando bucket S3: $BUCKET_NAME"
    aws s3 mb "s3://$BUCKET_NAME" --region $REGION
fi

# Subir templates a S3
echo "📤 Subiendo templates a S3..."
aws s3 cp main.yaml s3://$BUCKET_NAME/
aws s3 cp s3-bucket.yaml s3://$BUCKET_NAME/
aws s3 cp cloudfront.yaml s3://$BUCKET_NAME/
aws s3 cp route53.yaml s3://$BUCKET_NAME/

# Reemplazar URLs en main.yaml
echo "🔧 Actualizando URLs S3 en template..."
sed -i.bak "s|\./s3-bucket\.yaml|https://$BUCKET_NAME.s3.$REGION.amazonaws.com/s3-bucket.yaml|g" $MAIN_TEMPLATE
sed -i.bak "s|\./cloudfront\.yaml|https://$BUCKET_NAME.s3.$REGION.amazonaws.com/cloudfront.yaml|g" $MAIN_TEMPLATE  
sed -i.bak "s|\./route53\.yaml|https://$BUCKET_NAME.s3.$REGION.amazonaws.com/route53.yaml|g" $MAIN_TEMPLATE

# Desplegar stack
echo "🚀 Desplegando stack..."
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$MAIN_TEMPLATE \
    --parameters \
        ParameterKey=ProjectName,ParameterValue=my-landing-page \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=DomainName,ParameterValue=example.com \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --region $REGION

echo "⏳ Monitoreando despliegue..."
aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME \
    --region $REGION

if [ $? -eq 0 ]; then
    echo "✅ Stack desplegada exitosamente!"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].Outputs' \
        --output table
else
    echo "❌ Error en el despliegue"
    aws cloudformation describe-stack-events \
        --stack-name $STACK_NAME \
        --query 'StackEvents[?contains(ResourceStatus, `FAILED`)]' \
        --output table
fi