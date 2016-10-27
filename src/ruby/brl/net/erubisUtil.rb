
module ErubisHelp
  @_buf = nil
  def print(*args)
    args.each { |arg|
      @_buf << arg.to_s
    }
  end

  def puts(*args)
    args.each { |arg|
      @_buf << arg.to_s
    }
    @_buf << "\n"
  end
end
