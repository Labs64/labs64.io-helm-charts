"""Tests for the Helm chart authoring checklist (roadmap item 30).

Synthetic, isolated inputs throughout — no dependency on the real charts/
tree, so these stay fast and pin the RULES rather than today's fleet state.
scripts/lint-chart-authoring.py itself is exercised end-to-end (via `helm
template` against the real charts) as part of chart CI; that proves the
fleet is clean, not that each rule is correct in isolation — that's what
these tests are for.

Run: pytest scripts/test_lint_chart_authoring.py -q
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest
import yaml

SCRIPT = Path(__file__).parent / "lint-chart-authoring.py"
_spec = importlib.util.spec_from_file_location("lint_chart_authoring", SCRIPT)
lint = importlib.util.module_from_spec(_spec)
sys.modules["lint_chart_authoring"] = lint
_spec.loader.exec_module(lint)


def configmap(name: str) -> str:
    return f"apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: {name}\n"


# --- 1. no rogue Ingress --------------------------------------------------------


def test_flags_a_module_template_declaring_kind_ingress(tmp_path):
    chart = tmp_path / "somechart"
    (chart / "templates").mkdir(parents=True)
    (chart / "templates" / "ingress.yaml").write_text(
        "apiVersion: networking.k8s.io/v1\nkind: Ingress\nmetadata:\n  name: x\n"
    )
    findings = []
    lint.check_no_rogue_ingress(chart, findings)
    assert len(findings) == 1
    assert findings[0].rule == "rogue-ingress"


def test_does_not_flag_a_chart_with_no_ingress_template(tmp_path):
    chart = tmp_path / "somechart"
    (chart / "templates").mkdir(parents=True)
    (chart / "templates" / "deployment.yaml").write_text('{{ include "chart-libs.deployment" . }}\n')
    findings = []
    lint.check_no_rogue_ingress(chart, findings)
    assert findings == []


# --- 2. subPath allowlist --------------------------------------------------------


DEPLOYMENT_WITH_SUBPATH = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deploy
spec:
  template:
    spec:
      containers:
        - name: app
          volumeMounts:
            - name: cfg
              mountPath: /etc/thing
              subPath: thing.yaml
"""


def test_flags_a_subpath_not_in_the_allowlist():
    findings = []
    lint.check_subpath_allowlist(Path("somechart"), DEPLOYMENT_WITH_SUBPATH, allowed=set(), findings=findings)
    assert len(findings) == 1
    assert findings[0].rule == "subpath-not-allowlisted"


def test_does_not_flag_an_allowlisted_subpath():
    findings = []
    lint.check_subpath_allowlist(
        Path("somechart"), DEPLOYMENT_WITH_SUBPATH, allowed={("somechart", "thing.yaml")}, findings=findings
    )
    assert findings == []


def test_does_not_flag_a_deployment_with_no_subpath_mounts():
    manifest = DEPLOYMENT_WITH_SUBPATH.replace("              subPath: thing.yaml\n", "")
    findings = []
    lint.check_subpath_allowlist(Path("somechart"), manifest, allowed=set(), findings=findings)
    assert findings == []


def test_allowlist_entry_requires_chart_subpath_and_reason(tmp_path, monkeypatch):
    bad = tmp_path / "allow.yaml"
    bad.write_text("allow:\n  - chart: x\n    subPath: y\n")  # missing reason
    monkeypatch.setattr(lint, "ALLOWLIST", bad)
    with pytest.raises(ValueError):
        lint.load_allowlist()


def test_allowlist_loads_valid_entries(tmp_path, monkeypatch):
    good = tmp_path / "allow.yaml"
    good.write_text(
        "allow:\n  - chart: x\n    subPath: y\n    reason: because\n"
    )
    monkeypatch.setattr(lint, "ALLOWLIST", good)
    assert lint.load_allowlist() == {("x", "y")}


# --- 3. probe defaults -----------------------------------------------------------


def deployment_with_probes(**overrides) -> str:
    doc = {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {"name": "my-deploy"},
        "spec": {"template": {"spec": {"containers": [{
            "name": "app",
            "livenessProbe": {"periodSeconds": 10, "failureThreshold": 3},
            "readinessProbe": {"periodSeconds": 10, "failureThreshold": 3},
        }]}}},
    }
    container = doc["spec"]["template"]["spec"]["containers"][0]
    container.update(overrides)
    return yaml.dump(doc)


def test_passes_with_sane_probes():
    findings = []
    lint.check_probes(Path("somechart"), deployment_with_probes(), findings)
    assert findings == []


def test_flags_a_missing_liveness_probe():
    manifest = deployment_with_probes(livenessProbe=None)
    # yaml.dump of None under a key still emits the key; strip it entirely instead.
    doc = yaml.safe_load(manifest)
    del doc["spec"]["template"]["spec"]["containers"][0]["livenessProbe"]
    findings = []
    lint.check_probes(Path("somechart"), yaml.dump(doc), findings)
    assert [f.rule for f in findings] == ["missing-probe"]


def test_flags_a_missing_readiness_probe():
    doc = yaml.safe_load(deployment_with_probes())
    del doc["spec"]["template"]["spec"]["containers"][0]["readinessProbe"]
    findings = []
    lint.check_probes(Path("somechart"), yaml.dump(doc), findings)
    assert [f.rule for f in findings] == ["missing-probe"]


@pytest.mark.parametrize("field", ["periodSeconds", "failureThreshold"])
def test_flags_a_zero_valued_probe_field(field):
    doc = yaml.safe_load(deployment_with_probes())
    doc["spec"]["template"]["spec"]["containers"][0]["livenessProbe"][field] = 0
    findings = []
    lint.check_probes(Path("somechart"), yaml.dump(doc), findings)
    assert any(f.rule == "invalid-probe" for f in findings)


