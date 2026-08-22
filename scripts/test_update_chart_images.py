"""Tests for the chart digest updater.

Synthetic charts throughout — these pin the RULES (all-or-nothing, idempotency,
comment preservation, bump semantics), not today's fleet state. The real charts
are exercised separately by the round-trip test at the bottom, which runs the
updater against a copy of the actual auditflow chart and re-renders it with
`helm template` to prove the written digest reaches the manifest.

Run: pytest scripts/test_update_chart_images.py -q
"""

from __future__ import annotations

import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

SCRIPT = Path(__file__).parent / "update-chart-images.py"
_spec = importlib.util.spec_from_file_location("update_chart_images", SCRIPT)
upd = importlib.util.module_from_spec(_spec)
sys.modules["update_chart_images"] = upd
_spec.loader.exec_module(upd)

REPO_ROOT = Path(__file__).resolve().parent.parent

D1 = "sha256:" + "1" * 64
D2 = "sha256:" + "2" * 64
D3 = "sha256:" + "3" * 64

CHART_YAML = """apiVersion: v2
name: demo
type: application
version: 0.4.0
appVersion: 0.0.1
description: "demo chart"
"""

VALUES_YAML = """# -- replica count
replicaCount: 1

# -- This sets the container image
image:
  repository: labs64/demo
  # -- pull policy
  pullPolicy: IfNotPresent
  # -- Overrides the image tag whose default is the chart appVersion.
  tag: ""
  # -- Pin the image by digest.
  digest: ""

sidecar:
  image:
    repository: labs64/demo-sidecar
    pullPolicy: IfNotPresent
    tag: ""
    digest: ""
  service:
    port: 8081

service:
  port: 8080
"""


def make_chart(tmp_path: Path, chart: str = CHART_YAML, values: str = VALUES_YAML) -> Path:
    d = tmp_path / "demo"
    d.mkdir()
    (d / "Chart.yaml").write_text(chart)
    (d / "values.yaml").write_text(values)
    return d


# --- happy path -----------------------------------------------------------------


def test_writes_all_digests_appversion_and_bumps_patch(tmp_path):
    d = make_chart(tmp_path)
    result = upd.update_chart(
        d, "1.4.0", {"labs64/demo": D1, "labs64/demo-sidecar": D2}
    )
    assert result.changed
    values = yaml.safe_load((d / "values.yaml").read_text())
    chart = yaml.safe_load((d / "Chart.yaml").read_text())
    assert values["image"]["digest"] == D1
    assert values["sidecar"]["image"]["digest"] == D2
    assert chart["appVersion"] == "1.4.0"
    assert chart["version"] == "0.4.1"


def test_bump_minor_and_none(tmp_path):
    d = make_chart(tmp_path)
    upd.update_chart(d, "1.4.0", {"labs64/demo": D1, "labs64/demo-sidecar": D2}, bump="minor")
    assert yaml.safe_load((d / "Chart.yaml").read_text())["version"] == "0.5.0"

    second = tmp_path / "second"
    second.mkdir()
    d2 = make_chart(second)
    upd.update_chart(d2, "1.4.0", {"labs64/demo": D1, "labs64/demo-sidecar": D2}, bump="none")
    assert yaml.safe_load((d2 / "Chart.yaml").read_text())["version"] == "0.4.0"


def test_preserves_comments_and_layout(tmp_path):
    d = make_chart(tmp_path)
    upd.update_chart(d, "1.4.0", {"labs64/demo": D1, "labs64/demo-sidecar": D2})
    text = (d / "values.yaml").read_text()
    assert "# -- replica count" in text
    assert "# -- Overrides the image tag whose default is the chart appVersion." in text
    assert "# -- Pin the image by digest." in text
    # untouched keys keep their exact lines
    assert "  pullPolicy: IfNotPresent\n" in text
    assert '  tag: ""\n' in text
    # only the digest lines changed
    before = VALUES_YAML.splitlines()
    after = text.splitlines()
    assert len(before) == len(after)
    differing = [(b, a) for b, a in zip(before, after) if b != a]
    assert len(differing) == 2
    assert all("digest:" in a for _, a in differing)


