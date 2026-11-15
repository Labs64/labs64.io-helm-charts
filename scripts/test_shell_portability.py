"""Shell that runs on a developer's Mac must work on bash 3.2.

macOS ships bash 3.2, where expanding an empty array under `set -u` is an "unbound variable" error, so
`"${args[@]}"` breaks every run in which `args` stayed empty. The portable form, already used in install.sh, is
`${args[@]+"${args[@]}"}`. CI runs on Linux with bash 5 and never sees the difference.

An array declared empty (`name=()`) must therefore be expanded in the guarded form.

Run: pytest scripts -q   (helm-charts)  /  pytest scripts/tests -q   (workspace)
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] if (Path(__file__).parent.name == "scripts") else Path(__file__).resolve().parents[2]

DECLARED_EMPTY = re.compile(r"(?:^|[\s;{(])([A-Za-z_][A-Za-z0-9_]*)=\(\s*\)", re.M)


def shell_files() -> list[Path]:
    files = [*ROOT.glob("just/*.just"), *ROOT.glob("justfile*"), *ROOT.glob("*.sh"), *ROOT.glob("scripts/*.sh")]
    return sorted(p for p in files if p.is_file())


def unguarded(text: str) -> list[tuple[str, int]]:
    """(array, line) for every bare expansion of an array that is declared empty in the same file."""
    problems = []
    for name in set(DECLARED_EMPTY.findall(text)):
        bare = re.compile(r'(?<!\+)"\$\{%s\[@\]\}"' % re.escape(name))
        guarded = '${%s[@]+"${%s[@]}"}' % (name, name)
        for number, line in enumerate(text.splitlines(), 1):
            if bare.search(line.replace(guarded, "")):
                problems.append((name, number))
    return sorted(problems, key=lambda p: p[1])


def test_the_check_flags_a_bare_expansion_of_an_empty_array():
    assert unguarded('args=()\nrun "${args[@]}"\n') == [("args", 2)]


def test_the_check_sees_an_array_declared_empty_inside_a_one_line_if():
    assert unguarded('if [[ -t 1 ]]; then t=(-it); else t=(); fi\nrun "${t[@]}"\n') == [("t", 2)]


def test_the_check_accepts_the_guarded_form_and_arrays_never_declared_empty():
    assert unguarded('args=()\nrun ${args[@]+"${args[@]}"}\n') == []
    assert unguarded('args=(a)\nrun "${args[@]}"\n') == []


def test_no_shell_here_expands_an_empty_array_bare():
    found = {
        f"{path.relative_to(ROOT)}:{line} ({name})"
        for path in shell_files()
        for name, line in unguarded(path.read_text(encoding="utf-8"))
    }
    assert not found, "use ${name[@]+\"${name[@]}\"} (bash 3.2 on macOS): " + ", ".join(sorted(found))
