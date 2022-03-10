require 'prettyprint'
require 'natset'

require 'regexp_tree/alt'
require 'regexp_tree/char_class'
require 'regexp_tree/paren'
require 'regexp_tree/alt'
require 'regexp_tree/rep'
require 'regexp_tree/seq'
require 'regexp_tree/special'

=begin
= RegexpTree

RegexpTree represents regular expression.
It can be converted to Regexp.

== class methods
--- RegexpTree.str(string)
    returns an instance of RegexpTree which only matches ((|string|))
--- RegexpTree.alt(*regexp_trees)
    returns an instance of RegexpTree which is alternation of ((|regexp_trees|)).
--- RegexpTree.seq(*regexp_trees)
    returns an instance of RegexpTree which is concatination of ((|regexp_trees|)).
--- RegexpTree.rep(regexp_tree, min=0, max=nil, greedy=true)
    returns an instance of RegexpTree which is reptation of ((|regexp_tree|)).
--- RegexpTree.charclass(natset)
    returns an instance of RegexpTree which matches characters in ((|natset|)).
#--- RegexpTree.linebeg
#--- RegexpTree.lineend
#--- RegexpTree.strbeg
#--- RegexpTree.strend
#--- RegexpTree.strlineend
#--- RegexpTree.word_boundary
#--- RegexpTree.non_word_boundary
#--- RegexpTree.previous_match
#--- RegexpTree.backref(n)

== methods
--- regexp(anchored=false)
    convert to Regexp.

    If ((|anchored|)) is true, the Regexp is anchored by (({\A})) and (({\z})).
--- to_s
    convert to String.
--- empty_set?
    returns true iff self never matches. 
--- empty_sequence?
    returns true iff self only matches empty string.
--- self | other
    returns alternation of ((|self|)) and ((|other|)).
--- self + other
    returns concatination of ((|self|)) and ((|other|)).
--- self * n
    returns ((|n|)) times repetation of ((|self|)).
--- rep(min=0, max=nil, greedy=true)
    returns ((|min|)) to ((|max|)) times repetation of ((|self|)).
#--- closure(greedy=true)
#--- positive_closure(greedy=true)
#--- optional(greedy=true)
#--- ntimes(min, max=min, greedy=true)
#--- nongreedy_rep(min=0, max=nil)
#--- nongreedy_closure
#--- nongreedy_positive_closure
#--- nongreedy_optional
#--- nongreedy_ntimes(min, max=min)
=end
class RegexpTree
  PRECEDENCE = 1

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

  def empty_set?
    false
  end

  def empty_sequence?
    false
  end

  def |(other)
    RegexpTree.alt(self, other)
  end
  def RegexpTree.alt(*rs)
    rs2 = []
    rs.each {|r|
      if r.empty_set?
        next
      elsif Alt === r
        rs2.concat r.rs
      elsif CharClass === r
        if CharClass === rs2.last
          rs2[-1] = CharClass.new(rs2.last.natset + r.natset)
        else
          rs2 << r
        end
      else
        rs2 << r
      end
    }
    case rs2.length
    when 0; EmptySet
    when 1; rs2.first
    else; Alt.new(rs2)
    end
  end


  EmptySet = Alt.new([])

  def +(other)
    RegexpTree.seq(self, other)
  end
  def RegexpTree.seq(*rs)
    rs2 = []
    rs.each {|r|
      if r.empty_sequence?
        next
      elsif Seq === r
        rs2.concat r.rs
      elsif r.empty_set?
        return EmptySet
      else
        rs2 << r
      end
    }
    case rs2.length
    when 0; EmptySequence
    when 1; rs2.first
    else; Seq.new(rs2)
    end
  end

  EmptySequence = Seq.new([])

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
  def rep(m=0, n=nil, greedy=true) RegexpTree.rep(self, m, n, greedy) end

  def RegexpTree.rep(r, m=0, n=nil, greedy=true)
    return EmptySequence if m == 0 && n == 0
    return r if m == 1 && n == 1
    return EmptySequence if r.empty_sequence?
    if r.empty_set?
      return m == 0 ? EmptySequence : EmptySet
    end
    Rep.new(r, m, n, greedy)
  end

  def RegexpTree.charclass(natset)
    if natset.empty?
      EmptySet
    else
      CharClass.new(natset)
    end
  end

  def RegexpTree.linebeg() Special.new('^') end
  def RegexpTree.lineend() Special.new('$') end
  def RegexpTree.strbeg() Special.new('\A') end
  def RegexpTree.strend() Special.new('\z') end
  def RegexpTree.strlineend() Special.new('\Z') end
  def RegexpTree.word_boundary() Special.new('\b') end
  def RegexpTree.non_word_boundary() Special.new('\B') end
  def RegexpTree.previous_match() Special.new('\G') end
  def RegexpTree.backref(n) Special.new("\\#{n}") end

  def group() Paren.new(self, '') end
  def paren() Paren.new(self) end
  def lookahead() Paren.new(self, '?=') end
  def negative_lookahead() Paren.new(self, '?!') end

  # def RegexpTree.comment(str) ... end # (?#...)

  def RegexpTree.str(str)
    ccs = []
    str.each_byte {|ch|
      ccs << CharClass.new(Natset[ch])
    }
    seq(*ccs)
  end
end
