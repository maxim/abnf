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

  EMPTY_SET = Alt.new([])
  EMPTY_SEQ = Seq.new([])
  STR_BEG   = Special.new('\A')
  STR_END   = Special.new('\z')

  class << self
    # Returns an instance of RegexpTree which is alternation of
    # ((|regexp_trees|)).
    def alt(*trees)
      result = trees.each_with_object([]) { |tree, result|
        next if tree.empty_set?

        if Alt === tree
          result.concat tree.trees
        elsif CharClass === tree && CharClass === result.last
          result[-1] = CharClass.new(result.last.natset + tree.natset)
        else
          result << tree
        end
      }

      return EMPTY_SET if result.empty?
      return result.first if result.one?
      Alt.new(result)
    end

    # Returns an instance of RegexpTree which is concatination of
    # ((|regexp_trees|)).
    def seq(*trees)
      result = trees.each_with_object([]) { |tree, result|
        return EMPTY_SET if tree.empty_set?
        next if tree.empty_sequence?
        Seq === tree ? result.concat(tree.trees) : result << tree
      }

      return EMPTY_SEQ if result.empty?
      return result.first if result.one?
      Seq.new(result)
    end

    # Returns an instance of RegexpTree which is repetition of
    # ((|regexp_tree|)).
    def rep(tree, min = 0, max = nil, greedy = true)
      return EMPTY_SEQ if min == 0 && max == 0
      return tree      if min == 1 && max == 1
      return EMPTY_SEQ if tree.empty_sequence?
      return (min == 0 ? EMPTY_SEQ : EMPTY_SET) if tree.empty_set?
      Rep.new tree, min, max, greedy
    end

    def char_class(natset)
      natset.empty? ? EMPTY_SET : CharClass.new(natset)
    end

    # def comment(str) ... end # (?#...)

    # Returns an instance of RegexpTree which only matches ((|string|)).
    def str(str)
      seq(*str.each_byte.map { |ch| CharClass.new(Natset[ch]) })
    end
  end

  def parenthesize(target)
    target::PRECEDENCE <= self.class::PRECEDENCE ? self : Paren.new(self)
  end

  def pretty_print(pp)
    case_insensitive = case_insensitive?

    pp.group(3, '%r{', '}x') do
      (case_insensitive ? self.downcase : self).pretty_format(pp)
    end

    pp.text 'i' if case_insensitive
  end

  def inspect
    case_insensitive = case_insensitive? ? "i" : ""

    regex = PrettyPrint.singleline_format('') { |out|
      (case_insensitive ? self.downcase : self).pretty_format(out)
    }

    ((%r{/} =~ regex) ? "%r{#{regex}}" : "%r/#{regex}/") + case_insensitive
  end

  # Convert to Regexp. If ((|anchored|)) is true, the Regexp is anchored by
  # (({\A})) and (({\z})).
  def regexp(anchored = false)
    tree, opt = case_insensitive? ? [downcase, Regexp::IGNORECASE] : [self, 0]
    tree = RegexpTree.seq(STR_BEG, tree, STR_END) if anchored
    source = PrettyPrint.singleline_format('') { |out| tree.pretty_format(out) }
    Regexp.compile(source, opt)
  end

  def to_s
    PrettyPrint.singleline_format('') { |out|
      # x flag is not required because all whitespaces are escaped.
      if case_insensitive?
        out.text '(?i-m:'
        downcase.pretty_format(out)
      else
        out.text '(?-im:'
        pretty_format(out)
      end

      out.text ')'
    }
  end

  # Returns true iff self never matches.
  def empty_set?; false end

  # Returns true iff self only matches empty string.
  def empty_sequence?; false end

  # Returns alternation of ((|self|)) and ((|other|)).
  def |(other); RegexpTree.alt(self, other) end

  # Returns concatination of ((|self|)) and ((|other|)).
  def +(other); RegexpTree.seq(self, other) end

  # Returns ((|n|)) times repetition of ((|self|)).
  def *(n)
    case n
    when Integer; rep(n, n)
    when Range; rep(n.first, n.last - (n.exclude_end? ? 1 : 0))
    else; raise TypeError.new("Integer or Range expected: #{n}")
    end
  end

  # Returns ((|min|)) to ((|max|)) times repetation of ((|self|)).
  def rep(min = 0, max = nil, greedy = true)
    RegexpTree.rep(self, min, max, greedy)
  end
end
