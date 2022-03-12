require 'tsort'
require 'regexp_tree'

require 'abnf/parser'
require 'abnf/elements/alt'
require 'abnf/elements/rep'
require 'abnf/elements/seq'
require 'abnf/elements/term'
require 'abnf/elements/var'

# Convert ABNF to Regexp.
#
# Example:
#
# # IPv6 [RFC2373]
# p %r{\A#{ABNF.regexp <<'End'}\z}o =~ "FEDC:BA98:7654:3210:FEDC:BA98:7654:3210"
#   IPv6address = hexpart [ ":" IPv4address ]
#   IPv4address = 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT
#   hexpart = hexseq | hexseq "::" [ hexseq ] | "::" [ hexseq ]
#   hexseq  = hex4 *( ":" hex4)
#   hex4    = 1*4HEXDIG
# End
#
# Note that this is wrong because it doesn't match "::13.1.68.3".
#
# # URI-reference [RFC2396]
# p %r{\A#{ABNF.regexp <<'End'}\z}o
#       URI-reference = [ absoluteURI | relativeURI ] [ "#" fragment ]
#       ...
#       digit    = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" |
#                  "8" | "9"
# End
#
# Note: Wrong ABNF description produces wrong regexp.
class ABNF
  include TSort

  # Raised when ABNF grammar is too complex to convert to Regexp.
  TooComplex = Class.new(StandardError)
  ABNFError = Class.new(StandardError)
  EmptySet = Alt.new
  EmptySeq = Seq._new
  NonRecursion = 1  # X = a
  JustRecursion = 2 # X = Y
  LeftRecursion = 4 # X = Y a
  RightRecursion = 8  # X = a Y
  SelfRecursion = 16  # Y is X in JustRecursion, LeftRecursion and RightRecursion
  OtherRecursion = 32 # otherwise

  class << self
    def core_rules
      @core_rules ||= begin
        abnf = File.read("#{__dir__}/abnf/rfc5234_core_rules.abnf")
        parse abnf, true
      end
    end

    def parse(desc, dont_merge_core_rules=false)
      grammar = new
      Parser.new(grammar).parse(desc)
      grammar.merge(core_rules) unless dont_merge_core_rules
      grammar
    end

    # Converts ((|abnf_description|)) to a Regexp object corresponding with
    # ((|start_symbol|)). If ((|start_symbol|)) is not specified, first symbol
    # in ((|abnf_description|)) is used.
    def regexp(desc, name=nil)
      regexp_tree(desc, name).regexp
    end

    # Converts ((|abnf_description|)) to a ((<RegexpTree>)) object corresponding
    # with ((|start_symbol|)).
    def regexp_tree(desc, name=nil)
      parse(desc).regexp_tree(name)
    end
  end

  def initialize
    @names = []
    @rules = {}
    @start = nil
  end

  def tsort_each_node(&block)
    @names.each(&block)
  end

  def tsort_each_child(name)
    return unless @rules.include? name
    @rules.fetch(name).each_var { |n| yield n }
  end

  def start_symbol=(name)
    @start = name
  end

  def start_symbol
    return @start if @start
    raise StandardError, 'no symbol defined' if @names.empty?
    @names.first
  end

  def names
    @names.dup
  end

  def merge(g)
    g.each do |name, rhs|
      add(name, rhs)
    end
  end

  def [](name)
    @rules[name]
  end

  def []=(name, rhs)
    @names << name unless @rules.include? name
    @rules[name] = rhs
  end

  def add(name, rhs)
    if @rules.include? name
      @rules[name] |= rhs
    else
      @names << name
      @rules[name] = rhs
    end
  end

  def include?(name)
    @rules.include? name
  end

  def each(&block)
    @names.each do |name|
      yield name, @rules[name]
    end
  end

  def delete_unreachable!(starts)
    rules = {}
    id_map = {}
    stack = []
    starts.each {|name|
      next if id_map.include? name
      each_strongly_connected_component_from(name, id_map, stack) {|syms|
        syms.each {|sym|
          rules[sym] = @rules[sym] if @rules.include? sym
        }
      }
    }
    @rules = rules
    @names.reject! {|name| !@rules.include?(name)}
    self
  end

  def delete_useless!(starts=nil)
    if starts
      starts = [starts] if Symbol === starts
      delete_unreachable!(starts)
    end

    useful_names = {}
    using_names = {}

    @rules.each {|name, rhs|
      useful_names[name] = true if rhs.useful?(useful_names)
      rhs.each_var {|n|
        (using_names[n] ||= {})[name] = true
      }
    }

    queue = useful_names.keys
    until queue.empty?
      n = queue.pop
      next unless using_names[n]
      using_names[n].keys.each {|name|
        if useful_names[name]
          using_names[n].delete name
        elsif @rules[name].useful?(useful_names)
          using_names[n].delete name
          useful_names[name] = true
          queue << name
        end
      }
    end

    rules = {}
    @rules.each {|name, rhs|
      rhs = rhs.subst_var {|n| useful_names[n] ? nil : EmptySet}
      rules[name] = rhs unless rhs.empty_set?
    }

    #xxx: raise if some of start symbol becomes empty set?

    @rules = rules
    @names.reject! {|name| !@rules.include?(name)}
    self
  end

  def regexp(name=start_symbol)
    regexp_tree(name).regexp
  end

  # Convert a recursive rule to non-recursive rule if possible. This conversion
  # is *not* perfect. It may fail even if possible. More work (survey) is
  # needed.
  def regexp_tree(name=nil)
    name ||= start_symbol
    env = {}
    each_strongly_connected_component_from(name) {|ns|
      rules = {}
      ns.each {|n|
        rules[n] = @rules[n]
      }

      resolved_rules = {}
      updated = true
      while updated
        updated = false
        ns.reject! {|n| !rules.include?(n)}

        rs = {}
        ns.reverse_each {|n|
          e = rules[n]
          if !e
            raise ABNFError.new("no rule defined: #{n}")
          end
          rs[n] = e.recursion(ns, n)
          if rs[n] & OtherRecursion != 0
            raise TooComplex.new("too complex to convert to regexp: #{n} (#{ns.join(', ')})")
          end
        }

        ns.reverse_each {|n|
          e = rules[n]
          r = rs[n]
          if r & SelfRecursion == 0
            resolved_rules[n] = e
            rules.delete n
            rules.each {|n2, e2| rules[n2] = e2.subst_var {|n3| n3 == n ? e : nil}}
            updated = true
            break
          end
        }
        next if updated

        # X = Y | a
        # Y = X | b
        # =>
        # Y = Y | a | b
        ns.reverse_each {|n|
          e = rules[n]
          r = rs[n]
          if r & JustRecursion != 0 && r & ~(NonRecursion|JustRecursion) == 0
            e = e.remove_just_recursion(n)
            resolved_rules[n] = e
            rules.delete n
            rules.each {|n2, e2| rules[n2] = e2.subst_var {|n3| n3 == n ? e : nil}}
            updated = true
            break
          end
        }
        next if updated

        # X = X a | b
        # =>
        # X = b a*
        ns.reverse_each {|n|
          e = rules[n]
          r = rs[n]
          if r & LeftRecursion != 0 && r & ~(NonRecursion|JustRecursion|LeftRecursion|SelfRecursion) == 0
            e = e.remove_left_recursion(n)
            resolved_rules[n] = e
            rules.delete n
            rules.each {|n2, e2| rules[n2] = e2.subst_var {|n3| n3 == n ? e : nil}}
            updated = true
            break
          end
        }
        next if updated

        # X = a X | b
        # =>
        # X = a* b
        ns.reverse_each {|n|
          e = rules[n]
          r = rs[n]
          if r & RightRecursion != 0 && r & ~(NonRecursion|JustRecursion|RightRecursion|SelfRecursion) == 0
            e = e.remove_right_recursion(n)
            resolved_rules[n] = e
            rules.delete n
            rules.each {|n2, e2| rules[n2] = e2.subst_var {|n3| n3 == n ? e : nil}}
            updated = true
            break
          end
        }
        next if updated
      end

      if 1 < rules.length
        raise TooComplex.new("too complex to convert to regexp: (#{ns.join(', ')})")
      end

      if rules.length == 1
        n, e = rules.shift
        r = e.recursion(ns, n)
        if r & OtherRecursion != 0
          raise TooComplex.new("too complex to convert to regexp: #{n} (#{ns.join(', ')})")
        end
        if r == NonRecursion
          resolved_rules[n] = e
        else
          # X = a X | b | X c
          # =>
          # X = a* b c*
          left, middle, right = e.split_recursion(n)
          resolved_rules[n] = Seq.new(
            Alt.from_elements(left).rep,
            Alt.from_elements(middle),
            Alt.from_elements(right).rep
          )
        end
      end

      class << resolved_rules
        include TSort
        alias tsort_each_node each_key
        def tsort_each_child(n, &block)
          self[n].each_var {|n2|
            yield n2 if self.include? n2
          }
        end
      end

      resolved_rules.tsort_each {|n|
        env[n] = resolved_rules[n].subst_var {|n2|
          unless env[n2]
            raise Exception.new("unresolved nonterminal: #{n}") # bug
          end
          env[n2]
        }
      }
    }
    env[name].regexp_tree
  end
end