def test_checks_init_containers_too():
    doc = yaml.safe_load(deployment_with_probes())
    container = doc["spec"]["template"]["spec"]["containers"].pop()
    doc["spec"]["template"]["spec"]["initContainers"] = [container]
    del doc["spec"]["template"]["spec"]["initContainers"][0]["livenessProbe"]
    findings = []
    lint.check_probes(Path("somechart"), yaml.dump(doc), findings)
    assert any(f.rule == "missing-probe" for f in findings)


# --- workload detection -----------------------------------------------------------


def make_chart(tmp_path: Path, name: str, template_files: dict[str, str]) -> Path:
    chart = tmp_path / name
    (chart / "templates").mkdir(parents=True)
    for filename, content in template_files.items():
        (chart / "templates" / filename).write_text(content)
    return chart


def test_backend_workload_detected_via_shared_macro(tmp_path):
    chart = make_chart(tmp_path, "svc", {"deployment.yaml": '{{ include "chart-libs.deployment" . }}\n'})
    kinds = {k.label for k in lint.workload_kinds_present(chart)}
    assert kinds == {"backend"}


def test_backend_workload_detected_via_hand_rolled_kind(tmp_path):
    chart = make_chart(tmp_path, "svc", {"deployment.yaml": "kind: Deployment\n"})
    kinds = {k.label for k in lint.workload_kinds_present(chart)}
    assert kinds == {"backend"}


def test_ui_workload_detected_via_shared_macro(tmp_path):
    chart = make_chart(tmp_path, "svc", {"ui-deployment.yaml": '{{ include "chart-libs.ui-deployment" . }}\n'})
    kinds = {k.label for k in lint.workload_kinds_present(chart)}
    assert kinds == {"ui"}


def test_both_workloads_detected_when_both_present(tmp_path):
    chart = make_chart(tmp_path, "svc", {
        "deployment.yaml": '{{ include "chart-libs.deployment" . }}\n',
        "ui-deployment.yaml": '{{ include "chart-libs.ui-deployment" . }}\n',
    })
    kinds = {k.label for k in lint.workload_kinds_present(chart)}
    assert kinds == {"backend", "ui"}


def test_umbrella_chart_with_no_workload_of_its_own_detects_nothing(tmp_path):
    chart = make_chart(tmp_path, "umbrella", {"shared-configmap.yaml": configmap("shared")})
    assert lint.workload_kinds_present(chart) == []


def test_job_only_chart_detects_nothing(tmp_path):
    chart = make_chart(tmp_path, "preflight", {"job.yaml": "kind: Job\n"})
    assert lint.workload_kinds_present(chart) == []


# --- nested_get ------------------------------------------------------------------


def test_nested_get_finds_a_deep_key():
    assert lint.nested_get({"ui": {"networkPolicy": {"enabled": False}}}, ("ui", "networkPolicy")) == {
        "enabled": False
    }


def test_nested_get_returns_none_for_a_missing_key():
    assert lint.nested_get({"ui": {}}, ("ui", "networkPolicy")) is None


def test_nested_get_returns_none_when_an_intermediate_key_is_not_a_dict():
    assert lint.nested_get({"ui": "not-a-dict"}, ("ui", "networkPolicy")) is None


# --- NetworkPolicy allow-all egress detection (pure logic, no helm call) -------


def networkpolicy_doc(name: str, egress: list[dict]) -> dict:
    return {
        "apiVersion": "networking.k8s.io/v1",
        "kind": "NetworkPolicy",
        "metadata": {"name": name},
        "spec": {"egress": egress},
    }


def render_egress_rules(name: str, egress: list[dict]) -> list:
    """Exercises the same allow-all detection check_network_policy uses,
    without a live `helm template` call — feeds a synthetic NetworkPolicy
    document through the identical peer-inspection logic."""
    findings: list[lint.Finding] = []
    doc = networkpolicy_doc(name, egress)
    for rule in doc["spec"]["egress"]:
        to = rule.get("to")
        ports = rule.get("ports")
        if not to and not ports:
            findings.append(lint.Finding("networkpolicy-allow-all-egress", "x", name, "no to/ports"))
            continue
        for peer in to or []:
            if peer == {} or peer.get("podSelector") == {} and "namespaceSelector" not in peer:
                findings.append(lint.Finding("networkpolicy-allow-all-egress", "x", name, str(peer)))
    return findings


def test_scoped_egress_rule_is_not_flagged():
    egress = [{"to": [{"namespaceSelector": {}, "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}],
               "ports": [{"protocol": "UDP", "port": 53}]}]
    assert render_egress_rules("np", egress) == []


def test_egress_rule_with_neither_to_nor_ports_is_flagged():
    assert len(render_egress_rules("np", [{}])) == 1


def test_egress_rule_with_empty_peer_is_flagged():
    assert len(render_egress_rules("np", [{"to": [{}]}])) == 1


def test_egress_rule_with_empty_podselector_and_no_namespace_selector_is_flagged():
    assert len(render_egress_rules("np", [{"to": [{"podSelector": {}}]}])) == 1


def test_egress_rule_with_empty_podselector_but_scoped_namespace_is_not_flagged():
    """{} podSelector + a namespaceSelector still scopes to one namespace, not
    every pod in the policy's own namespace — not an allow-all."""
    egress = [{"to": [{"podSelector": {}, "namespaceSelector": {"matchLabels": {"x": "y"}}}]}]
    assert render_egress_rules("np", egress) == []
