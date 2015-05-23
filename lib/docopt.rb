module Docopt
  VERSION = '0.5.0'

  extend self

  @usage = ''

  def self.usage
    @usage
  end

  class DocoptLanguageError < SyntaxError
  end

  class Exit < RuntimeError
    def initialize(message='')
      super("#{message}\n#{Docopt.usage}".strip)
    end
  end


  class Pattern
    attr_accessor :children

    def initialize
      @children = []
    end

    def ==(other)
      inspect == other.inspect
    end

    alias eql? ==

    def dump
      puts ::Docopt::dump_patterns(self)
    end

    def fix
      fix_identities
      fix_list_arguments
      self
    end

    def fix_identities(uniq=nil)
      return self if children.nil?
      uniq ||= flat.uniq

      @children.each_with_index do |c, i|
        if c.children.nil?
          raise RuntimeError unless uniq.include?(c)
          @children[i] = uniq[uniq.index(c)]
        else
          c.fix_identities(uniq)
        end
      end
    end

    def fix_list_arguments
      either_groups.each do |case_|
        case_.uniq.select { |c| case_.count(c) > 1 }.each do |e|
          if e.class == Argument or (e.class == Option and e.argcount > 0)
            e.value = []
          elsif e.class == Command or (e.class == Option and e.argcount == 0)
            e.value = 0
          end
        end
      end
      self
    end

    def extract(children, *classes)
      int = children.find { |c| classes.include? c.class }
      yield children.slice! children.index(int) unless int.nil?
      int
    end

    def either_groups
      groups = [[self]]
      while groups.count > 0
        children = groups.shift
        next if extract(children, Either) do |i|
          groups += i.children.inject([]) { |g, c| g << [c] + children; g }
        end
        next if extract(children, Required, Optional) do |i|
          groups << i.children + children
        end
        next if extract(children, OneOrMore) do |i|
          groups << (i.children * 2) + children
          next
        end
        (ret ||= []) << children
      end
      ret
    end
  end


  class ChildPattern < Pattern
    attr_accessor :name, :value

    def initialize(name, value=nil)
      @name = name
      @value = value
    end

    def inspect
      "#{self.class.name}(#{name}, #{value})"
    end

    def flat
      [self]
    end

    def match(left, collected=[])
      pos, match = single_match(left)
      return [false, left, collected] if match == nil
      left_ = left[0...pos] + left[pos+1..-1]

      same_name = collected.select { |a| a.name == name }
      if @value.is_a? Array or @value.is_a? Integer
        increment = @value.is_a?(Integer) ? 1 : [match.value]
        if same_name.count == 0
          match.value = increment
          return [true, left_, collected + [match]]
        end
        same_name[0].value += increment
        return [true, left_, collected]
      end
      [true, left_, collected + [match]]
    end
  end

  class ParentPattern < Pattern
    attr_accessor :children

    def initialize(*children)
      @children = children
    end

    def inspect
      child_str = children.map { |a| a.inspect }
      "#{self.class.name}(#{child_str.join(", ")})"
    end

    def flat
      children.map { |c| c.flat }.flatten
    end
  end


  class Argument < ChildPattern

    def single_match(left)
      left.each_with_index do |p, n|
        return n, Argument.new(name, p.value) if p.class == Argument
      end
      [nil, nil]
    end
  end


  class Command < Argument
    def initialize(name, value=false)
      @name = name
      @value = value
    end

    def single_match(left)
      left.each_with_index do |p, n|
        if p.class == Argument
          return n, Command.new(name, true) if p.value == name
          break
        end
      end
      [nil, nil]
    end
  end


  class Option < ChildPattern
    attr_reader :short, :long
    attr_accessor :argcount

    def initialize(short=nil, long=nil, argcount=0, value=false)
      raise RuntimeError unless [0, 1].include? argcount
      @short, @long, @argcount = short, long, argcount
      @value = (value == false and argcount > 0) ? nil : value
    end

    def self.parse(option_description)
      short, long, argcount, val = nil, nil, 0, false
      options, _, description = option_description.strip.partition('  ')
      for s in options.split(/[\s,=]+/)
        if s.start_with?('--')
          long = s
        elsif s.start_with?('-')
          short = s
        else
          argcount = 1
          val = $1 if description =~ /\[default: (.*)\]/i
        end
      end
      new(short, long, argcount, val)
    end

    def single_match(left)
      left.each_with_index do |p, n|
        return n, p if name == p.name
      end
      [nil, nil]
    end

    def name
      long or short
    end

    def inspect
      "Option(#{short}, #{long}, #{argcount}, #{value})"
    end
  end

  class Required < ParentPattern
    def match(left, collected=[])
      l, c = left, collected
      if children.all? { |p| matched, l, c = p.match(l, c); matched }
        return true, l, c
      end
      [false, left, collected]
    end
  end

  class Optional < ParentPattern
    def match(left, collected=[])
      children.each do |p|
        _, left, collected = p.match(left, collected)
      end
      [true, left, collected]
    end
  end

  class OneOrMore < ParentPattern
    def match(left, collected=[])
      raise RuntimeError unless children.count == 1

      l = left
      c = collected
      l_ = nil
      matched = true
      times = 0
      while matched
        # could it be that something didn't match but changed l or c?
        matched, l, c = children[0].match(l, c)
        times += 1 if matched
        break if l_ == l
        l_ = l
      end
      return true, l, c if times >= 1
      [false, left, collected]
    end
  end

  class Either < ParentPattern
    def match(left, collected=[])
      outcomes = []
      children.each do |p|
        matched, _, _ = outcome = p.match(left, collected)
        outcomes << outcome if matched
      end

      return outcomes.min_by { |o| o[1].count } unless outcomes == []
      [false, left, collected]
    end
  end

  class TokenStream < Array
    attr_reader :error
    alias_method :move, :shift
    alias_method :current, :first

    def initialize(source, error)
      source = source.split if source.respond_to? :split
      super source || []
      @error = error
    end
  end

  private

  def parse_long(tokens, options)
    raw, eq, value = tokens.move.partition('=')
    value = (eq == value and eq == '') ? nil : value
    opt = options.select { |o| o.long and o.long == raw }
    if tokens.error == Exit and opt == []
      opt = options.select { |o| o.long and o.long.start_with?(raw) }
    end

    if opt.count < 1
      raise tokens.error, "#{raw} is not recognized" if tokens.error == Exit
      o = Option.new(nil, raw, eq == '=' ? 1 : 0)
      options << o
      return [o]
    elsif opt.count > 1
      raise tokens.error, "#{raw} is not a unique prefix: #{opt.map { |op| op.long }.join(', ')}?"
    end

    o = opt[0]
    opt = Option.new(o.short, o.long, o.argcount, o.value)
    if opt.argcount == 1
      if value == nil
        raise tokens.error, "#{opt.name} requires argument" if tokens.current.nil?
        value = tokens.move
      end
    elsif value != nil
      raise tokens.error, "#{opt.name} must not have an argument"
    end
    opt.value = if tokens.error == Exit
                  value ? value : true
                else
                  value ? nil : false
                end
    [opt]
  end

  def parse_shorts(tokens, options)
    raw = tokens.move[1..-1]
    parsed = []
    while raw != ''
      first = raw.slice(0, 1)
      opt = options.select { |o| o.short and o.short.sub(/^-+/, '').start_with?(first) }

      raise tokens.error, "-#{first} is specified ambiguously #{opt.count} times" if opt.count > 1

      if opt.count < 1
        raise tokens.error, "-#{first} is not recognized" if tokens.error == Exit
        o = Option.new('-' + first, nil)
        options << o
        parsed << o
        raw.slice! 0
        next
      end

      o = opt[0]
      opt = Option.new(o.short, o.long, o.argcount, o.value)
      raw.slice! 0
      if opt.argcount == 0
        value = tokens.error == Exit ? true : false
      else
        if raw == ''
          raise tokens.error, "-#{opt.short.slice(0, 1)} requires argument" if tokens.current.nil?
          raw = tokens.move
        end
        value, raw = raw, ''
      end

      opt.value = if tokens.error == Exit
                    value
                  else
                    value ? nil : false
                  end
      parsed << opt
    end
    parsed
  end

  def parse_pattern(source, options)
    tokens = TokenStream.new(source.gsub(/([\[\]()|]|\.{3})/, ' \1 '), DocoptLanguageError)
    result = parse_expr(tokens, options)
    raise tokens.error, "unexpected ending: #{tokens.join(" ")}" unless tokens.current.nil?
    Required.new(*result)
  end

  def parse_expr(tokens, options)
    seq = parse_seq(tokens, options)
    return seq unless tokens.current == '|'
    result = seq.count > 1 ? [Required.new(*seq)] : seq

    while tokens.current == '|'
      tokens.move
      seq = parse_seq(tokens, options)
      result += seq.count > 1 ? [Required.new(*seq)] : seq
    end
    result.count > 1 ? [Either.new(*result)] : result
  end

  def parse_seq(tokens, options)
    result = []
    stop = [nil, ']', ')', '|']
    until stop.include?(tokens.current)
      atom = parse_atom(tokens, options)
      if tokens.current == '...'
        atom = [OneOrMore.new(*atom)]
        tokens.move
      end
      result += atom
    end
    result
  end

  def parse_atom(tokens, options)
    token = tokens.current
    if '(['.include? token
      tokens.move
      matching, pattern = {'(' => [')', Required], '[' => [']', Optional]}[token]
      result = pattern.new(*parse_expr(tokens, options))
      raise tokens.error, "unmatched '#{token}'" if tokens.move != matching
      return [result]
    elsif token == 'options'
      tokens.move
      return options
    elsif token.start_with?('--') and token != '--'
      return parse_long(tokens, options)
    elsif token.start_with?('-') and not %w(- --).include? token
      return parse_shorts(tokens, options)
    elsif token.start_with?('<') and token.end_with?('>') or (token.upcase == token and token.downcase != token)
      return [Argument.new(tokens.move)]
    end
    [Command.new(tokens.move)]
  end

  def parse_argv(source, options, options_first: false)
    tokens = TokenStream.new(source, Exit)
    parsed = []
    while tokens.current != nil
      if tokens.current == '--'
        return parsed + tokens.map { |v| Argument.new(nil, v) }
      elsif tokens.current.start_with?('--')
        parsed += parse_long(tokens, options)
      elsif tokens.current.start_with?('-') and tokens.current != '-'
        parsed += parse_shorts(tokens, options)
      elsif options_first
        return parsed + tokens.map { |t| Argument.new(nil, t) }
      else
        parsed << Argument.new(nil, tokens.move)
      end
    end
    parsed
  end

  def parse_doc_options(doc)
    doc.split(/^ *-|\n *-/)[1..-1].map { |s| Option.parse('-' + s) }
  end

  def printable_usage(doc)
    usage_split = doc.split(/(usage:)/i)
    if usage_split.count < 3
      raise DocoptLanguageError, '"usage:" (case-insensitive) not found.'
    elsif usage_split.count > 3
      raise DocoptLanguageError, 'More than one "usage:" (case-insensitive).'
    end
    usage_split[1, 2].join.split(/\n\s*\n/)[0].strip
  end

  def formal_usage(printable_usage)
    pu = printable_usage.split[1..-1] # split and drop "usage:"
    '( ' + pu[1..-1].map { |e| e == pu[0] ? ') | (' : e }.join(' ') + ' )'
  end

  def dump_patterns(pattern, indent=0)
    ws = " " * 4 * indent
    out = ""
    if pattern.class == Array
      if pattern.count > 0
        out << ws << "[\n"
        for p in pattern
          out << dump_patterns(p, indent+1).rstrip << "\n"
        end
        out << ws << "]\n"
      else
        out << ws << "[]\n"
      end

    elsif pattern.class.ancestors.include?(ParentPattern)
      out << ws << pattern.class.name << "(\n"
      for p in pattern.children
        out << dump_patterns(p, indent+1).rstrip << "\n"
      end
      out << ws << ")\n"

    else
      out << ws << pattern.inspect
    end
    out
  end

  def extras(help, version, options, doc)
    abort doc.strip if help and options.any? { |o| %w(-h --help).include?(o.name) }
    abort version if version and options.any? { |o| '--version' == o.name }
  end

  public
  def docopt(doc, params={})
    params = {help: true}.merge(params)
    @usage = printable_usage(doc)
    options = parse_doc_options(doc)
    argv = params[:argv] || ARGV
    pattern = parse_pattern(formal_usage(@usage), options)
    args = parse_argv(argv, options, options_first: params.fetch(:options_first, false))
    extras(params[:help], params[:version], args, doc)
    matched, left, collected = pattern.fix.match(args)
    raise Exit unless matched and left == []
    (pattern.flat + options + (collected || [])).inject({}) { |h, p| h[p.name] = p.value; h }
  end


end
