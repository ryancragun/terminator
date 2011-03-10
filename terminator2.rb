#!/usr/bin/env ruby

require 'rubygems'
require 'rest_connection'
require 'time'

terminate_after_hours = 24
protection_word = "save"

threshold = Time.now - (terminate_after_hours * (60 * 60))
warning = threshold - ( 3 * (60 * 60))

@servers = Server.find_all.select { |x| x.state != "stopped" }
@servers.each do |svr|
  unless svr.nickname.downcase.include?(protection_word)
    settings = svr.settings_current
    unless settings['locked'] == "true"
      last_updated_time = Time.parse(settings['updated_at'].to_s)
      if last_updated_time > warning && last_updated_time < threhold
        #warn peep     
      elsif last_updated_time < threshold
          puts "Terminating => #{svr.nickname}"
          #svr.stop
          `mail -s "#{svr.nickname} has been destroyed by the Terminator." services@rightscale.com`
      end
    end
  end
end
