require 'abnf/ast/element'

class ABNF
  # Variable — a name of a rule that's defined elsewhere in the rulelist.
  class Var < Element
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def useful?(useful_names)
      useful_names.include?(@name)
    end

    def each_var(&block) yield @name end
    def subst_var(&block) yield(@name) || self end

    def recursion(syms, lhs)
      if lhs == self.name
        JustRecursion | SelfRecursion
      elsif syms.include? self.name
        JustRecursion
      else
        NonRecursion
      end
    end

    def remove_just_recursion(n)
      if n == self.name
        EmptySet
      else
        self
      end
    end

    def split_left_recursion(n)
      if n == self.name
        [EmptySet, EmptySeq]
      else
        [self, EmptySet]
      end
    end
    alias split_right_recursion split_left_recursion

    def split_recursion(n)
      if n == self.name
        [EmptySet, EmptySet, EmptySet]
      else
        [EmptySet, self, EmptySet]
      end
    end
  end
end
