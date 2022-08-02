#!/usr/bin/env python
import json
import os
import re
from datetime import datetime, timedelta

import requests

from client import get_token


CACHEFILE = "cache/mozilla_all_repos.json"


def parse_timestamp(tst):
    return datetime.strptime(tst, "%Y-%m-%dT%H:%M:%SZ")


if __name__ == "__main__":
    headers = {
        "Accept": "application/vnd.github.moondragon+json",
        "Authorization": f"token {get_token()}",
    }


    if os.path.exists(CACHEFILE):
        repos = json.loads(open(CACHEFILE).read())
        print(
            "Found cached repository list. Delete %s if you want a new "
            "one.\n" % CACHEFILE
        )

    else:
        repos = []
        repos_api = 'https://api.github.com/orgs/mozilla/repos'
        while True:
            resp = requests.get(repos_api, headers=headers)
            repos += resp.json()

            if next_match := re.search(
                r'<([^>]+)>; rel="next"', resp.headers["Link"]
            ):
                repos_api = next_match[1]

            else:
                break
        open(CACHEFILE, "w").write(json.dumps(repos))

    # Find small/empty repos older than a month.
    SMALL_MINAGE = 31
    small_repos = [
        r
        for r in repos
        if (
            r["size"] < 50
            and r["open_issues_count"] == 0
            and parse_timestamp(r["updated_at"]) + timedelta(days=SMALL_MINAGE)
            < datetime.now()
        )
    ]
    small_repos.sort(key=lambda r: r["name"])
    print(
        f"## {len(small_repos)} small/empty repositories older than {SMALL_MINAGE} days"
    )

    for repo in small_repos:
        print(repo["name"], ":", repo["size"], f'({repo["updated_at"]})')

    print("\n\n")

    # Find recently untouched repos.
    UNTOUCHED_MINAGE = 2 * 365
    old_repos = [
        r
        for r in repos
        if (
            parse_timestamp(r["updated_at"]) + timedelta(days=(UNTOUCHED_MINAGE))
            < datetime.now()
        )
    ]
    old_repos.sort(key=lambda r: r["name"])
    print(
        f"## {len(old_repos)} repos touched less recently than {UNTOUCHED_MINAGE} days ago."
    )

    for repo in old_repos:
        print(repo["name"], ":", repo["updated_at"])
