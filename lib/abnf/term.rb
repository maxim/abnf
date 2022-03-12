require 'abnf/element'
require 'natset'

class ABNF
  class Term < Element
    attr_reader :natset

    def initialize(natset)
      @natset = natset.empty? ? EmptySet : natset
    end

    def empty_set?
      @natset.empty?
    end

    def useful?(_)
      true
    end

    def each_var(&block) end
    def subst_var(&block) self end
    def regexp_tree; RegexpTree.char_class(@natset) end

    def recursion(syms, lhs)
      NonRecursion
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
