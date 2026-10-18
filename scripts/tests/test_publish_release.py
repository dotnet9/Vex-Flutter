"""Check remote publishing without pushing tags or contacting GitHub."""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('publish_release', ROOT / 'scripts/packaging/publish.py')
publish = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publish)


class PublishReleaseTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.root = Path(folder.name)
        notes = self.root / '.github/release-notes/v1.2.3.md'
        notes.parent.mkdir(parents=True)
        notes.write_text('# Release 1.2.3', encoding='utf-8')
        self.responses = {
            ('status', '--porcelain', '--untracked-files=normal'): '',
            ('branch', '--show-current'): 'main',
            ('remote', 'get-url', '--push', 'origin'): 'git@github.com:owner/project.git',
            ('rev-parse', 'HEAD'): 'abc123',
            ('ls-remote', '--exit-code', 'origin', 'refs/heads/main'): 'abc123\trefs/heads/main',
            ('tag', '--list', 'v1.2.3'): '',
            ('ls-remote', 'origin', 'refs/tags/v1.2.3'): '',
        }
        for mock in (patch.object(publish, 'ROOT', self.root),
                     patch.object(publish, 'app_version', return_value=('1.2.3', '4')),
                     patch.object(publish, 'git', side_effect=lambda *args: self.responses[args])):
            mock.start()
            self.addCleanup(mock.stop)

    def test_ssh_urls_and_repository_name(self):
        for remote in ('git@github.com:owner/project.git', 'ssh://git@github.com/owner/project.git',
                       'git@github.com:owner/project'):
            self.assertEqual(publish.github_repository(remote), 'owner/project')
        for remote in ('https://github.com/owner/project.git', 'git@example.com:owner/project.git'):
            with self.assertRaisesRegex(ValueError, 'SSH remote'):
                publish.github_repository(remote)

    def test_preflight_accepts_only_clean_pushed_main_with_notes_and_new_tag(self):
        self.assertEqual(publish.preflight(), ('v1.2.3', 'abc123', 'owner/project'))

    def test_reject_dirty_branch_unpushed_or_existing_tag(self):
        cases = [
            (('status', '--porcelain', '--untracked-files=normal'), '?? note.md', 'not clean'),
            (('branch', '--show-current'), 'feature', 'main'),
            (('rev-parse', 'HEAD'), 'unpushed', 'differs'),
            (('tag', '--list', 'v1.2.3'), 'v1.2.3', 'already exists'),
            (('ls-remote', 'origin', 'refs/tags/v1.2.3'), 'abc\trefs/tags/v1.2.3', 'already exists'),
        ]
        for key, value, message in cases:
            original = self.responses[key]
            self.responses[key] = value
            with self.assertRaisesRegex(ValueError, message):
                publish.preflight()
            self.responses[key] = original

    def test_reject_missing_notes(self):
        (self.root / '.github/release-notes/v1.2.3.md').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing'):
            publish.preflight()

    def test_check_only_and_cancel_never_create_or_push_tags(self):
        with patch.object(publish.subprocess, 'run') as run, patch('builtins.input', return_value='no'), \
                patch.object(publish.webbrowser, 'open') as browser, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(publish.main(['--check-only']), 0)
            self.assertEqual(publish.main([]), 0)
            run.assert_not_called()
            browser.assert_not_called()

    def test_confirmation_creates_annotated_tag_then_pushes_only_that_tag(self):
        with patch.object(publish.subprocess, 'run') as run, patch('builtins.input', return_value='v1.2.3'), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(publish.main(['--no-browser']), 0)
            self.assertEqual([call.args[0] for call in run.call_args_list], [
                ['git', 'tag', '-a', 'v1.2.3', 'abc123', '-m', 'Release Vex v1.2.3'],
                ['git', 'push', 'origin', 'refs/tags/v1.2.3'],
            ])

    def test_changed_source_during_confirmation_is_rejected(self):
        def confirm(_):
            self.responses[('status', '--porcelain', '--untracked-files=normal')] = ' M changed.dart'
            return 'v1.2.3'
        with patch('builtins.input', side_effect=confirm), patch.object(publish.subprocess, 'run') as run, \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(ValueError, 'not clean'):
                publish.main([])
            run.assert_not_called()

    def test_failed_push_is_not_reported_as_success_and_does_not_open_browser(self):
        with patch.object(publish.subprocess, 'run', side_effect=[None, subprocess.CalledProcessError(1, 'git')]), \
                patch('builtins.input', return_value='v1.2.3'), patch.object(publish.webbrowser, 'open') as browser, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            with self.assertRaises(subprocess.CalledProcessError):
                publish.main([])
            self.assertNotIn('Tag pushed', output.getvalue())
            browser.assert_not_called()

    def test_public_release_is_latest_eligible_and_keeps_all_validation(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
        self.assertIn("tags: ['v*']", workflow)
        self.assertIn('draft: false, prerelease: false, make_latest:', workflow)
        self.assertIn('python scripts/packaging/shared/release_tools.py verify', workflow)
        self.assertIn("needs.android.result == 'success'", workflow)
        self.assertIn('published.assets.length !== files.length', workflow)
        self.assertIn("annotated.object.sha !== process.env.APP_COMMIT", workflow)


if __name__ == '__main__':
    unittest.main()
