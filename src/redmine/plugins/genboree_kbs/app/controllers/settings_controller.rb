class SettingsController < ApplicationController
  before_filter :set_up_vars, :only => :plugin

  private

  def set_up_vars
    if(params[:id] == 'genboree_kbs')
      @genboreeKb = GenboreeKb.find(:all)
      $stderr.puts "params: #{params.inspect}"
    end
  end
end
