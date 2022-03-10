class RegexpTree
  class Seq < RegexpTree
    PRECEDENCE = 3

    def initialize(rs)
      @rs = rs
    end
    attr_reader :rs

    def empty_sequence?
      @rs.empty?
    end

    def case_insensitive?
      @rs.all? {|r| r.case_insensitive?}
    end

    def multiline_insensitive?
      @rs.all? {|r| r.multiline_insensitive?}
    end

    def downcase
      Seq.new(@rs.map {|r| r.downcase})
    end

    def pretty_format(out)
      out.group {
        @rs.each_with_index {|r, i|
          unless i == 0
            out.group {out.breakable ''}
          end
          r.parenthesize(Seq).pretty_format(out)
        }
      }
    end
  end
end
