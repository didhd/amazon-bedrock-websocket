provider "aws" {
  region = var.region # 원하는 AWS 리전 설정
}

resource "aws_iam_role" "api_gateway_cloudwatch_log_role" {
  name = "api_gateway_cloudwatch_log_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
      },
    ],
  })
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_log_policy" {
  name = "api_gateway_cloudwatch_log_policy"
  role = aws_iam_role.api_gateway_cloudwatch_log_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
    ],
  })
}


resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "websocket_api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.websocket_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "route" {
  api_id                              = aws_apigatewayv2_api.websocket_api.id
  route_key                           = "$default"
  target                              = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  route_response_selection_expression = "$default"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.websocket_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId"
  }
}

resource "aws_lambda_permission" "websocket_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.websocket_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket_api.execution_arn}/*/*"
}

output "websocket_api_url" {
  value = aws_apigatewayv2_api.websocket_api.api_endpoint
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name = "/aws/apigateway/my-websocket-api"
}

resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_log_role.arn
}
