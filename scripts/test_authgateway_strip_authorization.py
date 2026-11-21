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

CHARTS = Path(__file__).parent.parent / "charts"

pytestmark = pytest.mark.skipif(shutil.which("helm") is None, reason="helm is not installed")


@pytest.fixture(scope="module")
def middlewares(tmp_path_factory) -> dict[str, dict]:
    """Render the chart from a scratch copy: the vendored charts/*/charts/ is gitignored, so a clean
    checkout has no chart-libs until `helm dependency build` has run (file:// dependency, offline)."""
    work = tmp_path_factory.mktemp("charts")
    for name in ("chart-libs", "authgateway"):
        shutil.copytree(CHARTS / name, work / name, ignore=shutil.ignore_patterns("charts"))
    chart = work / "authgateway"
    for cmd in (["helm", "dependency", "build", str(chart)], ["helm", "template", "t", str(chart)]):
        done = subprocess.run(cmd, capture_output=True, text=True)
        assert done.returncode == 0, f"{' '.join(cmd)} failed: {done.stderr}"
    docs = [d for d in yaml.safe_load_all(done.stdout) if d and d.get("kind") == "Middleware"]
    return {d["metadata"]["name"]: d["spec"] for d in docs}


def test_auth_is_a_chain_that_runs_forwardauth_before_the_removal(middlewares):
    chain = middlewares["authgateway-auth"]["chain"]["middlewares"]
    assert [m["name"] for m in chain] == ["authgateway-forwardauth", "authgateway-strip-authorization"]


def test_the_removal_deletes_authorization(middlewares):
    assert middlewares["authgateway-strip-authorization"]["headers"]["customRequestHeaders"] == {"Authorization": ""}


def test_forwardauth_still_hands_the_identity_headers_on(middlewares):
    forward = middlewares["authgateway-forwardauth"]["forwardAuth"]
    assert {"X-Auth-User", "X-Auth-Scopes", "X-Auth-Tenant"} <= set(forward["authResponseHeaders"])
