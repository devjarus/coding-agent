"""Structured-ish logging for the service. Use get_logger(__name__)."""
import logging
import sys

_configured = False


def get_logger(name):
    global _configured
    if not _configured:
        h = logging.StreamHandler(sys.stderr)
        h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s"))
        root = logging.getLogger("orders")
        root.addHandler(h)
        root.setLevel(logging.INFO)
        _configured = True
    return logging.getLogger("orders." + name)
