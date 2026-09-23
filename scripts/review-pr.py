import json, os, subprocess

diff = open("/tmp/pr_diff.txt").read()
title = os.environ.get("PR_TITLE", "unknown")
author = os.environ.get("PR_AUTHOR", "unknown")
url = os.environ.get("PR_URL", "#")
api_key = os.environ.get("OPENCODE_API_KEY", "")

prompt = f"""You are a senior code reviewer. Review this pull request and provide:
1. **Summary** - What the PR does (1-2 sentences)
2. **Issues** - Bugs, security problems, or code smells (if any)
3. **Suggestions** - Improvements or best practices
4. **Rating** - LGTM, Minor issues, or Needs changes

Be concise and actionable.

PR: {title}
Author: {author}
URL: {url}

Diff:
{diff}"""

payload = json.dumps({
    "model": "mimo-v2.5",
    "messages": [{"role": "user", "content": prompt}],
    "stream": False
})

session_id = f"miow-pr-review-{os.environ.get('PR_NUMBER', 'na')}-{os.environ.get('GITHUB_RUN_ID', 'local')}"

result = subprocess.run([
    "curl", "-s", "-X", "POST",
    "https://opencode.ai/zen/go/v1/chat/completions",
    "-H", "Content-Type: application/json",
    "-H", f"Authorization: Bearer {api_key}",
    "-H", f"x-opencode-session: {session_id}",
    "-d", payload
], capture_output=True, text=True)

try:
    data = json.loads(result.stdout)
    review = data["choices"][0]["message"]["content"]
except Exception as e:
    review = f"Error generating review: {e}\n\nRaw response: {result.stdout[:500]}"

open("/tmp/review.txt", "w").write(review)
print("Review generated successfully")
