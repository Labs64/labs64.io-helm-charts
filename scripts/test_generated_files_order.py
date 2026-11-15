"""The generated files can only be right if the dependencies they are generated from are built first.

helm-schema silently writes nothing for a module chart whose `chart-libs` dependency has not been built (the vendored
charts/*/charts/ are gitignored, so a fresh checkout has none). Run before the build, the generated-files gate passed
on stale schemas for weeks, and the chart-image-update workflow, which generated the schema before it updated the
dependencies, never carried a pinned digest into values.schema.json.

Run: pytest scripts/test_generated_files_order.py -q
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def test_the_image_update_workflow_updates_dependencies_before_it_generates():
    workflow = yaml.safe_load((ROOT / ".github/workflows/labs64io-chart-image-update.yml").read_text(encoding="utf-8"))
    names = [step.get("name", "") for job in workflow["jobs"].values() for step in job.get("steps", [])]
    assert "Update chart dependencies" in names and "Generate values schema" in names
    assert names.index("Pin the released digests") < names.index("Update chart dependencies")
    assert names.index("Update chart dependencies") < names.index("Generate values schema")


def test_generate_schema_builds_the_dependencies_first():
    recipe = re.search(r"^generate-schema:(.*)$", (ROOT / "just/charts.just").read_text(encoding="utf-8"), re.M)
    assert recipe, "recipe generate-schema not found"
    assert "_build-chart-dependencies" in recipe.group(1)
