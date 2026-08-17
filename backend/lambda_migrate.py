"""Lambda entrypoint for running migrations (and, optionally, seeding)
against RDS.

RDS sits in a private subnet with no path in from outside the VPC (see
infra/rds.tf) - not from your laptop, not from anywhere but inside the VPC
itself. This is that "inside the VPC" runner: same container image as
lambda_handler.py, just a different entrypoint (see infra/lambda.tf's
image_config.command override), invoked manually and on-demand via
`aws lambda invoke`, never wired to API Gateway.

Seeding piggybacks on this same function rather than getting its own
Lambda resource - it's a rare, manual, dev-only action, not worth a third
always-on function/role/log-group for. Pass {"seed": true} as the invoke
payload to also run seed.py after migrating.
"""

from pathlib import Path

from alembic import command
from alembic.config import Config


def handler(event, context):
    alembic_cfg = Config(str(Path(__file__).parent / "alembic.ini"))
    command.upgrade(alembic_cfg, "head")

    if event.get("seed"):
        import seed

        seed.main()

    return {"status": "ok"}
