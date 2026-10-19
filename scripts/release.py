#!/usr/bin/env python
"""Tag and push a release, deriving the tag from apps/vex/pubspec.yaml.

The pubspec version is the only version edited by hand. This script derives
v{version} from it, prepares the release paperwork (changelog section,
release-notes file, bundled documents), reruns the prototype contract checks
locally, then pushes the current branch and the tag. Existing tags are never
moved without --force-move, so retries cannot silently rewrite a release.
"""
import argparse
import datetime
import glob
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


def rename_changelog_section(version):
    """Rename the top 未发布 changelog section to V{version}（today）; True when renamed."""
    path = ROOT / 'docs' / '更新日志.md'
    text = path.read_text(encoding='utf-8')
    heading = re.search(r'^## 未发布（\d{4}-\d{2}-\d{2}）$', text, re.M)
    if not heading:
        return False
    section = text[heading.end():]
    entries = re.split(r'^## ', section, maxsplit=1)[0]
    if not any(line.strip() for line in entries.splitlines()):
        sys.exit('更新日志的「未发布」小节没有条目；若本版无变更请先补充或移除该小节。')
    today = datetime.date.today().isoformat()
    renamed = re.sub(r'^## 未发布（\d{4}-\d{2}-\d{2}）$', f'## V{version}（{today}）',
                     text, count=1, flags=re.M)
    if re.search(rf'^## V{re.escape(version)}（{today}）$', renamed, re.M) is None:
        sys.exit('更新日志改名失败，请手动检查「未发布」小节。')
    path.write_text(renamed, encoding='utf-8')
    return True


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


def contract_checks():
    """Regenerate bundled documents and run the prototype contract checks."""
    run((sys.executable, str(ROOT / 'scripts' / 'sync_builtin_documents.py')))
    try:
        for script in sorted(glob.glob(str(ROOT / 'design' / 'scripts' / 'verify*.cjs'))):
            run(('node', script))
            print(f'契约检查通过 {Path(script).name}')
    except FileNotFoundError:
        print('警告：未找到 node，跳过本地原型契约检查（CI 仍会执行）。')


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


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--force-move', action='store_true',
                        help='允许移动已存在的标签（本地与 origin）')
    parser.add_argument('--branch', default='',
                        help='从干净检出（如临时 worktree）发布时指定目标分支，'
                             '推送使用 HEAD:<branch>')
    parser.add_argument('--dry-run', action='store_true',
                        help='只检查并打印将要执行的操作，不改动任何状态')
    args = parser.parse_args()

    meta = release_metadata()
    tag = meta['tag']
    if rename_changelog_section(meta['version']):
        run((sys.executable, str(ROOT / 'scripts' / 'sync_builtin_documents.py')))
        sys.exit(f'已把更新日志「未发布」小节改为 V{meta["version"]}，'
                 '请检查内容并提交后重新运行。')
    if draft_release_notes(tag, meta):
        sys.exit(f'已创建发布说明草稿 .github/release-notes/{tag}.md，请补充完善后重新运行。')

    contract_checks()

    dirty = git('status', '--porcelain')
    if dirty:
        sys.exit('工作区存在未提交改动，请先提交:\n' + dirty)

    branch = git('rev-parse', '--abbrev-ref', 'HEAD')
    if branch == 'HEAD' and not args.branch:
        sys.exit('当前处于 detached HEAD，请切到要发布的分支或用 --branch 指定目标分支。')
    push_ref = f'HEAD:{args.branch}' if args.branch else branch
    branch = args.branch or branch
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
    steps = [f'git push origin {push_ref}']
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

    git('push', 'origin', push_ref)
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
