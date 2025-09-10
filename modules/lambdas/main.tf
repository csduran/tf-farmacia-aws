locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ────────── IAM para Lambda ──────────
resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DDB read/write sobre las tablas
resource "aws_iam_policy" "ddb_rw" {
  name = "${local.name_prefix}-ddb-rw"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
        "dynamodb:Scan", "dynamodb:Query", "dynamodb:DeleteItem"
      ],
      Resource = [
        "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.connections_table}",
        "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.orders_table}"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ddb_rw" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ddb_rw.arn
}

# Permiso para responder por WebSocket (callback)
resource "aws_iam_policy" "manage_connections" {
  name = "${local.name_prefix}-manage-connections"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["execute-api:ManageConnections"],
      Resource = "arn:aws:execute-api:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*/@connections/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_manage_connections" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.manage_connections.arn
}

# Publicar a ambos SNS
resource "aws_iam_policy" "sns_publish" {
  name = "${local.name_prefix}-sns-publish"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sns:Publish"],
      Resource = [var.sns_topic_admin_arn, var.sns_topic_client_arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_sns_publish" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.sns_publish.arn
}

# ────────── onConnect ──────────
data "archive_file" "onconnect_zip" {
  type        = "zip"
  output_path = "${path.module}/build/onconnect.zip"
  source {
    filename = "lambda_function.py"
    content  = <<PY
import os, json, boto3, logging
logger = logging.getLogger(); logger.setLevel("INFO")
ddb = boto3.resource("dynamodb").Table(os.environ["TABLE_CONNECTIONS"])

def lambda_handler(event, context):
    logger.info({"event": event})
    cid = event.get("requestContext", {}).get("connectionId")
    if cid:
        ddb.put_item(Item={"connectionId": cid})
    return {"statusCode": 200, "body": json.dumps({"ok": True})}
PY
  }
}

resource "aws_lambda_function" "onconnect" {
  function_name    = "${local.name_prefix}-onConnect"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.onconnect_zip.output_path
  source_code_hash = data.archive_file.onconnect_zip.output_base64sha256
  timeout          = var.lambda_timeout

  environment {
    variables = {
      TABLE_CONNECTIONS    = var.connections_table
      TABLE_ORDERS         = var.orders_table
      SNS_TOPIC_ADMIN_ARN  = var.sns_topic_admin_arn
      SNS_TOPIC_CLIENT_ARN = var.sns_topic_client_arn
    }
  }
}

# ────────── onDisconnect ──────────
data "archive_file" "ondisconnect_zip" {
  type        = "zip"
  output_path = "${path.module}/build/ondisconnect.zip"
  source {
    filename = "lambda_function.py"
    content  = <<PY
import os, json, boto3, logging
logger = logging.getLogger(); logger.setLevel("INFO")
ddb = boto3.resource("dynamodb").Table(os.environ["TABLE_CONNECTIONS"])

def lambda_handler(event, context):
    logger.info({"event": event})
    cid = event.get("requestContext", {}).get("connectionId")
    if cid:
        ddb.delete_item(Key={"connectionId": cid})
    return {"statusCode": 200, "body": json.dumps({"ok": True})}
PY
  }
}

resource "aws_lambda_function" "ondisconnect" {
  function_name    = "${local.name_prefix}-onDisconnect"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.ondisconnect_zip.output_path
  source_code_hash = data.archive_file.ondisconnect_zip.output_base64sha256
  timeout          = var.lambda_timeout

  environment {
    variables = {
      TABLE_CONNECTIONS    = var.connections_table
      TABLE_ORDERS         = var.orders_table
      SNS_TOPIC_ADMIN_ARN  = var.sns_topic_admin_arn
      SNS_TOPIC_CLIENT_ARN = var.sns_topic_client_arn
    }
  }
}

# ────────── websocketHandler (unificado) ──────────
data "archive_file" "ws_handler_zip" {
  type        = "zip"
  output_path = "${path.module}/build/websocket_handler.zip"
  source {
    filename = "lambda_function.py"
    content  = <<PY
import os, json, boto3, logging
from decimal import Decimal
from datetime import datetime

logger = logging.getLogger(); logger.setLevel("INFO")

ddb = boto3.resource("dynamodb")
ddb_conn = ddb.Table(os.environ["TABLE_CONNECTIONS"])
ddb_ord  = ddb.Table(os.environ["TABLE_ORDERS"])
sns      = boto3.client("sns")

ADMIN_ARN  = os.environ["SNS_TOPIC_ADMIN_ARN"]
CLIENT_ARN = os.environ["SNS_TOPIC_CLIENT_ARN"]

def _mgmt_from_event(event):
    rc = event.get("requestContext", {})
    domain = rc.get("domainName")
    stage  = rc.get("stage")
    if not domain or not stage:
        raise RuntimeError("No domainName/stage en requestContext")
    endpoint = f"https://{domain}/{stage}"
    return boto3.client("apigatewaymanagementapi", endpoint_url=endpoint)

def post_all(event, message: dict):
    mgmt = _mgmt_from_event(event)
    conns = ddb_conn.scan().get("Items", [])
    body  = json.dumps(message)
    for c in conns:
        try:
            mgmt.post_to_connection(ConnectionId=c["connectionId"], Data=body)
        except Exception as e:
            logger.warning(f"post error {c.get('connectionId')}: {e}")

def lambda_handler(event, context):
    logger.info({"event": event})
    try:
        body = event.get("body")
        if isinstance(body, str):
            body = json.loads(body or "{}")
        elif body is None:
            body = {}

        action = body.get("type") or body.get("tipo") or body.get("action")

        if action == "newOrder":
            order_id = "F-" + datetime.utcnow().strftime("%Y-%m-%d-%H-%M-%S")
            ddb_ord.put_item(Item={
                "orderId": order_id,
                "cliente": body.get("cliente","Desconocido"),
                "productos": body.get("productos", []),
                "total": Decimal(str(body.get("total", 0))),
                "estado": "pendiente",
                "fecha": datetime.utcnow().isoformat()
            })
            try:
                sns.publish(TopicArn=ADMIN_ARN, Subject="Nuevo Pedido", Message=json.dumps(body, ensure_ascii=False))
                sns.publish(TopicArn=CLIENT_ARN, Subject="Pedido Recibido", Message=f"ID: {order_id} estado: pendiente")
            except Exception as e:
                logger.warning(f"SNS error: {e}")

            post_all(event, {"type":"newOrder","orderId":order_id, **{k:v for k,v in body.items() if k not in ("type","action","tipo")}})
            return {"statusCode": 200, "body": json.dumps({"ok": True, "orderId": order_id})}

        elif action == "updateOrder":
            order_id = body["orderId"]; estado = body["estado"]
            ddb_ord.update_item(
                Key={"orderId": order_id},
                UpdateExpression="SET #estado = :e",
                ExpressionAttributeNames={"#estado":"estado"},
                ExpressionAttributeValues={":e": estado}
            )
            try:
                sns.publish(TopicArn=CLIENT_ARN, Subject="Actualización de Pedido", Message=f"{order_id} → {estado}")
            except Exception as e:
                logger.warning(f"SNS error: {e}")
            post_all(event, {"type":"orderUpdated","orderId":order_id,"estado":estado})
            return {"statusCode": 200, "body": json.dumps({"ok": True})}

        elif action == "getPedidos":
            scan = ddb_ord.scan().get("Items", [])
            pedidos = [{
                "orderId": i.get("orderId"),
                "cliente": i.get("cliente","Desconocido"),
                "productos": i.get("productos",[]),
                "total": float(i.get("total",0)),
                "estado": i.get("estado","pendiente"),
                "fecha": i.get("fecha","")
            } for i in scan]
            post_all(event, {"type":"allPedidos","pedidos": pedidos})
            return {"statusCode": 200, "body": json.dumps({"ok": True})}

        else:
            return {"statusCode": 400, "body": json.dumps({"error":"Tipo desconocido"})}
    except Exception as e:
        logger.exception("Unhandled")
        return {"statusCode": 500, "body": str(e)}
PY
  }
}

resource "aws_lambda_function" "websocket_handler" {
  function_name    = "${local.name_prefix}-websocketHandler"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.ws_handler_zip.output_path
  source_code_hash = data.archive_file.ws_handler_zip.output_base64sha256
  timeout          = var.lambda_timeout

  environment {
    variables = {
      TABLE_CONNECTIONS    = var.connections_table
      TABLE_ORDERS         = var.orders_table
      SNS_TOPIC_ADMIN_ARN  = var.sns_topic_admin_arn
      SNS_TOPIC_CLIENT_ARN = var.sns_topic_client_arn
    }
  }
}

