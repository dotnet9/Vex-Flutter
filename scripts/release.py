#!/usr/bin/env python
"""Tag and push a release, deriving the tag from apps/vex/pubspec.yaml.

The pubspec version is the only version edited by hand. This script derives
v{version} from it, drafts the release-notes file when missing, then pushes
the current branch and the tag. Existing tags are never moved without
--force-move, so retries cannot silently rewrite a published release.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(command):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                            encoding='utf-8', errors='replace')
    if result.returncode != 0:
        raise RuntimeError(f'{" ".join(map(str, command))} 失败:\n{result.stderr.strip()}')
    return result.stdout.strip()


def git(*args):
    return run(('git',) + args)


def release_metadata():
    script = ROOT / 'scripts' / 'packaging' / 'shared' / 'release_tools.py'
    return json.loads(run((sys.executable, str(script), 'metadata')))


def local_tag_commit(target):
    """Commit the local tag points at, or '' when the tag does not exist."""
    if not git('tag', '-l', target):
        return ''
    return git('rev-parse', f'{target}^{{commit}}')


def remote_tag_commit(target):
    """Commit the tag points at on origin, or '' when it does not exist."""
    listing = git('ls-remote', 'origin', f'refs/tags/{target}', f'refs/tags/{target}^{{}}')
    peeled = [line for line in listing.splitlines() if line.endswith(f'refs/tags/{target}^{{}}')]
    plain = [line for line in listing.splitlines() if line.endswith(f'refs/tags/{target}')]
    if peeled:
        return peeled[0].split()[0]
    if plain:
        return plain[0].split()[0]
    return ''


def draft_release_notes(tag, meta):
    """Create the release-notes file from commit history; True when created."""
    path = ROOT / '.github' / 'release-notes' / f'{tag}.md'
    if path.exists():
        return False
    current = tuple(int(part) for part in meta['version'].split('.'))
    previous = []
    for name in git('tag', '-l', 'v*').split():
        match = re.fullmatch(r'v(\d+)\.(\d+)\.(\d+)', name)
        if match and tuple(map(int, match.groups())) < current:
            previous.append(name)
    base = max(previous, key=lambda name: tuple(int(part) for part in name[1:].split('.'))) if previous else None
    subjects = git('log', '--oneline', '--max-count=30', *( (f'{base}..HEAD',) if base else ()))
    bullets = '\n'.join(f'- {line.split(maxsplit=1)[-1]}' for line in subjects.splitlines())
    path.write_text(
        f'# 维刻 Vex {tag}\n\n'
        '本版变更（从提交记录起草，发布前请补充完善）：\n\n'
        f'{bullets or "- （填写本版变更）"}\n\n'
        f'应用版本为 `{meta["version"]}+{meta["build"]}`。\n',
        encoding='utf-8')
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--force-move', action='store_true',
                        help='允许移动已存在的标签（本地与 origin）')
    parser.add_argument('--dry-run', action='store_true',
                        help='只检查并打印将要执行的操作，不改动任何状态')
    args = parser.parse_args()

    meta = release_metadata()
    tag = meta['tag']
    if draft_release_notes(tag, meta):
        sys.exit(f'已创建发布说明草稿 .github/release-notes/{tag}.md，请补充完善后重新运行。')

    dirty = git('status', '--porcelain')
    if dirty:
        sys.exit('工作区存在未提交改动，请先提交:\n' + dirty)

    branch = git('rev-parse', '--abbrev-ref', 'HEAD')
    if branch == 'HEAD':
        sys.exit('当前处于 detached HEAD，请切到要发布的分支。')
    head = git('rev-parse', 'HEAD')
    local = local_tag_commit(tag)
    remote = remote_tag_commit(tag)

    force = args.force_move
    if local and local != head and not force:
        sys.exit(f'本地标签 {tag} 已存在且不指向当前提交（{local[:12]}）；确认要移动请加 --force-move。')
    if remote and remote != head and not force:
        sys.exit(f'origin 上的标签 {tag} 指向其他提交（{remote[:12]}）；'
                 f'确认要移动请加 --force-move，若只是重试发布可用 workflow_dispatch 复用现有标签。')

    print(f'版本 {meta["version"]}+{meta["build"]}，标签 {tag}，flutter {meta["flutter"]}')
    steps = [f'git push origin {branch}']
    if local != head:
        steps.append(f'git tag {"-f " if force else ""}{tag}')
    if remote != head:
        steps.append(f'git push {"--force " if force else ""}origin {tag}')
    if remote == head:
        steps.append(f'（origin 上已有 {tag}，与当前提交一致，跳过标签推送）')
    for step in steps:
        print(f'  {"[dry-run] " if args.dry_run else ""}{step}')
    if args.dry_run:
        return

    git('push', 'origin', branch)
    if local != head:
        git(*( ('tag', '-f', tag) if force else ('tag', tag) ))
    if remote != head:
        git(*( ('push', '--force', 'origin', tag) if force else ('push', 'origin', tag) ))
    print(f'完成：{tag} 已推送，release workflow 将自动运行。')


if __name__ == '__main__':
    try:
        main()
    except RuntimeError as error:
        sys.exit(error)
