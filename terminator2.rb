#!/usr/bin/env ruby
# Terminator2, rob & ryan

require 'rubygems'
require 'rest_connection'
require 'time'
require 'getoptlong'

# Define usage
def usage
  puts("#{$0} -h <hours> [-w <safe word> -d]")
  puts("    -h: The number of hours to use for threshold")
  puts("    -w: Safe word that prevents a server from being shut down.  Required to be in nickname")
  puts("    -d: Enables debug logging"
  exit
end

# Define Debug info
def display_debug_info(nickname, locked, last_update, life_time, warning)
  puts("Debug info:")
  puts("Server Nickname: #{nickname}")
  puts("Locked status is: #{locked}")
  puts("Last updated at: #{last_update}")
  puts("Will terminate after: #{life_time}")
  puts("Warn at: #{warning}")
end 

#Define default parameters
terminate_after_hours = nil
protection_word = "save"
debug = 'false'
current_time = Time.now

#Define options
opts = GetoptLong.new(
    [ '--hours', '-h', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--safeword', '-w',  GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--debug', '-d',  GetoptLong::OPTIONAL_ARGUMENT ]
)

opts.each do |opt, arg|
  case opt
    when '--hours'
      terminate_after_hours = arg.to_i
    when '--debug'
      debug = 'true'
    when '--safeword'
      protection_word = arg
  end
  arg.inspect
end

# Throw usage warning if hour parameter is missing.
usage unless terminate_after_hours

# Main
@servers = Server.find_all.select { |x| x.state != "stopped" }
@servers.each do |svr|
  unless svr.nickname.downcase.include?(protection_word)
    settings = svr.settings
    unless svr.settings['locked'].to_s == "true"
      last_updated_time = Time.parse(settings['updated_at'].to_s)
      life_time = last_updated_time + (terminate_after_hours * 60 * 60)
      warning = life_time - ( 3 * (60 * 60)) #warns 3 hours before termination
      display_debug_info(settings['nickname'], settings['locked'], last_updated_time, life_time, warning) unless debug == 'false'
      if (current_time > warning) && (current_time < life_time)
        #Eventually I'd like to warn the user who launched the server before we shut it down.
	      #Currently that is not exposed through the API so this isn't possible.
        #puts "Warning owner of => #{svr.nickname}\n"     
      elsif (current_time > life_time)
        puts "Terminating => #{svr.nickname}\n"
        svr.stop
        `echo 'Be sure to lock or put "save" somewhere in the nickname to prevent this from happening again.' | mail -s "#{svr.nickname} has been destroyed by the Terminator." terminator@rightscale.com`
      end
    end
  end
end
