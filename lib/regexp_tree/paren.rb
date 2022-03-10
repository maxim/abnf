require 'regexp_tree/elt'

class RegexpTree
  # (?ixm-ixm:...)
  # (?>...)
  class Paren < Elt
    def initialize(tree, mark='?:')
      @mark = mark
      @tree = tree
    end

    def case_insensitive?
      # xxx: if @mark contains "i"...
      @tree.case_insensitive?
    end

    def multiline_insensitive?
      # xxx: if @mark contains "m"...
      @tree.multiline_insensitive?
    end

    def downcase
      Paren.new(@tree.downcase, @mark)
    end

    def pretty_format(out)
      out.group(1 + @mark.length, "(#@mark", ')') { @tree.pretty_format(out) }
    end
  end
end
