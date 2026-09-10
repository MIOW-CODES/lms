import json, os, subprocess

review = open("/tmp/review.txt").read()
title = os.environ.get("PR_TITLE", "unknown")
author = os.environ.get("PR_AUTHOR", "unknown")
url = os.environ.get("PR_URL", "#")
webhook = os.environ.get("DISCORD_WEBHOOK_URL", "")
repo = os.environ.get("GITHUB_REPOSITORY", "")
pr_number = os.environ.get("PR_NUMBER", "")

# Post to Discord
embed = {
    "title": f"PR Review: {title}",
    "url": url,
    "description": review[:4000],
    "color": 5814783,
    "author": {"name": author},
    "footer": {"text": "Hermes Agent - Auto Review"}
}

payload = json.dumps({"embeds": [embed]})

result = subprocess.run([
    "curl", "-s", "-X", "POST", webhook,
    "-H", "Content-Type: application/json",
    "-d", payload
], capture_output=True, text=True)

print(f"Discord webhook response: {result.stdout[:200]}")

# Post review as PR comment on GitHub
if repo and pr_number:
    gh_token = os.environ.get("GH_TOKEN", "")
    if gh_token:
        comment_body = f"## Hermes Agent Review\n\n{review}"
        comment_payload = json.dumps({"body": comment_body})
        result = subprocess.run([
            "curl", "-s", "-X", "POST",
            f"https://api.github.com/repos/{repo}/issues/{pr_number}/comments",
            "-H", "Content-Type: application/json",
            "-H", f"Authorization: token {gh_token}",
            "-d", comment_payload
        ], capture_output=True, text=True)
        print(f"GitHub comment response: {result.stdout[:200]}")
