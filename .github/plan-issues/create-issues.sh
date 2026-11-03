#!/usr/bin/env bash
# Opens the parent issue (00-*.md) and one sub-issue per other file.
# Each file: title on line 1, a blank line, then the body. In the body,
# {{PLAN}} becomes the link to research-plan.md, {{PARENT}} the parent's
# number and {{SELF}} the issue's own number.
# Needs GH_TOKEN and GITHUB_REPOSITORY; does nothing if the parent exists.
set -euo pipefail

repo="$GITHUB_REPOSITORY"
dir="$(dirname "$0")"
plan="https://github.com/$repo/blob/main/research-plan.md"

parent_file=$(ls "$dir"/00-*.md)
parent_title=$(head -n 1 "$parent_file")
if gh api --paginate "repos/$repo/issues?state=all&per_page=100" \
     --jq '.[] | select(.pull_request == null) | .title' |
   grep -qxF "$parent_title"; then
  echo "\"$parent_title\" already exists; nothing to do."
  exit 0
fi

# create FILE [PARENT]: opens the issue; prints "number id"
create() {
  local file=$1 parent=${2:-} title body number id
  title=$(head -n 1 "$file")
  body=$(tail -n +3 "$file")
  body=${body//'{{PLAN}}'/"$plan"}
  body=${body//'{{PARENT}}'/"$parent"}
  read -r number id < <(gh api "repos/$repo/issues" \
    -f title="$title" -f body="$body" --jq '"\(.number) \(.id)"')
  if [[ $body == *'{{SELF}}'* ]]; then
    gh api -X PATCH "repos/$repo/issues/$number" \
      -f body="${body//'{{SELF}}'/"$number"}" > /dev/null
  fi
  echo "$number $id"
}

read -r parent _ < <(create "$parent_file")
echo "#$parent $parent_title"
for file in "$dir"/[0-9][0-9]-*.md; do
  [[ $file == "$parent_file" ]] && continue
  read -r number id < <(create "$file" "$parent")
  gh api -X POST "repos/$repo/issues/$parent/sub_issues" \
    -F sub_issue_id="$id" > /dev/null
  echo "#$number $(head -n 1 "$file") (sub-issue of #$parent)"
done
