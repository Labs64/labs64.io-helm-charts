"""The Auth Gateway must remove `Authorization` after it has used it.

RFC_03 Principle 1: modules never see the caller's JWT. Native Gateway API filters run before
ExtensionRef filters (ForwardAuth), so the removal has to live inside the `-auth` Middleware
every non-public module route references. Rendering the chart pins three things: `-auth` is a
chain, ForwardAuth comes before the removal (it needs the token), and the removal really
deletes the header (an empty value).

Run: pytest scripts/test_authgateway_strip_authorization.py -q
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

CHART = Path(__file__).parent.parent / "charts" / "authgateway"

pytestmark = pytest.mark.skipif(shutil.which("helm") is None, reason="helm is not installed")


def middlewares() -> dict[str, dict]:
    out = subprocess.run(
        ["helm", "template", "t", str(CHART)], check=True, capture_output=True, text=True
    ).stdout
    docs = [d for d in yaml.safe_load_all(out) if d and d.get("kind") == "Middleware"]
    return {d["metadata"]["name"]: d["spec"] for d in docs}


def test_auth_is_a_chain_that_runs_forwardauth_before_the_removal():
    chain = middlewares()["authgateway-auth"]["chain"]["middlewares"]
    assert [m["name"] for m in chain] == ["authgateway-forwardauth", "authgateway-strip-authorization"]


def test_the_removal_deletes_authorization():
    assert middlewares()["authgateway-strip-authorization"]["headers"]["customRequestHeaders"] == {"Authorization": ""}


def test_forwardauth_still_hands_the_identity_headers_on():
    forward = middlewares()["authgateway-forwardauth"]["forwardAuth"]
    assert {"X-Auth-User", "X-Auth-Scopes", "X-Auth-Tenant"} <= set(forward["authResponseHeaders"])
