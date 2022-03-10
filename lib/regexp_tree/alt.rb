class RegexpTree
  class Alt < RegexpTree
    PRECEDENCE = 2
    attr_reader :trees

    def initialize(trees)
      @trees = trees
    end

    def empty_set?; @trees.empty? end
    def case_insensitive?; @trees.all?(&:case_insensitive?) end
    def multiline_insensitive?; @trees.all?(&:multiline_insensitive?) end
    def downcase; self.class.new(@trees.map(&:downcase)) end

    def pretty_format(out)
      return out.text('(?!)') if @trees.empty?

      out.group do
        @trees.each_with_index do |tree, i|
          if i.nonzero?
            out.text '|'
            out.breakable ''
          end

          tree.parenthesize(self.class).pretty_format(out)
        end
      end
    end
  end
end
