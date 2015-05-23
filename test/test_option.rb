require 'minitest/autorun'
require 'docopt'

class DocoptOptionTest < MiniTest::Unit::TestCase

  include Docopt

  def test_option
    assert_equal Option.parse('-h'), Option.new('-h')
    assert_equal Option.parse('--help'), Option.new(nil, '--help')
    assert_equal Option.parse('-h --help'), Option.new('-h', '--help')
    assert_equal Option.parse('-h, --help'), Option.new('-h', '--help')

    assert_equal Option.parse('-h TOPIC'), Option.new('-h', nil, 1)
    assert_equal Option.parse('--help TOPIC'), Option.new(nil, '--help', 1)
    assert_equal Option.parse('-h TOPIC --help TOPIC'), Option.new('-h', '--help', 1)
    assert_equal Option.parse('-h TOPIC, --help TOPIC'), Option.new('-h', '--help', 1)
    assert_equal Option.parse('-h TOPIC, --help=TOPIC'), Option.new('-h', '--help', 1)

    assert_equal Option.parse('-h  Description...'), Option.new('-h')
    assert_equal Option.parse('-h --help  Description...'), Option.new('-h', '--help')
    assert_equal Option.parse('-h TOPIC  Description...'), Option.new('-h', nil, 1)

    assert_equal Option.parse('    -h'), Option.new('-h')

    assert_equal Option.parse('-h TOPIC  Descripton... [default: 2]'),
                 Option.new('-h', nil, 1, '2')
    assert_equal Option.parse('-h TOPIC  Descripton... [default: topic-1]'),
                 Option.new('-h', nil, 1, 'topic-1')
    assert_equal Option.parse('--help=TOPIC  ... [default: 3.14]'),
                 Option.new(nil, '--help', 1, '3.14')
    assert_equal Option.parse('-h, --help=DIR  ... [default: ./]'),
                 Option.new('-h', '--help', 1, "./")
    assert_equal Option.parse('-h TOPIC  Descripton... [dEfAuLt: 2]'),
                 Option.new('-h', nil, 1, '2')

  end

  def test_option_name
    assert_equal Option.new('-h', nil).name, '-h'
    assert_equal Option.new('-h', '--help').name, '--help'
    assert_equal Option.new(nil, '--help').name, '--help'
  end
end
