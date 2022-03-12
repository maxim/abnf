require 'abnf/element'

class ABNF
  class Seq < Element
    class << Seq
      alias _new new
    end

    def Seq.new(*elts)
      elts2 = []
      elts.each {|e|
        if e.empty_sequence?
          next
        elsif Seq === e
          elts2.concat e.elts
        elsif e.empty_set?
          return EmptySet
        else
          elts2 << e
        end
      }
      case elts2.length
      when 0; EmptySeq
      when 1; elts2.first
      else; Seq._new(*elts2)
      end
    end

    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts

    def empty_sequence?
      @elts.empty?
    end

    def useful?(useful_names)
      @elts.all? { |e| e.useful?(useful_names) }
    end

    def each_var(&block) @elts.each {|elt| elt.each_var(&block)} end
    def subst_var(&block) Seq.new(*@elts.map {|elt| elt.subst_var(&block)}) end
    def regexp_tree; RegexpTree.seq(*@elts.map {|e| e.regexp_tree}) end

    def recursion(syms, lhs)
      case @elts.length
      when 0
        NonRecursion
      when 1
        @elts.first.recursion(syms, lhs)
      else
        (1...(@elts.length-1)).each {|i|
          return OtherRecursion if @elts[i].recursion(syms, lhs) != NonRecursion
        }

        r_left = @elts.first.recursion(syms, lhs)
        return OtherRecursion if r_left & ~(NonRecursion|JustRecursion|LeftRecursion|SelfRecursion) != 0
        r_left = (r_left & ~JustRecursion) | LeftRecursion if r_left & JustRecursion != 0

        r_right = @elts.last.recursion(syms, lhs)
        return OtherRecursion if r_right & ~(NonRecursion|JustRecursion|RightRecursion|SelfRecursion) != 0
        r_right = (r_right & ~JustRecursion) | RightRecursion if r_right & JustRecursion != 0

        if r_left == NonRecursion
          r_right
        elsif r_right == NonRecursion
          r_left
        else
          OtherRecursion
        end
      end
    end

    def remove_just_recursion(n)
      self
    end

    def split_left_recursion(n)
      case @elts.length
      when 0
        [self, EmptySet]
      when 1
        @elts.first.split_left_recursion(n)
      else
        nonrec, rest = @elts.first.split_left_recursion(n)
        rest1 = Seq.new(*@elts[1..-1])
        nonrec += rest1
        rest += rest1
        [nonrec, rest]
      end
    end

    def split_right_recursion(n)
      case @elts.length
      when 0
        [self, EmptySet]
      when 1
        @elts.first.split_right_recursion(n)
      else
        nonrec, rest = @elts.last.split_right_recursion(n)
        rest1 = Seq.new(*@elts[0...-1])
        nonrec = rest1 + nonrec
        rest = rest1 + rest
        [nonrec, rest]
      end
    end

    def split_recursion(n)
      case @elts.length
      when 0
        [EmptySet, self, EmptySet]
      when 1
        @elts.first.split_recursion(n)
      else
        leftmost_nonrec, leftmost_rest_right = @elts.first.split_left_recursion(n)
        rightmost_nonrec, rightmost_rest_left = @elts.last.split_right_recursion(n)
        rest_middle = Seq.new(*@elts[1...-1])

        if leftmost_rest_right.empty_set?
          [leftmost_nonrec + rest_middle + rightmost_rest_left,
           leftmost_nonrec + rest_middle + rightmost_nonrec,
           EmptySet]
        elsif rightmost_rest_left.empty_set?
          [EmptySet,
           leftmost_nonrec + rest_middle + rightmost_nonrec,
           leftmost_rest_right + rest_middle + rightmost_nonrec]
        else
          raise Exception.new("non left/right recursion") # bug
        end
      end
    end
  end
end
