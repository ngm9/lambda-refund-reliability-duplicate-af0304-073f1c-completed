import json
import logging
import os
import time
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

BUCKET = os.environ["SETTLEMENT_BUCKET"]
TABLE_NAME = os.environ["LEDGER_TABLE"]

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
ledger = dynamodb.Table(TABLE_NAME)


def _required_string(payload, name):
    value = payload.get(name)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{name} is required")
    return value.strip()


def _validate_refund(payload):
    refund_id = _required_string(payload, "refund_id")
    order_id = _required_string(payload, "order_id")
    account_id = _required_string(payload, "customer_account_id")
    currency = _required_string(payload, "currency")
    reason = _required_string(payload, "reason")
    requested_at = _required_string(payload, "requested_at")

    amount_cents = payload.get("amount_cents")
    if not isinstance(amount_cents, int) or amount_cents <= 0:
        raise ValueError("amount_cents must be a positive integer")
    if currency != "USD":
        raise ValueError("only USD refunds are supported in this local workflow")

    delay_ms = payload.get("processing_delay_ms", 0)
    if not isinstance(delay_ms, int) or delay_ms < 0:
        raise ValueError("processing_delay_ms must be a non-negative integer")

    return {
        "refund_id": refund_id,
        "order_id": order_id,
        "customer_account_id": account_id,
        "amount_cents": amount_cents,
        "currency": currency,
        "reason": reason,
        "requested_at": requested_at,
        "processing_delay_ms": delay_ms,
        "correlation_id": payload.get("correlation_id", ""),
    }


def _settle_refund(refund, message_id):
    delay_ms = refund.get("processing_delay_ms", 0)
    if delay_ms:
        time.sleep(min(delay_ms / 1000.0, 6.0))

    now = datetime.now(timezone.utc).isoformat()
    settlement_id = f"set-{refund['refund_id']}-{message_id}-{uuid.uuid4().hex[:10]}"
    object_key = f"settlements/{refund['refund_id']}/{settlement_id}.json"

    document = {
        "settlement_id": settlement_id,
        "refund_id": refund["refund_id"],
        "order_id": refund["order_id"],
        "customer_account_id": refund["customer_account_id"],
        "amount_cents": refund["amount_cents"],
        "currency": refund["currency"],
        "reason": refund["reason"],
        "requested_at": refund["requested_at"],
        "settled_at": now,
        "source_message_id": message_id,
        "correlation_id": refund.get("correlation_id", ""),
        "status": "SETTLED",
    }

    s3.put_object(
        Bucket=BUCKET,
        Key=object_key,
        Body=json.dumps(document, separators=(",", ":")).encode("utf-8"),
        ContentType="application/json",
    )

    ledger.put_item(
        Item={
            "settlement_id": settlement_id,
            "refund_id": refund["refund_id"],
            "order_id": refund["order_id"],
            "amount_cents": Decimal(refund["amount_cents"]),
            "currency": refund["currency"],
            "settled_at": now,
            "s3_key": object_key,
            "source_message_id": message_id,
            "correlation_id": refund.get("correlation_id", ""),
            "status": "SETTLED",
        }
    )

    logger.info("settled refund message %s", message_id)
    return settlement_id


def lambda_handler(event, context):
    records = event.get("Records", [])
    logger.info("received batch with %s records", len(records))

    processed = []
    for record in records:
        message_id = record.get("messageId", "unknown")
        payload = json.loads(record.get("body", "{}"))
        refund = _validate_refund(payload)
        settlement_id = _settle_refund(refund, message_id)
        processed.append(settlement_id)

    logger.info("completed batch with %s settlements", len(processed))
    return {"processed": len(processed), "settlement_ids": processed}
