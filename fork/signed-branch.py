"""Build a one-commit branch on upstream/main from local diffs and create it, GitHub-signed, through the API.

usage: python3 -I fork/signed-branch.py <branch> <headline> <body-file> <diff-spec>...
  diff-spec: <rev> (its own diff) or <from>..<to>, applied in order onto upstream/main
  DRY=1: only build the files and say whether each matches local main; create nothing

heygen-com/hyperframes requires signed commits. A commit created through the GraphQL API
(createCommitOnBranch) is signed by GitHub (web-flow) and authored by the account gh is signed in to,
so no local signing key is needed. Run from the repository root after `git fetch upstream`.
The branch must not exist yet; a file that differs from main is not covered by main's tests.
"""

import base64
import json
import os
import subprocess
import sys
import tempfile

REPO = "ssheleg/hyperframes-agent"


def git(*args, env=None, data=None):
    return subprocess.run(["git", *args], check=True, capture_output=True, env=env, input=data).stdout


branch, headline, body_file = sys.argv[1:4]
specs = sys.argv[4:]
base = git("rev-parse", "upstream/main").decode().strip()

with tempfile.TemporaryDirectory() as tmp:
    env = {**os.environ, "GIT_INDEX_FILE": os.path.join(tmp, "index")}
    git("read-tree", base, env=env)
    for spec in specs:
        diff = git("diff", *(spec.split("..") if ".." in spec else [f"{spec}^", spec]))
        git("apply", "--cached", env=env, data=diff)
    changed = git("diff", "--cached", "--name-only", base, env=env).decode().split()
    additions = []
    for path in changed:
        blob = git("show", f":{path}", env=env)
        on_main = subprocess.run(["git", "show", f"main:{path}"], capture_output=True).stdout
        print(f"{path}: {'matches main' if blob == on_main else 'DIFFERS from main'}")
        additions.append({"path": path, "contents": base64.b64encode(blob).decode()})

if os.environ.get("DRY"):
    sys.exit(0)
subprocess.run(
    ["gh", "api", "-X", "POST", f"repos/{REPO}/git/refs", "-f", f"ref=refs/heads/{branch}", "-f", f"sha={base}"],
    check=True,
    capture_output=True,
)
query = (
    "mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) "
    "{ commit { oid url signature { isValid signer { login } } } } }"
)
payload = {
    "query": query,
    "variables": {
        "input": {
            "branch": {"repositoryNameWithOwner": REPO, "branchName": branch},
            "message": {"headline": headline, "body": open(body_file).read().strip()},
            "expectedHeadOid": base,
            "fileChanges": {"additions": additions},
        }
    },
}
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    json.dump(payload, f)
out = subprocess.run(["gh", "api", "graphql", "--input", f.name], check=True, capture_output=True).stdout
os.unlink(f.name)
print(json.dumps(json.loads(out)["data"]["createCommitOnBranch"]["commit"]))
