"""Build and verify Vex's native Finder drag-to-Applications disk image."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BACKGROUND = ROOT / 'scripts/installer/assets/macos-background.png'
WINDOW_SIZE = (740, 380)
ICON_SIZE = 88
ICON_LOCATIONS = {'Vex.app': (220, 190), 'Applications': (520, 190)}


def layout_settings(app, background=BACKGROUND):
    return {
        'format': 'UDZO',
        'filesystem': 'HFS+',
        'files': [(str(app), 'Vex.app')],
        'symlinks': {'Applications': '/Applications'},
        # SetFile -a E adds FinderInfo to the signed bundle; strict codesign
        # rejects that attribute. Leave bundle display to Finder's conventions.
        'hide_extensions': [],
        'background': str(background),
        'window_rect': ((100, 100), WINDOW_SIZE),
        'default_view': 'icon-view',
        'show_status_bar': False,
        'show_tab_view': False,
        'show_toolbar': False,
        'show_pathbar': False,
        'show_sidebar': False,
        'arrange_by': None,
        'icon_size': ICON_SIZE,
        'text_size': 14,
        'icon_locations': dict(ICON_LOCATIONS),
    }


def verify_layout(mount):
    from ds_store import DSStore

    if not (mount / 'Vex.app/Contents/Resources/LICENSE.txt').is_file():
        raise ValueError('The shipped Vex application is missing its license.')
    target = mount / 'Applications'
    if not target.is_symlink() or target.readlink() != Path('/Applications'):
        raise ValueError('The Applications drag target is missing or incorrect.')
    if not (mount / '.background.tiff').is_file():
        raise ValueError('The Retina Finder background is missing.')
    with DSStore.open(str(mount / '.DS_Store'), 'r') as store:
        options = store['.']['icvp']
        if options['iconSize'] != ICON_SIZE or options['backgroundType'] != 2:
            raise ValueError('Finder icon size or image background mismatch.')
        for name, position in ICON_LOCATIONS.items():
            if tuple(store[name]['Iloc']) != position:
                raise ValueError(f'Finder drag target moved: {name}')
        window = store['.']['bwsp']
        if window['ShowToolbar'] or window['ShowSidebar']:
            raise ValueError('Finder chrome obscures the installer layout.')
        if window['WindowBounds'] != '{{100, 100}, {740, 380}}':
            raise ValueError('Finder window geometry mismatch.')
    print('Verified shipped Vex bundle, license, Applications link and Retina Finder layout.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    build = sub.add_parser('build')
    build.add_argument('--app', type=Path, required=True)
    build.add_argument('--output', type=Path, required=True)
    build.add_argument('--version', required=True)
    verify = sub.add_parser('verify')
    verify.add_argument('--mount', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'verify':
        verify_layout(args.mount)
        return
    from dmgbuild import build_dmg

    if not args.app.is_dir() or not BACKGROUND.is_file():
        raise ValueError('The application bundle or Finder background is missing.')
    build_dmg(str(args.output), f'Vex {args.version}', settings=layout_settings(args.app))


if __name__ == '__main__':
    main()
