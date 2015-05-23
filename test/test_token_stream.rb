require 'minitest/autorun'
require 'docopt'


class TestTokenStream < MiniTest::Unit::TestCase
  def test_create_with_array
    array = %w(a b c)
    tokens = Docopt::TokenStream.new(array, nil)
    array.each_with_index do |v, i|
      assert_equal tokens[i], v
    end
  end

  def test_create_with_string
    array = %w(a b c)
    tokens = Docopt::TokenStream.new(array.join(' '), nil)
    array.each_with_index do |v, i|
      assert_equal tokens[i], v
    end
  end

  def test_move
    array = %w(a b c)
    tokens = Docopt::TokenStream.new(array, nil)
    array.each do |v|
      assert_equal tokens[0], v
      tokens.move
    end
  end

  def test_current
    array = %w(a b c)
    tokens = Docopt::TokenStream.new(array, nil)
    array.each do |v|
      assert_equal tokens.current, v
      tokens.move
    end
  end
end
