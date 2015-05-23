require 'minitest/autorun'
require 'docopt'

class DocoptTest < MiniTest::Unit::TestCase

  include Docopt

  def test_pattern_flat
    assert Required.new(
             OneOrMore.new(Argument.new('N')),
             Option.new('-a'), Argument.new('M')
           ).flat == [Argument.new('N'), Option.new('-a'), Argument.new('M')]
  end

  def test_any_options
    doc = <<-DOC
      Usage: prog [options] A

      -q  Be quiet
      -v  Be verbose.
    DOC

    assert docopt(doc, argv: 'arg') == {'A' => 'arg', '-v' => false, '-q' => false}
    assert docopt(doc, argv: '-v arg') == {'A' => 'arg', '-v' => true, '-q' => false}
    assert docopt(doc, argv: '-q arg') == {'A' => 'arg', '-v' => false, '-q' => true}
  end

  def test_commands
    assert_equal docopt('Usage: prog add', argv: 'add'), {'add' => true}
    assert_equal docopt('Usage: prog [add]', argv: ''), {'add' => false}
    assert_equal docopt('Usage: prog [add]', argv: 'add'), {'add' => true}
    assert_equal docopt('Usage: prog (add|rm)', argv: 'add'), {'add' => true, 'rm' => false}
    assert_equal docopt('Usage: prog (add|rm)', argv: 'rm'), {'add' => false, 'rm' => true}
    assert_equal docopt('Usage: prog a b', argv: 'a b'), {'a' => true, 'b' => true}
    assert_raises(Exit) { docopt('Usage: prog a b', argv: 'b a') }
  end


  def test_parse_doc_options
    doc = <<-DOC
      -h, --help  Print help message.
      -o FILE     Output file.
      --verbose   Verbose mode.
    DOC
    assert parse_doc_options(doc) == [Option.new('-h', '--help'),
                                      Option.new('-o', nil, 1),
                                      Option.new(nil, '--verbose')]
  end

  def test_printable_and_formal_usage
    doc = <<-DOC
    Usage: prog [-hv] ARG
           prog N M

    prog is a program.DOC
    DOC
    assert printable_usage(doc) == "Usage: prog [-hv] ARG\n           prog N M"
    assert formal_usage(printable_usage(doc)) == "( [-hv] ARG ) | ( N M )"
    assert printable_usage("uSaGe: prog ARG\n\t \t\n bla") == "uSaGe: prog ARG"
  end


  def test_parse_argv
    o = [Option.new('-h'), Option.new('-v', '--verbose'), Option.new('-f', '--file', 1)]
    assert parse_argv('', o) == []
    assert parse_argv('-h', o) == [Option.new('-h', nil, 0, true)]
    assert parse_argv('-h --verbose', o) == \
            [Option.new('-h', nil, 0, true), Option.new('-v', '--verbose', 0, true)]
    assert parse_argv('-h --file f.txt', o) == \
            [Option.new('-h', nil, 0, true), Option.new('-f', '--file', 1, 'f.txt')]
    assert parse_argv('-h --file f.txt arg', o) == \
            [Option.new('-h', nil, 0, true),
             Option.new('-f', '--file', 1, 'f.txt'),
             Argument.new(nil, 'arg')]
    assert parse_argv('-h --file f.txt arg arg2', o) == \
            [Option.new('-h', nil, 0, true),
             Option.new('-f', '--file', 1, 'f.txt'),
             Argument.new(nil, 'arg'),
             Argument.new(nil, 'arg2')]
    assert parse_argv('-h arg -- -v', o) == \
            [Option.new('-h', nil, 0, true),
             Argument.new(nil, 'arg'),
             Argument.new(nil, '--'),
             Argument.new(nil, '-v')]
  end


  def test_parse_pattern
    o = [Option.new('-h'), Option.new('-v', '--verbose'), Option.new('-f', '--file', 1)]
    assert parse_pattern('[ -h ]', o) == \
               Required.new(Optional.new(Option.new('-h')))
    assert parse_pattern('[ ARG ... ]', o) == \
               Required.new(Optional.new(OneOrMore.new(Argument.new('ARG'))))
    assert parse_pattern('[ -h | -v ]', o) == \
               Required.new(Optional.new(Either.new(Option.new('-h'),
                                                    Option.new('-v', '--verbose'))))
    assert parse_pattern('( -h | -v [ --file <f> ] )', o) == \
               Required.new(Required.new(Either.new(Option.new('-h'),
                                                    Required.new(Option.new('-v', '--verbose'),
                                                                 Optional.new(Option.new('-f', '--file', 1, nil))))))
    assert parse_pattern('(-h|-v[--file=<f>]N...)', o) == \
               Required.new(Required.new(Either.new(Option.new('-h'),
                                                    Required.new(Option.new('-v', '--verbose'),
                                                                 Optional.new(Option.new('-f', '--file', 1, nil)),
                                                                 OneOrMore.new(Argument.new('N'))))))
    assert parse_pattern('(N [M | (K | L)] | O P)', []) == \
               Required.new(Required.new(Either.new(
                                                                                                      Required.new(Argument.new('N'),
                                                                                                                   Optional.new(Either.new(Argument.new('M'),
                                                                                                                                           Required.new(Either.new(Argument.new('K'),
                                                                                                                                                                   Argument.new('L')))))),
                                                                                                      Required.new(Argument.new('O'), Argument.new('P')))))
    assert parse_pattern('[ -h ] [N]', o) == \
               Required.new(Optional.new(Option.new('-h')),
                            Optional.new(Argument.new('N')))
    assert parse_pattern('[options]', o) == Required.new(
             Optional.new(*o))
    assert parse_pattern('[options] A', o) == Required.new(
             Optional.new(*o),
             Argument.new('A'))
    assert parse_pattern('-v [options]', o) == Required.new(
             Option.new('-v', '--verbose'),
             Optional.new(*o))

    assert parse_pattern('ADD', o) == Required.new(Argument.new('ADD'))
    assert parse_pattern('<add>', o) == Required.new(Argument.new('<add>'))
    assert parse_pattern('add', o) == Required.new(Command.new('add'))
  end

  def test_option_match
    assert Option.new('-a').match([Option.new('-a', nil, 0, true)]) == \
            [true, [], [Option.new('-a', nil, 0, true)]]
    assert Option.new('-a').match([Option.new('-x')]) == [false, [Option.new('-x')], []]
    assert Option.new('-a').match([Argument.new('N')]) == [false, [Argument.new('N')], []]
    assert Option.new('-a').match([Option.new('-x'), Option.new('-a'), Argument.new('N')]) == \
            [true, [Option.new('-x'), Argument.new('N')], [Option.new('-a')]]
    assert Option.new('-a').match([Option.new('-a', nil, 0, true), Option.new('-a')]) == \
            [true, [Option.new('-a')], [Option.new('-a', nil, 0, true)]]
  end

  def test_argument_match
    assert Argument.new('N').match([Argument.new(nil, 9)]) == [
             true, [], [Argument.new('N', 9)]]
    assert Argument.new('N').match([Option.new('-x')]) == [false, [Option.new('-x')], []]
    assert Argument.new('N').match([Option.new('-x'), Option.new('-a'), Argument.new(nil, 5)])\
            == [true, [Option.new('-x'), Option.new('-a')], [Argument.new('N', 5)]]
    assert Argument.new('N').match([Argument.new(nil, 9), Argument.new(nil, 0)]) == [
             true, [Argument.new(nil, 0)], [Argument.new('N', 9)]]
  end

  def test_command_match
    assert Command.new('c').match([Argument.new(nil, 'c')]) == [
             true, [], [Command.new('c', true)]]
    assert Command.new('c').match([Option.new('-x')]) == [false, [Option.new('-x')], []]
    assert Command.new('c').match([Option.new('-x'), Option.new('-a'),
                                   Argument.new(nil, 'c')]) == [
             true, [Option.new('-x'), Option.new('-a')], [Command.new('c', true)]]
    assert Either.new(Command.new('add', false), Command.new('rm', false)).match(
             [Argument.new(nil, 'rm')]) == [true, [], [Command.new('rm', true)]]
  end

  def test_optional_match
    assert_equal Optional.new(Option.new('-a')).match([Option.new('-a')]),
                 [true, [], [Option.new('-a')]]
    assert_equal Optional.new(Option.new('-a')).match([]), [true, [], []]
    assert_equal Optional.new(Option.new('-a')).match([Option.new('-x')]),
                 [true, [Option.new('-x')], []]
    assert_equal Optional.new(Option.new('-a'), Option.new('-b')).match([Option.new('-a')]),
                 [true, [], [Option.new('-a')]]
    assert_equal Optional.new(Option.new('-a'), Option.new('-b')).match([Option.new('-b')]),
                 [true, [], [Option.new('-b')]]
    assert_equal Optional.new(Option.new('-a'), Option.new('-b')).match([Option.new('-x')]),
                 [true, [Option.new('-x')], []]
    assert_equal Optional.new(Argument.new('N')).match([Argument.new(nil, 9)]),
                 [true, [], [Argument.new('N', 9)]]
    assert_equal Optional.new(Option.new('-a'), Option.new('-b')).match(
                   [Option.new('-b'), Option.new('-x'), Option.new('-a')]),
                 [true, [Option.new('-x')], [Option.new('-a'), Option.new('-b')]]
  end


  def test_required_match
    assert_equal Required.new(Option.new('-a')).match([Option.new('-a')]),
                 [true, [], [Option.new('-a')]]
    assert_equal Required.new(Option.new('-a')).match([]), [false, [], []]
    assert_equal Required.new(Option.new('-a')).match([Option.new('-x')]), [
                                                                           false, [Option.new('-x')], []]
    assert_equal Required.new(Option.new('-a'), Option.new('-b')).match([Option.new('-a')]),
                 [false, [Option.new('-a')], []]
  end


  def test_either_match
    assert_equal Either.new(Option.new('-a'), Option.new('-b')).match([Option.new('-a')]),
                 [true, [], [Option.new('-a')]]
    assert_equal Either.new(Option.new('-a'), Option.new('-b')).match(
                   [Option.new('-a'), Option.new('-b')]),
                 [true, [Option.new('-b')], [Option.new('-a')]]
    assert_equal Either.new(Option.new('-a'), Option.new('-b')).match([Option.new('-x')]),
                 [false, [Option.new('-x')], []]
    assert_equal Either.new(Option.new('-a'), Option.new('-b'), Option.new('-c')).match(
                   [Option.new('-x'), Option.new('-b')]),
                 [true, [Option.new('-x')], [Option.new('-b')]]
    assert_equal Either.new(Argument.new('M'),
                            Required.new(Argument.new('N'), Argument.new('M'))).match(
                   [Argument.new(nil, 1), Argument.new(nil, 2)]),
                 [true, [], [Argument.new('N', 1), Argument.new('M', 2)]]
  end


  def test_one_or_more_match
    assert OneOrMore.new(Argument.new('N')).match([Argument.new(nil, 9)]) ==\
            [true, [], [Argument.new('N', 9)]]
    assert OneOrMore.new(Argument.new('N')).match([]) == [false, [], []]
    assert OneOrMore.new(Argument.new('N')).match([Option.new('-x')]) == \
            [false, [Option.new('-x')], []]
    assert OneOrMore.new(Argument.new('N')).match(
             [Argument.new(nil, 9), Argument.new(nil, 8)]) == [
             true, [], [Argument.new('N', 9), Argument.new('N', 8)]]
    assert OneOrMore.new(Argument.new('N')).match(
             [Argument.new(nil, 9), Option.new('-x'), Argument.new(nil, 8)]) == [
             true, [Option.new('-x')], [Argument.new('N', 9), Argument.new('N', 8)]]
    assert OneOrMore.new(Option.new('-a')).match(
             [Option.new('-a'), Argument.new(nil, 8), Option.new('-a')]) == \
                    [true, [Argument.new(nil, 8)], [Option.new('-a'), Option.new('-a')]]
    assert OneOrMore.new(Option.new('-a')).match([Argument.new(nil, 8), Option.new('-x')]) == [
             false, [Argument.new(nil, 8), Option.new('-x')], []]
    assert OneOrMore.new(Required.new(Option.new('-a'), Argument.new('N'))).match(
             [Option.new('-a'), Argument.new(nil, 1), Option.new('-x'),
              Option.new('-a'), Argument.new(nil, 2)]) == \
             [true, [Option.new('-x')],
              [Option.new('-a'), Argument.new('N', 1), Option.new('-a'), Argument.new('N', 2)]]
    assert OneOrMore.new(Optional.new(Argument.new('N'))).match([Argument.new(nil, 9)]) == \
                    [true, [], [Argument.new('N', 9)]]
  end

  def test_list_argument_match
    assert Required.new(Argument.new('N'), Argument.new('N')).fix.match(
             [Argument.new(nil, '1'), Argument.new(nil, '2')]) == \
                    [true, [], [Argument.new('N', ['1', '2'])]]
    assert OneOrMore.new(Argument.new('N')).fix.match(
             [Argument.new(nil, '1'), Argument.new(nil, '2'), Argument.new(nil, '3')]) == \
                    [true, [], [Argument.new('N', ['1', '2', '3'])]]
    assert Required.new(Argument.new('N'), OneOrMore.new(Argument.new('N'))).fix.match(
             [Argument.new(nil, '1'), Argument.new(nil, '2'), Argument.new(nil, '3')]) == \
                    [true, [], [Argument.new('N', ['1', '2', '3'])]]
    assert Required.new(Argument.new('N'), Required.new(Argument.new('N'))).fix.match(
             [Argument.new(nil, '1'), Argument.new(nil, '2')]) == \
                    [true, [], [Argument.new('N', ['1', '2'])]]
  end


  def test_basic_pattern_matching
    # ( -a N [ -x Z ] )
    pattern = Required.new(Option.new('-a'), Argument.new('N'),
                           Optional.new(Option.new('-x'), Argument.new('Z')))
    # -a N
    assert pattern.match([Option.new('-a'), Argument.new(nil, 9)]) == \
            [true, [], [Option.new('-a'), Argument.new('N', 9)]]
    # -a -x N Z
    assert pattern.match([Option.new('-a'), Option.new('-x'),
                          Argument.new(nil, 9), Argument.new(nil, 5)]) == \
            [true, [], [Option.new('-a'), Argument.new('N', 9),
                        Option.new('-x'), Argument.new('Z', 5)]]
    # -x N Z  # BZZ!
    assert pattern.match([Option.new('-x'),
                          Argument.new(nil, 9),
                          Argument.new(nil, 5)]) == \
            [false, [Option.new('-x'), Argument.new(nil, 9), Argument.new(nil, 5)], []]
  end


  def test_pattern_either
    assert Option.new('-a').either_groups.inspect == [[Option.new('-a')]].inspect
    assert Argument.new('A').either_groups == [[Argument.new('A')]]
    assert Required.new(Either.new(Option.new('-a'), Option.new('-b')), Option.new('-c')).either_groups ==\
            [[Option.new('-a'), Option.new('-c')], [Option.new('-b'), Option.new('-c')]]
    assert Optional.new(Option.new('-a'), Either.new(Option.new('-b'), Option.new('-c'))).either_groups ==\
            [[Option.new('-b'), Option.new('-a')], [Option.new('-c'), Option.new('-a')]]
    assert Either.new(Option.new('-x'), Either.new(Option.new('-y'), Option.new('-z'))).either_groups == \
            [[Option.new('-x')], [Option.new('-y')], [Option.new('-z')]]
    assert OneOrMore.new(Argument.new('N'), Argument.new('M')).either_groups == \
            [[Argument.new('N'), Argument.new('M'), Argument.new('N'), Argument.new('M')]]
  end


  def test_pattern_fix_list_arguments
    assert Option.new('-a').fix_list_arguments == Option.new('-a')
    assert Argument.new('N', nil).fix_list_arguments == Argument.new('N', nil)
    assert Required.new(Argument.new('N'), Argument.new('N')).fix_list_arguments == \
            Required.new(Argument.new('N', []), Argument.new('N', []))
    assert Either.new(Argument.new('N'),
                      OneOrMore.new(Argument.new('N'))).fix == \
           Either.new(Argument.new('N', []),
                      OneOrMore.new(Argument.new('N', [])))
  end


  def test_pattern_fix_identities_1
    pattern = Required.new(Argument.new('N'), Argument.new('N'))
    assert pattern.children[0] == pattern.children[1]
    assert !(pattern.children[0].equal? pattern.children[1])
    pattern.fix_identities
    assert pattern.children[0].equal? pattern.children[1]
  end


  def test_pattern_fix_identities_2
    pattern = Required.new(Optional.new(Argument.new('X'), Argument.new('N')), Argument.new('N'))
    assert pattern.children[0].children[1] == pattern.children[1]
    assert !(pattern.children[0].children[1].equal? pattern.children[1])
    pattern.fix_identities
    assert pattern.children[0].children[1].equal? pattern.children[1]
  end

  def test_long_options_error_handling
    assert_raises(Exit) do
      docopt('Usage: prog', argv: '--non-existent')
    end
    assert_raises(Exit) do
      docopt("Usage: prog [--version --verbose]\n\n
                  --version\n--verbose", argv: '--ver')
    end
    assert_raises(DocoptLanguageError) do
      docopt("Usage: prog --long\n\n--long ARG")
    end
    assert_raises(Exit) do
      docopt("Usage: prog --long ARG\n\n--long ARG", argv: '--long')
    end
    assert_raises(DocoptLanguageError) do
      docopt("Usage: prog --long=ARG\n\n--long")
    end
    assert_raises(Exit) do
      docopt("Usage: prog --long\n\n--long", argv: '--long=ARG')
    end
  end


  def test_short_options_error_handling
    assert_raises(DocoptLanguageError) do
      docopt("Usage: prog -x\n\n-x  this\n-x  that")
    end

    assert_raises(Exit) do
      docopt('Usage: prog', argv: '-x')
    end

    assert_raises(DocoptLanguageError) do
      docopt("Usage: prog -o\n\n-o ARG")
    end
    assert_raises(Exit) do
      docopt("Usage: prog -o ARG\n\n-o ARG", argv: '-o')
    end
  end


  def test_matching_paren
    assert_raises(DocoptLanguageError) do
      docopt('Usage: prog [a [b]')
    end
    assert_raises(DocoptLanguageError) do
      docopt('Usage: prog [a [b] ] c )')
    end
  end


  def test_allow_double_underscore
    assert_equal docopt("usage: prog [-o] [--] <arg>\n\n-o", argv: '-- -o'),
                 {'-o' => false, '<arg>' => '-o', '--' => true}
    assert_equal docopt("/usage: prog [-o] [--] <arg>\n\n-o", argv: '-o 1'),
                 {'-o' => true, '<arg>' => '1', '--' => false}
    assert_raises(Exit) do
      docopt("usage: prog [-o] <arg>\n\n-o", argv: '-- -o') # '--' not allowed
    end
  end


  def test_allow_single_underscore
    assert_equal docopt('usage: prog [-]', argv: '-'), {'-' => true}
    assert_equal docopt('usage: prog [-]', argv: ''), {'-' => false}
  end


  def test_allow_empty_pattern
    assert_equal docopt('usage: prog', argv: ''), {}
  end


  def test_docopt
    doc = <<-DOC
      Usage: prog [-v] A

      -v  Be verbose.
    DOC
    assert_equal docopt(doc, argv: 'arg'), {'-v' => false, 'A' => 'arg'}
    assert_equal docopt(doc, argv: '-v arg'), {'-v' => true, 'A' => 'arg'}

    doc = <<-DOC
      Usage: prog [-vqr] [FILE]
             prog INPUT OUTPUT
             prog --help

      Options:
        -v  print status messages
        -q  report only file names
        -r  show all occurrences of the same error
        --help

    DOC
    a = docopt(doc, argv: '-v file.py')
    assert_equal a, {'-v' => true, '-q' => false, '-r' => false, '--help' => false,
                     'FILE' => 'file.py', 'INPUT' => nil, 'OUTPUT' => nil}

    a = docopt(doc, argv: '-v')
    assert_equal a, {'-v' => true, '-q' => false, '-r' => false, '--help' => false,
                     'FILE' => nil, 'INPUT' => nil, 'OUTPUT' => nil}

    assert_raises(Exit) {# does not match
      docopt(doc, argv: '-v input.py output.py')
    }

    assert_raises(Exit) {
      docopt(doc, argv: '--fake')
    }

    assert_raises(SystemExit) {
      docopt(doc, argv: '--help')
    }
  end


  def test_bug_not_list_argument_if_nothing_matched
    d = 'usage: prog [NAME [NAME ...]]'
    assert_equal docopt(d, argv: 'a b'), {'NAME' => ['a', 'b']}
    assert_equal docopt(d, argv: ''), {'NAME' => []}
  end


  def test_option_arguments_default_to_none
    d = <<-DOC
      usage: prog [options]

      -a        Add
      -m <msg>  Message

    DOC
    assert docopt(d, argv: '-a') == {'-m' => nil, '-a' => true}
  end


  def test_options_without_description
    assert_equal docopt('usage: prog --hello', argv: '--hello'), {'--hello' => true}
    assert_equal docopt('usage: prog [--hello=<world>]', argv: ''), {'--hello' => nil}
    assert_equal docopt('usage: prog [--hello=<world>]', argv: '--hello wrld'), {'--hello' => 'wrld'}
    assert_equal docopt('usage: prog [-o]', argv: ''), {'-o' => false}
    assert_equal docopt('usage: prog [-o]', argv: '-o'), {'-o' => true}
    assert_equal docopt('usage: prog [-opr]', argv: '-op'), {'-o' => true, '-p' => true, '-r' => false}
    assert_equal docopt('usage: git [-v | --verbose]', argv: '-v'), {'-v' => true, '--verbose' => false}
    assert_equal docopt('usage: git remote [-v | --verbose]', argv: 'remote -v'),
                 {'remote' => true, '-v' => true, '--verbose' => false}
  end


  def test_language_errors
    assert_raises(DocoptLanguageError) {
      docopt('no usage with colon here')
    }
    assert_raises(DocoptLanguageError) {
      docopt("usage: here \n\n and again usage: here")
    }
  end

  def test_bug
    assert_equal docopt('usage: prog', argv: ''), {}
    assert_equal docopt("usage: prog \n prog <a> <b>", argv: '1 2'), {'<a>' => '1', '<b>' => '2'}
    assert_equal docopt("usage: prog \n prog <a> <b>", argv: ''), {'<a>' => nil, '<b>' => nil}
    assert_equal docopt("usage: prog <a> <b> \n prog", argv: ''), {'<a>' => nil, '<b>' => nil}
  end


  def test_issue40
    assert_raises(SystemExit) do
      docopt('usage: prog --help-commands | --help', argv: '--help')
    end
    assert_equal docopt('usage: prog --aabb | --aa', argv: '--aa'),
                 {'--aabb' => false, '--aa' => true}
  end

  def test_bug_option_argument_should_not_capture_default_value_from_pattern
    assert_equal docopt('usage: prog [--file=<f>]', argv: ''), {'--file' => nil}
    assert_equal docopt("usage: prog [--file=<f>]\n\n--file <a>", argv: ''), {'--file' => nil}
    doc = <<-DOC
      usage: tau [-a <host:port>]

      -a, --address <host:port>  TCP address [default: localhost:6283].

    DOC
    assert docopt(doc, argv: '') == {'--address' => 'localhost:6283'}
  end

  if /^1\.9/ === RUBY_VERSION then
    def test_issue34_unicode_strings
      begin
        assert_equal docopt('usage: prog [-o <a>]'.encode('utf-8'), argv: ''),
                     {'-o' => false, '<a>' => nil}
      rescue SyntaxError
      end
    end
  end

  def test_count_multiple_flags
    assert_equal docopt('usage: prog [-v]', argv: '-v'), {'-v' => true}
    assert_equal docopt('usage: prog [-vv]', argv: ''), {'-v' => 0}
    assert_equal docopt('usage: prog [-vv]', argv: '-v'), {'-v' => 1}
    assert_equal docopt('usage: prog [-vv]', argv: '-vv'), {'-v' => 2}
    assert_raises(Exit) do
      docopt('usage: prog [-vv]', argv: '-vvv')
    end
    assert_equal docopt('usage: prog [-v | -vv | -vvv]', argv: '-vvv'), {'-v' => 3}
    assert_equal docopt('usage: prog -v...', argv: '-vvvvvv'), {'-v' => 6}
    assert_equal docopt('usage: prog [--ver --ver]', argv: '--ver --ver'), {'--ver' => 2}
  end


  def test_count_multiple_commands
    assert_equal docopt('usage: prog [go]', argv: 'go'), {'go' => true}
    assert_equal docopt('usage: prog [go go]', argv: ''), {'go' => 0}
    assert_equal docopt('usage: prog [go go]', argv: 'go'), {'go' => 1}
    assert_equal docopt('usage: prog [go go]', argv: 'go go'), {'go' => 2}
    assert_raises(Exit) {
      docopt('usage: prog [go go]', argv: 'go go go')
    }
    assert_equal docopt('usage: prog go...', argv: 'go go go go go'), {'go' => 5}
  end


  def test_accumulate_multiple_options
    assert_equal docopt('usage: prog --long=<arg> ...', argv: '--long one'),
                 {'--long' => ['one']}
    assert_equal docopt('usage: prog --long=<arg> ...', argv: '--long one --long two'),
                 {'--long' => ['one', 'two']}
  end


  def test_multiple_different_elements
    assert_equal docopt('usage: prog (go <direction> --speed=<km/h>)...',
                        argv: 'go left --speed=5  go right --speed=9'),
                 {'go' => 2, '<direction>' => ['left', 'right'], '--speed' => ['5', '9']}
  end

  def test_options_first_parse_as_argument
    args = docopt('usage: prog [<args>...]', argv: 'command --opt1 --opt2=val2',
                  options_first: true)
    assert_equal args, {'<args>' => %w(command --opt1 --opt2=val2)}

    assert_raises Docopt::Exit do
      docopt('usage: prog [<args>...]', argv: 'command --opt1 --opt2')
    end
  end

  def test_options_first_get_options
    args = docopt('usage: prog --opt1 --opt2=<opt2>  [<args>...]',
                  argv: '--opt1 --opt2=val2 command',
                  options_first: true)
    assert_equal args['--opt1'], true
    assert_equal args['--opt2'], 'val2'
    assert_equal args['<args>'], ['command']
    assert_raises Docopt::Exit do
      docopt('usage: prog [<args>...]', argv: '--opt1 --opt2=val2 command',
             options_first: true)
    end
  end

end
