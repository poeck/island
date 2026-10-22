import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
import island_cli as cli

class CliTests(unittest.TestCase):
    def test_invalid_configuration(self):
        for value in ['[]', '{"terminal":"sh -c"}', '{"pamService":"../login"}', '{"theme":"red"}', '{"notifications":"true"}']:
            with self.subTest(value=value), tempfile.TemporaryDirectory() as d:
                path=Path(d)/'config.json'; path.write_text(value)
                with self.assertRaises(cli.IslandError): cli.configuration(path)

    def test_missing_config_has_preview_safe_defaults(self):
        config=cli.configuration('/tmp/island-nonexistent-test-config')
        self.assertFalse(config['notifications']); self.assertFalse(config['polkit'])

    def test_session_actions_are_dry_run_outside_live_mode(self):
        def forbidden(*args,**kwargs): self.fail('Must not touch the session in preview')
        with patch.dict(os.environ, {'ISLAND_MODE':'preview'}):
            for action in ['lock','suspend','logout','reboot','poweroff']:
                self.assertTrue(cli.session_action(action,{},forbidden,forbidden)['dryRun'])

    def test_suspend_waits_for_lock_before_dispatch(self):
        calls=[]
        def locker(config,wait): calls.append(('lock',wait))
        def runner(args,check): calls.append(tuple(args)); return SimpleNamespace(returncode=0)
        with patch.dict(os.environ, {'ISLAND_MODE':'live'}): cli.session_action('suspend',{},runner,locker)
        self.assertEqual(calls,[('lock',True),('systemctl','suspend')])

    def test_failed_lock_never_suspends(self):
        def locker(*args,**kwargs): raise cli.IslandError('no secure lock')
        def runner(*args,**kwargs): self.fail('Suspend must not be requested')
        with patch.dict(os.environ, {'ISLAND_MODE':'live'}), self.assertRaises(cli.IslandError):
            cli.session_action('suspend',{},runner,locker)

    def test_backlight_hotplug_and_missing_device(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d)
            self.assertIsNone(cli.read_backlight(base))
            device=base/'intel_backlight'; device.mkdir()
            (device/'max_brightness').write_text('200')
            (device/'brightness').write_text('100')
            self.assertEqual(cli.read_backlight(base),('intel_backlight',50))
            (device/'actual_brightness').write_text('120')
            self.assertEqual(cli.read_backlight(base),('intel_backlight',60))
            self.assertIsNone(cli.read_backlight(base,'missing'))
            (device/'max_brightness').write_text('0')
            self.assertIsNone(cli.read_backlight(base))

    def test_desktop_visibility_and_user_override(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); user=root/'user/applications'; system=root/'system/applications'
            user.mkdir(parents=True); system.mkdir(parents=True)
            entries={'visible':'OnlyShowIn=Hyprland;GNOME;\n', 'hidden':'Hidden=true\n',
                     'nodisplay':'NoDisplay=true\n', 'elsewhere':'OnlyShowIn=GNOME;\n',
                     'excluded':'NotShowIn=Hyprland;\n', 'missing':'TryExec=island-impossible-binary\n',
                     'override':'', 'terminal':'Terminal=true\n'}
            for name,extra in entries.items():
                (system/(name+'.desktop')).write_text('[Desktop Entry]\nType=Application\nName='+name+'\nExec=true\n'+extra)
            (user/'override.desktop').write_text('[Desktop Entry]\nHidden=true\n')
            env={'XDG_DATA_HOME':str(user.parent),'XDG_DATA_DIRS':str(system.parent),'XDG_CURRENT_DESKTOP':'Hyprland'}
            self.assertEqual(set(cli.visible_applications(env)), {'visible.desktop','terminal.desktop'})


if __name__ == '__main__': unittest.main()
