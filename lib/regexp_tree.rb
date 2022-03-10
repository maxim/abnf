require 'prettyprint'
require 'natset'

require 'regexp_tree/alt'
require 'regexp_tree/char_class'
require 'regexp_tree/paren'
require 'regexp_tree/alt'
require 'regexp_tree/rep'
require 'regexp_tree/seq'
require 'regexp_tree/special'

# RegexpTree represents regular expression.
# It can be converted to Regexp.
class RegexpTree
  PRECEDENCE = 1

  EmptySet = Alt.new([])
  EmptySequence = Seq.new([])

  class << self
    # Returns an instance of RegexpTree which is alternation of
    # ((|regexp_trees|)).
    def alt(*trees)
      result = []

      trees.each do |tree|
        next if tree.empty_set?

        case tree
        when Alt
          result.concat(tree.rs)
        when CharClass
          if CharClass === result.last
            result[-1] = CharClass.new(result.last.natset + tree.natset)
          else
            result << tree
          end
        else
          result << tree
        end
      end

      return EmptySet if result.empty?
      return result.first if result.one?
      Alt.new(result)
    end

    # Returns an instance of RegexpTree which is concatination of
    # ((|regexp_trees|)).
    def seq(*trees)
      result = []

      trees.each do |tree|
        next if tree.empty_sequence?

        if Seq === tree
          result.concat tree.rs
        elsif tree.empty_set?
          return EmptySet
        else
          result << tree
        end
      end

      return EmptySequence if result.empty?
      return result.first if result.one?
      Seq.new(result)
    end

    # Returns an instance of RegexpTree which is repetition of
    # ((|regexp_tree|)).
    def rep(r, m=0, n=nil, greedy=true)
      return EmptySequence if m == 0 && n == 0
      return r if m == 1 && n == 1
      return EmptySequence if r.empty_sequence?
      if r.empty_set?
        return m == 0 ? EmptySequence : EmptySet
      end
      Rep.new(r, m, n, greedy)
    end

    def charclass(natset)
      if natset.empty?
        EmptySet
      else
        CharClass.new(natset)
      end
    end

    def linebeg; Special.new('^') end
    def lineend; Special.new('$') end
    def strbeg; Special.new('\A') end
    def strend; Special.new('\z') end
    def strlineend; Special.new('\Z') end
    def word_boundary; Special.new('\b') end
    def non_word_boundary; Special.new('\B') end
    def previous_match; Special.new('\G') end
    def backref(n); Special.new("\\#{n}") end

    # def comment(str) ... end # (?#...)

    # Returns an instance of RegexpTree which only matches ((|string|)).
    def str(str)
      ccs = []
      str.each_byte {|ch|
        ccs << CharClass.new(Natset[ch])
      }
      seq(*ccs)
    end
  end

  def parenthesize(target)
    target::PRECEDENCE <= self.class::PRECEDENCE ? self : Paren.new(self)
  end

  def pretty_print(pp)
    case_insensitive = case_insensitive?
    pp.group(3, '%r{', '}x') {
      (case_insensitive ? self.downcase : self).pretty_format(pp)
    }
    pp.text 'i' if case_insensitive
  end

  def inspect
    case_insensitive = case_insensitive? ? "i" : ""
    r = PrettyPrint.singleline_format('') { |out|
      (case_insensitive ? self.downcase : self).pretty_format(out)
    }
    if %r{/} =~ r
      "%r{#{r}}#{case_insensitive}"
    else
      "%r/#{r}/#{case_insensitive}"
    end
  end

  # Convert to Regexp. If ((|anchored|)) is true, the Regexp is anchored by
  # (({\A})) and (({\z})).
  def regexp(anchored=false)
    if case_insensitive?
      r = downcase
      opt = Regexp::IGNORECASE
    else
      r = self
      opt = 0
    end
    r = RegexpTree.seq(RegexpTree.strbeg, r, RegexpTree.strend) if anchored
    Regexp.compile \
      PrettyPrint.singleline_format('') { |out| r.pretty_format(out) },
      opt
  end

  def to_s
    PrettyPrint.singleline_format('') {|out|
      # x flag is not required because all whitespaces are escaped.
      if case_insensitive?
        out.text '(?i-m:'
        downcase.pretty_format(out)
        out.text ')'
      else
        out.text '(?-im:'
        pretty_format(out)
        out.text ')'
      end
    }
  end

  # Returns true iff self never matches.
  def empty_set?
    false
  end

  # Returns true iff self only matches empty string.
  def empty_sequence?
    false
  end

  # Returns alternation of ((|self|)) and ((|other|)).
  def |(other)
    RegexpTree.alt(self, other)
  end

  # Returns concatination of ((|self|)) and ((|other|)).
  def +(other)
    RegexpTree.seq(self, other)
  end

  # Returns ((|n|)) times repetition of ((|self|)).
  def *(n)
    case n
    when Integer
      RegexpTree.rep(self, n, n)
    when Range
      RegexpTree.rep(self, n.first, n.last - (n.exclude_end? ? 1 : 0))
    else
      raise TypeError.new("Integer or Range expected: #{n}")
    end
  end

  def nongreedy_closure() RegexpTree.rep(self, 0, nil, false) end
  def nongreedy_positive_closure() RegexpTree.rep(self, 1, nil, false) end
  def nongreedy_optional() RegexpTree.rep(self, 0, 1, false) end
  def nongreedy_ntimes(m, n=m) RegexpTree.rep(self, m, n, false) end
  def nongreedy_rep(m=0, n=nil) RegexpTree.rep(self, m, n, false) end
  def closure(greedy=true) RegexpTree.rep(self, 0, nil, greedy) end
  def positive_closure(greedy=true) RegexpTree.rep(self, 1, nil, greedy) end
  def optional(greedy=true) RegexpTree.rep(self, 0, 1, greedy) end
  def ntimes(m, n=m, greedy=true) RegexpTree.rep(self, m, n, greedy) end

  # Returns ((|min|)) to ((|max|)) times repetation of ((|self|)).
  def rep(m=0, n=nil, greedy=true) RegexpTree.rep(self, m, n, greedy) end

  def group() Paren.new(self, '') end
  def paren() Paren.new(self) end
  def lookahead() Paren.new(self, '?=') end
  def negative_lookahead() Paren.new(self, '?!') end
end
