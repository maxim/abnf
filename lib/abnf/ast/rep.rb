require 'abnf/ast/element'

class ABNF
  class Rep < Element
    attr_reader :elt, :min, :max, :greedy

    class << self
      alias _new new
      def new(elt, min=0, max=nil, greedy=true)
        return EmptySeq if min == 0 && max == 0
        return elt if min == 1 && max == 1
        return EmptySeq if elt.empty_sequence?

        if elt.empty_set?
          return min == 0 ? EmptySeq : EmptySet
        end

        _new(elt, min, max, greedy)
      end
    end

    def initialize(elt, min=0, max=nil, greedy=true)
      @elt = elt
      @min = min
      @max = max
      @greedy = greedy
    end

    def useful?(useful_names)
      @min == 0 ? true : @elt.useful?(useful_names)
    end

    def each_var(&block) @elt.each_var(&block) end
    def subst_var(&block) Rep.new(@elt.subst_var(&block), min, max, greedy) end
    def regexp_tree; @elt.regexp_tree.rep(min, max, greedy) end

    def recursion(syms, lhs)
      @elt.recursion(syms, lhs) == NonRecursion ? NonRecursion : OtherRecursion
    end

    def remove_just_recursion(n)
      self
    end

    def split_left_recursion(n)
      [self, EmptySet]
    end
    alias split_right_recursion split_left_recursion

    def split_recursion(n)
      [EmptySet, self, EmptySet]
    end
  end
end
