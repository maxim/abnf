require 'tsort'
require 'abnf/grammar'

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

  ABNFError = Class.new(StandardError)

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
      self.add(name, rhs)
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
end
