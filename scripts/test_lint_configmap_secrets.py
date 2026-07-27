"""Tests for the ConfigMap credential linter.

A linter that reports "clean" is only trustworthy if it is proven to fail on a
planted credential. These tests are that proof, and they guard the heuristics
against being loosened by accident.

Run: pytest scripts/test_lint_configmap_secrets.py
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parent / "lint-configmap-secrets.py"
_spec = importlib.util.spec_from_file_location("lint_configmap_secrets", SCRIPT)
lint = importlib.util.module_from_spec(_spec)
sys.modules["lint_configmap_secrets"] = lint
_spec.loader.exec_module(lint)


def scan(manifest: str):
    return lint.scan_manifests(manifest, chart="testchart", label="values.yaml")


def configmap(data_block: str) -> str:
    return f"""
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-cm
data:
{data_block}
"""


# --- must fail: real credentials ---------------------------------------------


def test_flags_plain_password_key():
    findings = scan(configmap('  SPRING_DATASOURCE_PASSWORD: "hunter2"'))
    assert len(findings) == 1
    assert findings[0].rule == "secret-shaped key"


@pytest.mark.parametrize(
    "key",
    [
        "PASSWORD",
        "spring.rabbitmq.password",
        "API_KEY",
        "apiKey",
        "client_secret",
        "AWS_SECRET_ACCESS_KEY",
        "auth_token",
        "PASSPHRASE",
    ],
)
def test_flags_credential_key_names(key):
    assert scan(configmap(f'  {key}: "s0mething-real"')), f"{key} should be flagged"


def test_flags_credential_nested_in_application_yaml():
    """The real risk surface: an arbitrary tree serialised into one ConfigMap key."""
    manifest = configmap(
        """  application.yaml: |-
    spring:
      rabbitmq:
        host: rabbitmq.tools
        username: auditflow
        password: sup3rs3cret
"""
    )
    findings = scan(manifest)
    assert len(findings) == 1
    assert findings[0].path == "data.application.yaml.spring.rabbitmq.password"


def test_flags_credential_nested_in_list():
    manifest = configmap(
        """  tenant.yaml: |-
    pipelines:
      - sink: webhook
        config:
          apiKey: live-key-abcdef123456
"""
    )
    findings = scan(manifest)
    assert len(findings) == 1
    assert "[0]" in findings[0].path


@pytest.mark.parametrize(
    "value,expected",
    [
        ("postgresql://admin:s3cret@db.internal:5432/app", "URI with embedded credentials"),
        ("AKIAIOSFODNN7EXAMPLE", "AWS access key id"),
        ("-----BEGIN RSA PRIVATE KEY-----\nMIIE...", "PEM private key"),
        ("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.abcdefgh", "JWT"),
        ("ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789", "GitHub token"),
        ("sk_live_abcdefghijklmnop1234", "Stripe secret key"),
    ],
)
def test_flags_credential_value_shapes_under_innocent_key(value, expected):
    """Key name says `url`/`config`; the value is a credential anyway."""
    findings = scan(configmap(f'  connection_url: "{value}"'))
    rules = [f.detail for f in findings if f.rule == "secret-shaped value"]
    assert expected in rules


# --- must pass: references and non-credentials --------------------------------


@pytest.mark.parametrize(
    "key",
    [
        "SPRING_DATASOURCE_PASSWORD_SECRET_NAME",
        "existingSecret",
        "secretName",
        "secretRef",
        "imagePullSecrets",
        "storeName",
    ],
)
def test_ignores_pointers_to_secrets(key):
    """Referencing a Secret is the fix, not the finding."""
    assert not scan(configmap(f'  {key}: "auditflow-creds"'))


@pytest.mark.parametrize(
    "value",
    ["", "<your-password>", "${DB_PASSWORD}", "changeme", "REDACTED", "TBD"],
)
def test_ignores_placeholders(value):
    assert not scan(configmap(f'  password: "{value}"'))


def test_ignores_non_credential_config():
    manifest = configmap(
        """  application.yaml: |-
    spring:
      rabbitmq:
        host: rabbitmq.tools
        port: 5672
        username: auditflow
    server:
      port: 8080
"""
    )
    assert not scan(manifest)


def test_ignores_non_configmap_kinds():
    """Secrets are exactly where these values belong."""
    manifest = """
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
stringData:
  SPRING_DATASOURCE_PASSWORD: "hunter2"
"""
    assert not scan(manifest)


# --- allowlist ----------------------------------------------------------------


def test_allowlist_matches_by_glob():
    finding = lint.Finding(
        chart="auditflow",
        values_file="values.yaml",
        configmap="auditflow-app-ext",
        path="data.application.yaml.some.token",
        rule="secret-shaped key",
        detail="",
    )
    entries = [{"match": "auditflow/*/data.application.yaml.some.*", "reason": "test"}]
    assert lint.allowed(finding, entries)
    assert not lint.allowed(finding, [{"match": "checkout/*", "reason": "test"}])


def test_allowlist_entry_requires_a_reason(tmp_path, monkeypatch):
    bad = tmp_path / "allow.yaml"
    bad.write_text("allow:\n  - match: 'foo/*'\n")
    monkeypatch.setattr(lint, "ALLOWLIST", bad)
    with pytest.raises(ValueError):
        lint.load_allowlist()
