data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "lambda/"
  output_path = "lambda.zip"
}

data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-layer/"
  output_path = "${path.module}/lambda-layer/lambda_layer.zip"
}

resource "aws_lambda_layer_version" "my_lambda_layer" {
  filename   = data.archive_file.lambda_layer.output_path
  layer_name = "boto3-requests-layer"

  compatible_runtimes = ["python3.8"]
  source_code_hash    = filebase64sha256(data.archive_file.lambda_layer.output_path)
}

resource "aws_lambda_function" "websocket_lambda" {
  function_name = "websocket_lambda_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_handler.handler"
  runtime       = "python3.8"
  filename      = data.archive_file.lambda_zip.output_path
  layers        = [aws_lambda_layer_version.my_lambda_layer.arn]

  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  timeout = 90 # Maximum allowed timeout in seconds

  environment {
    variables = {
      API_GATEWAY_ID = aws_apigatewayv2_api.websocket_api.id
      REGION         = var.region # Terraform 변수 또는 직접 입력
      STAGE          = aws_apigatewayv2_stage.default_stage.name
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private_subnet[*].id
    security_group_ids = [aws_security_group.my_sg.id]
  }
}

# Lambda 실행에 필요한 IAM 역할 및 정책
resource "aws_iam_role" "lambda_role" {
  name = "lambda_websocket_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_websocket_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "execute-api:ManageConnections",
        "bedrock-runtime:*",
        "bedrock:*",
        "ec2:*"
      ],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}