# --- idempotency ----------------------------------------------------------------


def test_replayed_event_is_a_noop_and_does_not_bump_again(tmp_path):
    d = make_chart(tmp_path)
    images = {"labs64/demo": D1, "labs64/demo-sidecar": D2}
    first = upd.update_chart(d, "1.4.0", images)
    assert first.changed
    assert yaml.safe_load((d / "Chart.yaml").read_text())["version"] == "0.4.1"

    second = upd.update_chart(d, "1.4.0", images)
    assert not second.changed
    assert yaml.safe_load((d / "Chart.yaml").read_text())["version"] == "0.4.1"


def test_changing_one_digest_still_bumps(tmp_path):
    d = make_chart(tmp_path)
    upd.update_chart(d, "1.4.0", {"labs64/demo": D1, "labs64/demo-sidecar": D2})
    result = upd.update_chart(d, "1.4.0", {"labs64/demo": D3, "labs64/demo-sidecar": D2})
    assert result.changed
    assert yaml.safe_load((d / "Chart.yaml").read_text())["version"] == "0.4.2"


# --- all-or-nothing -------------------------------------------------------------


def test_partial_first_party_set_is_rejected(tmp_path):
    d = make_chart(tmp_path)
    with pytest.raises(upd.UpdateError) as exc:
        upd.update_chart(d, "1.4.0", {"labs64/demo": D1})
    assert "labs64/demo-sidecar" in str(exc.value)
    # nothing was written
    assert yaml.safe_load((d / "values.yaml").read_text())["image"]["digest"] == ""


def test_allow_partial_opts_out(tmp_path):
    d = make_chart(tmp_path)
    result = upd.update_chart(d, "1.4.0", {"labs64/demo": D1}, allow_partial=True)
    assert result.changed
    values = yaml.safe_load((d / "values.yaml").read_text())
    assert values["image"]["digest"] == D1
    assert values["sidecar"]["image"]["digest"] == ""


def test_third_party_images_are_not_required(tmp_path):
    values = VALUES_YAML.replace("repository: labs64/demo-sidecar", "repository: ghcr.io/cerbos/cerbos")
    d = make_chart(tmp_path, values=values)
    result = upd.update_chart(d, "1.4.0", {"labs64/demo": D1})
    assert result.changed


# --- failure modes --------------------------------------------------------------


def test_unknown_repository_is_rejected(tmp_path):
    d = make_chart(tmp_path)
    with pytest.raises(upd.UpdateError) as exc:
        upd.update_chart(d, "1.4.0", {"labs64/nope": D1, "labs64/demo": D1, "labs64/demo-sidecar": D2})
    assert "labs64/nope" in str(exc.value)


def test_block_without_digest_key_is_rejected(tmp_path):
    values = VALUES_YAML.replace('  # -- Pin the image by digest.\n  digest: ""\n', "")
    d = make_chart(tmp_path, values=values)
    with pytest.raises(upd.UpdateError) as exc:
        upd.update_chart(d, "1.4.0", {"labs64/demo": D1, "labs64/demo-sidecar": D2})
    assert "chart-libs >= 0.3.0" in str(exc.value)


def test_digest_of_a_later_block_is_not_stolen(tmp_path):
    """A block missing its own digest must fail, not silently take the next block's."""
    values = """image:
  repository: labs64/demo
  tag: ""

sidecar:
  image:
    repository: labs64/demo-sidecar
    tag: ""
    digest: ""
"""
    d = make_chart(tmp_path, values=values)
    with pytest.raises(upd.UpdateError):
        upd.update_chart(d, "1.4.0", {"labs64/demo": D1}, allow_partial=True)


@pytest.mark.parametrize(
    "bad",
    [
        "labs64/demo@sha256:tooshort",
        "labs64/demo@sha256:" + "A" * 64,  # uppercase
        "labs64/demo@" + "1" * 64,  # no algorithm
        "labs64/demo",  # no digest at all
        "@" + "sha256:" + "1" * 64,  # no repository
    ],
)
def test_malformed_image_args_are_rejected(bad):
    with pytest.raises(upd.UpdateError):
        upd.parse_image_arg(bad)


