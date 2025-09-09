from huggingface_hub import whoami, snapshot_download
from pathlib import Path
from datetime import datetime, timezone
import json

LOG_PATH = Path("var/models/snapshots.jsonl")


def verify_hf_login_local_only() -> str:
    try:
        info = whoami()
        return info.get("name") or info.get("user") or "unknown"
    except Exception as e:
        raise RuntimeError(
            "Not authenticated to Hugging Face. "
            "Please run `hf auth login` locally and try again.\n\n"
            f"Underlying error: {type(e).__name__}: {e}"
        ) from e


def download_model_if_logged_in(repo_id: str, *, allow_patterns=None):
    try:
        return snapshot_download(
            repo_id=repo_id,
            allow_patterns=allow_patterns,
        )
    except Exception as e:
        raise RuntimeError(
            f"Failed to download '{repo_id}'. "
            "Make sure you're logged in with `hf auth login` and have access.\n"
            f"Underlying error: {type(e).__name__}: {e}"
        ) from e


def download_and_log_model(repo_id: str, *, allow_patterns=None) -> str:
    """
    Extension of `download_model_if_logged_in` that also logs:
    - repo_id
    - resolved revision (commit hash)
    - UTC timestamp
    - list of files in snapshot
    """
    snap_path = Path(download_model_if_logged_in(repo_id, allow_patterns=allow_patterns))
    resolved_revision = snap_path.name  # snapshot dir is the commit hash

    files = [str(p.relative_to(snap_path)) for p in snap_path.rglob("*") if p.is_file()]
    record = {
        "repo_id": repo_id,
        "resolved_revision": resolved_revision,
        "snapshot_path": str(snap_path),
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "files": files,
    }

    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")

    return str(snap_path)


def main():
    repo_id = "bert-base-uncased"

    snap_path = download_model_if_logged_in(
        repo_id,
    )
    print("Snapshot directory:", snap_path)


if __name__ == "__main__":
    main()
