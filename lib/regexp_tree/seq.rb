class RegexpTree
  class Seq < RegexpTree
    PRECEDENCE = 3
    attr_reader :trees

    def initialize(trees)
      @trees = trees
    end

    def empty_sequence?; @trees.empty? end
    def case_insensitive?; @trees.all?(&:case_insensitive?) end
    def multiline_insensitive?; @trees.all?(&:multiline_insensitive?) end
    def downcase; self.class.new(@trees.map(&:downcase)) end

    def pretty_format(out)
      out.group do
        @trees.each_with_index do |tree, i|
          out.group { out.breakable '' } if i.nonzero?
          tree.parenthesize(self.class).pretty_format(out)
        end
      end
    end
  end
end
