#env /usr/bin/ruby

class Identifier
 # default constructor
 attr_accessor  :use, :label, :system, :value
 def initialize(use="official",label=nil,system=nil,value=nil)
    @use,@label,@system,@value=
      use,label,system,value
 end
 def to_hash
      temp_hash = {"identifier" => 
                    { 
                   "value" => "ID"+("%012d" % rand(1000000000000)).to_s,
                   "properties" => {
                     "use" =>    { "value" => self.use},
                     "label" =>  { "value" => self.label}, 
                     "system" => { "value" => self.system}, 
                     "value" =>  { "value" => self.value}
                    }
                   }
                  }
      return temp_hash
 end
end

