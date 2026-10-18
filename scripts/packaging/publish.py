"""Push an annotated tag over SSH to build all installers on GitHub Actions.

This is a remote release, not cross-compilation on the current computer.
It never commits files, moves tags, changes credentials or installs software.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import webbrowser

sys.path.insert(0, str(Path(__file__).resolve().parent / 'shared'))
from release_tools import ROOT, app_version


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True, encoding='utf-8').strip()


def github_repository(remote):
    match = re.fullmatch(r'(?:git@github\.com:|ssh://git@github\.com/)([\w.-]+/[\w.-]+?)(?:\.git)?', remote)
    if not match:
        raise ValueError('origin must be a GitHub SSH remote, for example git@github.com:OWNER/REPO.git.')
    return match.group(1)


def preflight():
    version, _ = app_version(ROOT)
    tag = f'v{version}'
    if git('status', '--porcelain', '--untracked-files=normal'):
        raise ValueError('Working tree is not clean. Commit the intended changes and preserve other files before releasing.')
    if git('branch', '--show-current') != 'main':
        raise ValueError('Switch to main before releasing.')
    if not (ROOT / '.github/release-notes' / f'{tag}.md').is_file():
        raise ValueError(f'Missing .github/release-notes/{tag}.md.')
    repository = github_repository(git('remote', 'get-url', '--push', 'origin'))
    head = git('rev-parse', 'HEAD')
    remote_main = git('ls-remote', '--exit-code', 'origin', 'refs/heads/main').split()[0]
    if head != remote_main:
        raise ValueError('Local HEAD differs from origin/main. Push or update main before releasing.')
    if git('tag', '--list', tag) or git('ls-remote', 'origin', f'refs/tags/{tag}'):
        raise ValueError(f'{tag} already exists. Retry its Actions run; never move a published tag.')
    return tag, head, repository


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-only', action='store_true', help='Validate without creating or pushing a tag.')
    parser.add_argument('--no-browser', action='store_true', help='Do not open the Actions page.')
    args = parser.parse_args(argv)
    tag, head, repository = preflight()
    actions = f'https://github.com/{repository}/actions/workflows/release.yml'
    release = f'https://github.com/{repository}/releases/tag/{tag}'
    print(f'Ready: {tag} at {head}\nGitHub will build Windows, macOS, Linux and signed Android installers.')
    print('iOS is compile-only; HarmonyOS packaging is deferred. No installable IPA/HAP is published.')
    print(f'Actions: {actions}\nDownload after successful publication: {release}', flush=True)
    if args.check_only:
        return 0
    if input(f'Type {tag} to publish this version (anything else cancels): ').strip() != tag:
        print('Cancelled. No tag created or pushed.')
        return 0
    # Recheck after confirmation so an intervening edit cannot slip into a release.
    if preflight() != (tag, head, repository):
        raise ValueError('Source changed while waiting for confirmation.')
    subprocess.run(['git', 'tag', '-a', tag, head, '-m', f'Release Vex {tag}'], cwd=ROOT, check=True)
    subprocess.run(['git', 'push', 'origin', f'refs/tags/{tag}'], cwd=ROOT, check=True)
    print(f'Tag pushed. This does NOT mean the installers are ready.\nWatch {actions}', flush=True)
    if not args.no_browser:
        webbrowser.open(actions)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, EOFError, subprocess.CalledProcessError) as error:
        print(f'PUBLISH STOPPED: {error}', file=sys.stderr)
        print('If a local tag was created before a network failure, inspect local/remote refs before retrying. Never force-push it.', file=sys.stderr)
        sys.exit(1)
