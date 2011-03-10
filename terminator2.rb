#!/usr/bin/env ruby

require 'rubygems'
require 'rest_connection'
require 'time'

terminate_after_hours = 24
protection_word = "save"
debug = 'true'
threshold = Time.now

@servers = Server.find_all.select { |x| x.state != "stopped" }
@servers.each do |svr|
  unless svr.nickname.downcase.include?(protection_word)
    settings = svr.settings
    unless svr.settings['locked'].to_s == "true"
      last_updated_time = Time.parse(settings['updated_at'].to_s)
      life_time = last_updated_time + (terminate_after_hours * 60 * 60)
      warning = life_time - ( 3 * (60 * 60)) #warns 3 hours before termination
      puts "nickname: #{settings['nickname']}
       locked: #{settings['locked']}
       last updated: #{last_updated_time}
       life time allowed: #{life_time}
       warning time: #{warning}\n" unless debug == 'false'
      if (threshold < warning) && (threshold < life_time)
        #warn peep
        puts "Warning owner of => #{svr.nickname}\n"     
      elsif (threshold > life_time)
        puts "Terminating => #{svr.nickname}\n"
        #svr.stop
        #`mail -s "#{svr.nickname} has been destroyed by the Terminator." services@rightscale.com`
      end
    end
  end
end