def test_bad_app_version_is_rejected(tmp_path):
    d = make_chart(tmp_path)
    with pytest.raises(upd.UpdateError):
        upd.update_chart(d, "not-a-version", {"labs64/demo": D1, "labs64/demo-sidecar": D2})


def test_non_semver_chart_version_cannot_be_bumped(tmp_path):
    d = make_chart(tmp_path, chart=CHART_YAML.replace("version: 0.4.0", "version: weird"))
    with pytest.raises(upd.UpdateError):
        upd.update_chart(d, "1.4.0", {"labs64/demo": D1, "labs64/demo-sidecar": D2})


def test_appversion_is_quoted_so_yaml_cannot_read_it_as_a_float(tmp_path):
    d = make_chart(tmp_path, chart=CHART_YAML.replace("version: 0.4.0", "version: 1.9.0"))
    upd.update_chart(d, "1.10.0", {"labs64/demo": D1, "labs64/demo-sidecar": D2})
    text = (d / "Chart.yaml").read_text()
    chart = yaml.safe_load(text)
    assert chart["appVersion"] == "1.10.0"   # not the float 1.1
    assert chart["version"] == "1.9.1"
    # appVersion is quoted because it is free-form; chart version is bare, matching
    # how every Chart.yaml in this repo is written.
    assert 'appVersion: "1.10.0"\n' in text
    assert "version: 1.9.1\n" in text


# --- CLI ------------------------------------------------------------------------


def run_cli(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args], capture_output=True, text=True
    )


def test_check_mode_reports_without_writing(tmp_path):
    charts = tmp_path / "charts"
    charts.mkdir()
    d = make_chart(charts)
    proc = run_cli(
        "--charts-dir", str(charts), "--chart", "demo", "--app-version", "1.4.0",
        "--image", f"labs64/demo@{D1}", "--image", f"labs64/demo-sidecar@{D2}", "--check",
    )
    assert proc.returncode == 1, proc.stderr
    assert "would change" in proc.stdout
    assert yaml.safe_load((d / "values.yaml").read_text())["image"]["digest"] == ""


def test_check_mode_exits_zero_when_already_pinned(tmp_path):
    charts = tmp_path / "charts"
    charts.mkdir()
    make_chart(charts)
    args = [
        "--charts-dir", str(charts), "--chart", "demo", "--app-version", "1.4.0",
        "--image", f"labs64/demo@{D1}", "--image", f"labs64/demo-sidecar@{D2}",
    ]
    assert run_cli(*args).returncode == 0
    proc = run_cli(*args, "--check")
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "nothing to do" in proc.stdout


def test_unknown_chart_lists_available_ones(tmp_path):
    charts = tmp_path / "charts"
    charts.mkdir()
    make_chart(charts)
    proc = run_cli(
        "--charts-dir", str(charts), "--chart", "ghost", "--app-version", "1.0.0",
        "--image", f"labs64/demo@{D1}",
    )
    assert proc.returncode == 2
    assert "demo" in proc.stderr


# --- release event payload (untrusted input) ------------------------------------


def write_event(tmp_path: Path, payload) -> Path:
    p = tmp_path / "event.json"
    p.write_text(json.dumps(payload))
    return p


def valid_payload(**overrides):
    payload = {
        "chart": "demo",
        "version": "1.4.0",
        "bump": "patch",
        "images": [
            {"image": "labs64/demo", "digest": D1},
            {"image": "labs64/demo-sidecar", "digest": D2},
        ],
    }
    payload.update(overrides)
    return payload


def test_event_payload_round_trips(tmp_path):
    event = upd.load_event(write_event(tmp_path, valid_payload()))
    assert event.chart == "demo"
    assert event.version == "1.4.0"
    assert event.bump == "patch"
    assert event.images == {"labs64/demo": D1, "labs64/demo-sidecar": D2}


def test_event_bump_defaults_to_patch(tmp_path):
    payload = valid_payload()
    del payload["bump"]
    assert upd.load_event(write_event(tmp_path, payload)).bump == "patch"


