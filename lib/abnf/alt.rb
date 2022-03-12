require 'abnf/element'

class ABNF
  class Alt < Element
    attr_reader :elts

    class << self
      def from_elements(*elts)
        result = elts.each_with_object([]) { |e, result|
          next if e.empty_set?

          if Alt === e
            result.concat e.elts
          elsif Term === e && Term === result.last
            result[-1] = Term.new(result.last.natset + e.natset)
          else
            result << e
          end
        }

        case result.size
        when 0; EmptySet
        when 1; result.first
        else; new(*result)
        end
      end

      alias [] from_elements
    end

    def initialize(*elts)
      @elts = elts
    end

    def empty_set?
      @elts.empty?
    end

    def useful?(useful_names)
      @elts.any? { |e| e.useful?(useful_names) }
    end

    def each_var(&block) @elts.each {|elt| elt.each_var(&block)} end
    def subst_var(&block)
      self.class[*@elts.map {|elt| elt.subst_var(&block)}]
    end

    def regexp_tree; RegexpTree.alt(*@elts.map {|e| e.regexp_tree}) end

    def recursion(syms, lhs)
      @elts.inject(0) {|r, e| r | e.recursion(syms, lhs)}
    end

    def remove_just_recursion(n)
      Alt[*@elts.map {|e| e.remove_just_recursion(n)}]
    end

    def split_left_recursion(n)
      nonrec = EmptySet
      rest = EmptySet
      @elts.each {|e|
        nonrec1, rest1 = e.split_left_recursion(n)
        nonrec |= nonrec1
        rest |= rest1
      }
      [nonrec, rest]
    end

    def split_right_recursion(n)
      nonrec = EmptySet
      rest = EmptySet
      @elts.each {|e|
        nonrec1, rest1 = e.split_right_recursion(n)
        nonrec |= nonrec1
        rest |= rest1
      }
      [nonrec, rest]
    end

    def split_recursion(n)
      rest_left = EmptySet
      nonrec = EmptySet
      rest_right = EmptySet
      @elts.each {|e|
        rest_left1, nonrec1, rest_right1 = e.split_recursion(n)
        rest_left |= rest_left1
        nonrec |= nonrec1
        rest_right |= rest_right1
      }
      [rest_left, nonrec, rest_right]
    end
  end
end
