"""Token and literal contracts for the generated download compactor."""
import unittest
try:
    import luau_compact as module
except ImportError:
    module = None


class CompactTests(unittest.TestCase):
    def test_compactor_is_available(self):
        self.assertIsNotNone(module, 'delivery build needs a token-preserving compactor')

    def test_only_unnecessary_whitespace_and_comments_are_removed(self):
        source = '  local total = 12 + 3 -- explanation\n  return total\n'
        self.assertEqual(module.compact(source), 'local total=12+3\nreturn total\n')

    def test_number_and_operator_boundaries_keep_their_tokens(self):
        for source in ['return 1 .. 2\n', 'return x - -1\n', 'return x / / y\n',
                       'return .5 .. .25\n', 'return 0x1p+2 + 1e-3\n',
                       'local a = f[ [=[text]=] ]\n', 'return x : : y\n']:
            with self.subTest(source=source):
                result = module.compact(source)
                self.assertEqual(module.code_tokens(source), module.code_tokens(result))
        self.assertIn('- -', module.compact('return x - -1\n'))
        self.assertIn('/ /', module.compact('return x / / y\n'))

    def test_string_contents_and_long_delimiters_are_verbatim(self):
        source = 'local a = "a  b -- [[ .. ]]"\nlocal b = [=[\n  preserve  indentation\n]=]\n'
        result = module.compact(source)
        self.assertIn('"a  b -- [[ .. ]]"', result)
        self.assertIn('[=[\n  preserve  indentation\n]=]', result)
        self.assertEqual(source.count('\n'), result.count('\n'))

    def test_escaped_quotes_newlines_and_z_whitespace_are_preserved(self):
        source = 'local a = "say \\"hi\\""\n'.replace('\\\\"', '\\"')
        source += 'local b = "a\\z\n  b"\nlocal c = "x\\\n  y"\n'
        result = module.compact(source)
        self.assertEqual(module.code_tokens(source), module.code_tokens(result))
        self.assertIn('"a\\z\n  b"', result)
        self.assertEqual(source.count('\n'), result.count('\n'))

    def test_directives_runtime_marker_and_line_numbers_survive(self):
        source = '--!strict\n-- ordinary comment\nlocal x = 1 --[[one\ntwo]] + 2\n-- Runtime\nreturn x\n'
        result = module.compact(source)
        self.assertIn('--!strict\n', result)
        self.assertIn('-- Runtime\n', result)
        self.assertNotIn('ordinary comment', result)
        self.assertEqual(source.count('\n'), result.count('\n'))
        self.assertEqual(module.code_tokens(source), module.code_tokens(result))

    def test_crlf_and_cr_line_endings_keep_source_mapping(self):
        source = 'local x = 1 -- comment\r\nlocal y = 2\rreturn x+y\n'
        result = module.compact(source)
        self.assertEqual(source.count('\r'), result.count('\r'))
        self.assertEqual(source.count('\n'), result.count('\n'))
        self.assertEqual(len(source.splitlines()), len(result.splitlines()))
        self.assertEqual(module.code_tokens(source), module.code_tokens(result))

    def test_cr_only_line_comment_cannot_swallow_following_code(self):
        source = 'local x=1 -- comment\rreturn x\r'
        result = module.compact(source)
        self.assertEqual(result, 'local x=1\rreturn x\r')
        self.assertIn(('identifier', 'return'), module.code_tokens(result))

    def test_unsupported_or_unterminated_input_fails_closed(self):
        for source in ['local a = `hello`\n', 'local a = "unterminated\n',
                       'local a = [=[unterminated\n', '--[=[unterminated\n', 'return 1e+\n']:
            with self.subTest(source=source):
                with self.assertRaises(ValueError):
                    module.compact(source)


if __name__ == '__main__':
    unittest.main()
