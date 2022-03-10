require 'regexp_tree/elt'

class RegexpTree
  class Special < Elt
    def initialize(str)
      @str = str
    end

    def case_insensitive?
      true
    end

    def multiline_insensitive?
      true
    end

    def downcase
      self
    end

    def pretty_format(out)
      out.text @str
    end
  end
end
