import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('verify_jni', ROOT / 'scripts/packaging/android/verify_jni.py')
jni = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jni)


class AndroidJniTests(unittest.TestCase):
    def test_exact_continuation_signature_is_required(self):
        parameters = ''.join(f'<parameter type="{value}"/>' for value in jni.PARAMETERS['getString'])
        xml = (f'<api><package name="io.flutter.plugins.sharedpreferences">'
               f'<class name="SharedPreferencesAsyncApiRegistrar">'
               f'<method name="getString" return="java.lang.Object" static="false">{parameters}'
               '</method></class></package></api>')
        self.assertEqual(jni.signatures(xml), {'getString'})
        self.assertEqual(jni.signatures(xml.replace('kotlin.coroutines.Continuation', 'a.b')), set())
        self.assertEqual(jni.signatures(xml.replace('name="getString"', 'name="a"')), set())

    def test_release_keeps_classes_and_descriptor_types_without_disabling_r8(self):
        rules = (ROOT / 'apps/vex/android/app/proguard-rules.pro').read_text(encoding='utf-8')
        self.assertIn('-keep,includedescriptorclasses class io.flutter.plugins.sharedpreferences.**', rules)
        build = (ROOT / 'apps/vex/android/app/build.gradle.kts').read_text(encoding='utf-8')
        self.assertIn('"proguard-rules.pro"', build)
        self.assertNotIn('isMinifyEnabled = false', build)
        for value in ['kotlin.coroutines.**', 'kotlin.Result**', 'kotlin.Unit']:
            self.assertIn('-keep class ' + value, rules)

    def test_runtime_requires_exact_unobfuscated_coroutine_class_names(self):
        xml = ('<api><package name="kotlin.coroutines.intrinsics">'
               '<class name="CoroutineSingletons"/></package></api>')
        self.assertEqual(jni.runtime_classes(xml), {'kotlin.coroutines.intrinsics.CoroutineSingletons'})
        self.assertEqual(jni.runtime_classes(xml.replace('CoroutineSingletons', 'a')), set())


if __name__ == '__main__':
    unittest.main()
