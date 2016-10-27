def genbkb_hash_delete_null input
  input.each do |key,value|
    if key == "value"
      if value.nil?
        input.delete(key)
      end
    elsif key == "properties"
      genbkb_hash_delete_null(value)
    elsif key == "items"
      (0...value.size).each do |i|
          genbkb_hash_delete_null(value[i])
      end
    else
      genbkb_hash_delete_null(value)
    end
  end
end

def follow_genbkb_hash_delete_null input
  input.each do |key,value|
    if     key == "value"
    elsif  key == "properties"
          follow_genbkb_hash_delete_null(value)
    elsif  key == "items"
      (0...value.size).each do |i|
          follow_genbkb_hash_delete_null(value[i])
      end
    else 
      if value.empty?
       #STDERR.puts "..........................."
       #STDERR.puts key,value
       #STDERR.puts "..........................."
       input.delete(key)
      else 
        follow_genbkb_hash_delete_null(value)
      end
    end
  end
end

def ask_uname_pwd
  #STDERR.puts "username:"
  #username = ask("") { |q| q.echo = true }
  #STDERR.puts "pwd:"
  #password = ask("") { |q| q.echo = "" }
  username="ronakypatel"
  password = "rnaset1@"
  return username,password
end 
