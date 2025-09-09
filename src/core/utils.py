from typing import Any

from pathlib import Path
import json


def repo_root() -> Path:
    """Return the repository root (looks upward for .git or pyproject.toml)."""
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / ".git").exists() or (parent / "pyproject.toml").exists():
            return parent
    return here.parents[2]


# --- JSON I/O ------------------------------------------------------------
def read_json(path: Path, default: Any = None) -> Any:
    p = Path(path)
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else default


def write_json(path: Path, data: Any, indent: int = 2) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, indent=indent, ensure_ascii=False) + "\n", encoding="utf-8")
