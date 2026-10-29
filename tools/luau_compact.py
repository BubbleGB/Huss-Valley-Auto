"""Conservative, line-preserving Luau delivery compaction.

Preserves code tokens and all literal contents. Unknown syntax fails the build;
editable modules remain formatted and no runtime decoder is introduced.
"""
import re

SPACE = ' \t\r\n\f\v'
IDENTIFIER = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
NUMBER = re.compile(r'(?:0[xX](?:[0-9a-fA-F]+(?:\.[0-9a-fA-F]*)?|\.[0-9a-fA-F]+)(?:[pP][+-]?[0-9]+)?|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)')
LONG = re.compile(r'\[(=*)\[')
OPERATORS = ('...', '..=', '//=', '==', '~=', '<=', '>=', '+=', '-=', '*=', '/=', '%=', '^=', '..', '//', '::', '->', '<<', '>>')
SYMBOLS = set('+-*/%^#=<>;:,.{}[]()~?|&!')


def tokens(source):
    cursor = 0
    while cursor < len(source):
        start = cursor
        char = source[cursor]
        if char in SPACE:
            cursor += 1
            while cursor < len(source) and source[cursor] in SPACE:
                cursor += 1
            yield 'space', source[start:cursor]
            continue
        comment = source.startswith('--', cursor)
        opening = LONG.match(source, cursor + (2 if comment else 0))
        if opening:
            ending = ']' + opening.group(1) + ']'
            end = source.find(ending, opening.end())
            if end < 0:
                raise ValueError('Unterminated long string/comment')
            cursor = end + len(ending)
            yield 'comment' if comment else 'string', source[start:cursor]
            continue
        if comment:
            endings = [at for at in (source.find('\n', cursor), source.find('\r', cursor)) if at >= 0]
            cursor = min(endings) if endings else len(source)
            yield 'comment', source[start:cursor]
            continue
        if char in "\"'":
            quote = char
            cursor += 1
            while cursor < len(source):
                current = source[cursor]
                if current == '\\':
                    cursor += 1
                    if cursor >= len(source):
                        break
                    escape = source[cursor]
                    cursor += 1
                    if escape == 'z':
                        while cursor < len(source) and source[cursor] in SPACE:
                            cursor += 1
                    elif escape == '\r' and cursor < len(source) and source[cursor] == '\n':
                        cursor += 1
                elif current == quote:
                    cursor += 1
                    yield 'string', source[start:cursor]
                    break
                elif current in '\r\n':
                    raise ValueError('Unescaped newline in quoted string')
                else:
                    cursor += 1
            else:
                raise ValueError('Unterminated quoted string')
            if cursor > len(source) or source[cursor - 1] != quote:
                raise ValueError('Unterminated quoted string')
            continue
        match = IDENTIFIER.match(source, cursor)
        if match:
            cursor = match.end()
            yield 'identifier', match.group()
            continue
        if char.isdigit() or char == '.' and cursor + 1 < len(source) and source[cursor + 1].isdigit():
            match = NUMBER.match(source, cursor)
            if not match:
                raise ValueError('Unsupported numeral')
            cursor = match.end()
            if cursor < len(source) and (source[cursor].isalnum() or source[cursor] == '_'):
                raise ValueError('Unsupported numeral suffix')
            yield 'number', match.group()
            continue
        operator = next((value for value in OPERATORS if source.startswith(value, cursor)), None)
        if operator:
            cursor += len(operator)
            yield 'symbol', operator
            continue
        if char in SYMBOLS:
            cursor += 1
            yield 'symbol', char
            continue
        raise ValueError('Unsupported Luau character: ' + repr(char))


def code_tokens(source):
    return [(kind, value) for kind, value in tokens(source) if kind not in ('space', 'comment')]


def needs_space(previous, current):
    if previous is None:
        return False
    left_kind, left = previous
    right_kind, right = current
    if left_kind in ('identifier', 'number') and right_kind in ('identifier', 'number'):
        return True
    if left_kind == 'number' and right.startswith('.') or left.endswith('.') and right_kind == 'number':
        return True
    if left[-1:] + right[:1] in ('--', '..', '//', '==', '~=', '<=', '>=', '::', '+=', '-=', '*=', '/=', '%=', '^=', '->', '<<', '>>', '[['):
        return True
    if left + right in OPERATORS or left == '[' and right.startswith('[='):
        return True
    return False


def compact(source):
    output, previous = [], None
    for kind, value in tokens(source):
        if kind == 'space':
            breaks = ''.join(char for char in value if char in '\r\n')
            if breaks:
                output.append(breaks)
                previous = None
        elif kind == 'comment':
            if value.startswith(('--!', '-- GENERATED')) or value.strip() == '-- Runtime':
                if previous is not None:
                    output.append(' ')
                output.append(value)
                previous = None
            else:
                breaks = ''.join(char for char in value if char in '\r\n')
                if breaks:
                    output.append(breaks)
                    previous = None
        else:
            current = kind, value
            if needs_space(previous, current):
                output.append(' ')
            output.append(value)
            previous = current
    result = ''.join(output)
    if (result.count('\n') != source.count('\n') or result.count('\r') != source.count('\r')
            or code_tokens(result) != code_tokens(source)):
        raise ValueError('Compaction changed code tokens or line mapping')
    return result