@pytest.mark.parametrize(
    "payload",
    [
        valid_payload(chart="../../etc"),          # path traversal
        valid_payload(chart="demo; rm -rf /"),     # shell metacharacters
        valid_payload(chart="Demo"),               # not a plain chart name
        valid_payload(chart=""),
        valid_payload(chart=123),
        valid_payload(version=""),
        valid_payload(version=None),
        valid_payload(bump="wat"),
        valid_payload(images=[]),
        valid_payload(images="labs64/demo"),
        valid_payload(images=[{"image": "labs64/demo"}]),                    # no digest
        valid_payload(images=[{"image": "labs64/demo", "digest": "latest"}]),
        valid_payload(images=[{"digest": D1}]),                              # no image
        valid_payload(images=["labs64/demo@" + D1]),                         # wrong shape
        valid_payload(images=[{"image": "labs64/demo", "digest": D1},
                              {"image": "labs64/demo", "digest": D2}]),      # conflicting
    ],
)
def test_malformed_event_payloads_are_rejected(tmp_path, payload):
    with pytest.raises(upd.UpdateError):
        upd.load_event(write_event(tmp_path, payload))


def test_event_file_that_is_not_json_is_rejected(tmp_path):
    p = tmp_path / "event.json"
    p.write_text("not json at all")
    with pytest.raises(upd.UpdateError):
        upd.load_event(p)


def test_cli_event_file_updates_the_chart(tmp_path):
    charts = tmp_path / "charts"
    charts.mkdir()
    d = make_chart(charts)
    event = write_event(tmp_path, valid_payload())
    proc = run_cli("--charts-dir", str(charts), "--event-file", str(event))
    assert proc.returncode == 0, proc.stderr
    values = yaml.safe_load((d / "values.yaml").read_text())
    assert values["image"]["digest"] == D1
    assert yaml.safe_load((d / "Chart.yaml").read_text())["version"] == "0.4.1"


def test_cli_rejects_mixing_event_file_with_flags(tmp_path):
    charts = tmp_path / "charts"
    charts.mkdir()
    make_chart(charts)
    event = write_event(tmp_path, valid_payload())
    proc = run_cli(
        "--charts-dir", str(charts), "--event-file", str(event), "--chart", "demo"
    )
    assert proc.returncode == 2
    assert "replaces" in proc.stderr


def test_cli_event_for_unknown_chart_fails_without_writing(tmp_path):
    charts = tmp_path / "charts"
    charts.mkdir()
    make_chart(charts)
    event = write_event(tmp_path, valid_payload(chart="ghost"))
    proc = run_cli("--charts-dir", str(charts), "--event-file", str(event))
    assert proc.returncode == 2
    assert "ghost" in proc.stderr


# --- round trip against the real chart ------------------------------------------


@pytest.mark.skipif(shutil.which("helm") is None, reason="helm not installed")
def test_real_auditflow_chart_renders_by_digest_after_update(tmp_path):
    """The written value must actually reach the rendered manifest.

    Guards the seam between this script and chart-libs: a digest written to a key
    the templates ignore would look like success everywhere except the cluster.
    """
    src = REPO_ROOT / "charts" / "auditflow"
    chart = tmp_path / "auditflow"
    shutil.copytree(src, chart)

    libs_src = REPO_ROOT / "charts" / "chart-libs"
    libs_chart = tmp_path / "chart-libs"
    if libs_src.exists():
        shutil.copytree(libs_src, libs_chart)
    
    subprocess.run(
        ["helm", "dependency", "build", str(chart)],
        capture_output=True,
        check=True,
    )

    upd.update_chart(
        chart,
        "9.9.9",
        {
            "labs64/auditflow": D1,
            "labs64/auditflow-transformer": D2,
            "labs64/auditflow-sink": D3,
        },
    )

    proc = subprocess.run(
        ["helm", "template", "t", str(chart)], capture_output=True, text=True
    )
    assert proc.returncode == 0, proc.stderr
    assert f"labs64/auditflow@{D1}" in proc.stdout
    assert f"labs64/auditflow-transformer@{D2}" in proc.stdout
    assert f"labs64/auditflow-sink@{D3}" in proc.stdout
    assert "labs64/auditflow:9.9.9" not in proc.stdout
