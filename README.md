# Amazon Bedrock Websocket

## Overview
This project uses Terraform to manage AWS resources, deploy Websocket API Gateway and Lambda function which invoke Bedrock.  

## Structure
- `lambda/`: Lambda function source code
- `lambda-layer/`: Files related to Lambda layer
- `scripts/`: Test scripts
- `*.tf`: Terraform configuration files

## Prerequisites
- Terraform installation
- AWS CLI installation and configuration
- Python installation

## Preparing Lambda Layer
The Lambda layer contains the necessary Python libraries.

1. Create the lambda-layer/python folder:
    ```bash 
    mkdir -p lambda-layer/python
    cd lambda-layer/python
    ```

2. Create and activate a Python virtual environment:
    ```bash
    python -m venv .venv 
    source .venv/bin/activate
    ```

3. Install the required libraries:
    ```bash
    pip install requests boto3 slack-bolt
    ```

## Deployment 
Use the following commands to deploy the project:
```bash
terraform init
terraform apply
```

## Test
```
export WEBSOCKET_API_URL="wss://y4siqdvwp4.execute-api.us-west-2.amazonaws.com/$default/"
cd scripts
python test.py
```