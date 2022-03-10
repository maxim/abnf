require 'regexp_tree/elt'

class RegexpTree
  # (?ixm-ixm:...)
  # (?>...)
  class Paren < Elt
    def initialize(r, mark='?:')
      @mark = mark
      @r = r
    end

    def case_insensitive?
      # xxx: if @mark contains "i"...
      @r.case_insensitive?
    end

    def multiline_insensitive?
      # xxx: if @mark contains "m"...
      @r.multiline_insensitive?
    end

    def downcase
      Paren.new(@r.downcase, @mark)
    end

    def pretty_format(out)
      out.group(1 + @mark.length, "(#@mark", ')') { @r.pretty_format(out) }
    end
  end
end
