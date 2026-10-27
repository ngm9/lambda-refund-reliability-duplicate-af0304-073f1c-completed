## Task Overview

This project models a marketplace refund-settlement pipeline running on real AWS Lambda, SQS, S3, and DynamoDB in your own leased sandbox account. Refund requests are consumed in batches and the worker records settlement evidence for downstream finance operations. The pipeline has been in use for a few weeks and the basic happy path works. Recently, a few of the teams that depend on it have reported behaviour that does not match what they expect from a system that moves money. Their reports are listed under Objectives. Your job is to look into each one and harden the workflow so the business outcome stays correct.

## Objectives

- The finance team was reconciling last week's payouts and noticed that one customer had been refunded twice for a single order. This should not happen.
- The QA team was running a routine batch of refund requests and noticed that when one request in the batch was bad, the good ones next to it did not go through either.
- The operations team went looking for the bad request that caused that batch to stall and could not find it anywhere.
- The QA team noticed that a refund that takes a little longer than usual to process ended up being paid out more than once.
- The on-call engineer tried to follow a single refund through the system while investigating the above and found it was not possible to tell which log lines and records belonged to it.

## Helpful Tips

- Get the stack running and watch a normal refund go through end to end before you touch anything.
- Reproduce what each team saw before deciding what to change.
- Think about what correct means for a system that moves money, not just whether the code runs without errors.
- Whatever you change should still be checkable by hand afterwards.

## How to Verify

- Sending the same refund request more than once should result in that customer being refunded exactly once, with a single record of it.
- A batch that contains one bad request should still get every good request in it paid out, once each.
- A bad request that cannot be processed should stop coming back around, and an operator should be able to find it and see exactly what was sent.
- A refund that takes longer than usual to process should still be paid out exactly once.
- Picking any one refund should let you find every log line and every stored record that belongs to it.
- The scripts under `tests/` exercise these behaviours once `build.sh` reports the stack is ready.
