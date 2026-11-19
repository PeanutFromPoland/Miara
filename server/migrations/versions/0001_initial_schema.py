"""Create initial Miara API schema.

Revision ID: 0001_initial_schema
Revises:
"""
from alembic import op

from app.db import Base
from app import models  # noqa: F401: register mapped tables on Base.metadata

revision = "0001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    Base.metadata.create_all(bind=op.get_bind())


def downgrade():
    Base.metadata.drop_all(bind=op.get_bind())
