require 'abnf/alt'
require 'abnf/rep'
require 'abnf/seq'
require 'abnf/term'
require 'abnf/var'

class ABNF
  EmptySet = Alt._new
  EmptySequence = Seq._new
end
