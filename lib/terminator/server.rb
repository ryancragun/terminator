module Terminator
  class ServerTerminator < Terminator
    def initialize(override={})
      super
      @terminated_servers = []
      @opts[:server_hours]=24 unless @opts[:server_hours]
      @opts = @opts.merge!(override) unless override.empty? 
    end

    def generate_user_message(resource_name,recipient_email)
      logger(:debug,"Generating email message for Server \"#{resource_name}\" to be sent to #{recipient_email}") if @opts[:debug]
      subject="The \"#{resource_name}\" Server has been Terminated"
      body = "Date: #{Time.now.utc}\n\n"
      body += "The \"#{resource_name}\" Server has been terminated by the Terminator. To prevent future termination you have a few options:\n"
      body += "* Lock the Server\n"
      body += "* Put valid keywords somewhere in the Server nickname.  Valid keyword(s) are: #{@opts[:safe_words].join(", ")}\n"
      body += "* Tag the Server with one the following tag(s):\n" 
      @opts[:safe_words].each {|w| body += "  #{@opts[:tag]}:#{w}=true\n"} 
      body += "If you have questions please contact your Terminator admin: #{@opts[:admin_email]}"
      return {:subject => subject, :body => body} 
    end
    
    def generate_admin_message()
      subject="Terminator Server Report"
      body = "Date: #{Time.now.utc}\n"
      body += "Terminator Server lifetime: #{@opts[:server_hours].to_f/24} days\n"
      body += "Total terminated: #{@terminated_servers.count}\n\n" 
      body += "The following Servers(s) have been terminated by the Terminator:\n"
      @terminated_servers.each {|s| body += "  #{s.nickname} : #{s.href}\n"}
      body += "\nTo prevent future destruction please tag the Server with one the following tag(s):\n" 
      @opts[:safe_words].each {|w| body += "  #{@opts[:tag]}:#{w}=true\n"} 
      body += "\nYou can also put a valid keyword somewhere in the Server nickname.  Valid keyword(s) are:\n" 
      body += "  #{@opts[:safe_words].join("\n  ")}\n"
      body += "\nIf you have questions please contact your Terminator admin: #{@opts[:admin_email]}"
      return {:subject => subject, :body => body}
    end
    
    def terminate()
      @opts[:account_ids].each do |account| 
        change_account(account)
        logger(:info,"Terminating Servers in account #{account}")
        running_servers = Server.find_all.select {|x| x.state == "operational" || x.state == "stranded" || x.state == "booting"}
        running_servers.each do |svr|
          tags = svr.current_tags
          next if has_safe_word_in_name?(svr.nickname) ||
                  has_safe_tag?(tags)
          settings = svr.settings
          next if settings['locked'].to_s == "true"
          if has_terminator_tag?(tags)
            lifetime = (get_discovery_time(tags) + (@opts[:server_hours] * 60 * 60)) 
            if lifetime < Time.now
              launched_by = ( settings['launched-by'] && !@opts[:disable_user_email] && valid_email?(settings['launched-by']) ) ? settings['launched-by'] : nil
              logger(:info,"Terminating Server: \"#{svr.nickname}\"")
              @terminated_servers << svr
              svr.stop
              send_email(generate_user_message(svr.nickname,launched_by),launched_by) if launched_by
            end
          else
            logger(:info,"Tagging newly discovered Server \"#{svr.nickname}\"")
            svr.add_tags(["#{@opts[:tag]}:discovery_time=#{Time.now}"])
          end
        end
        unless @opts[:disable_admin_email] || @terminated_servers.empty?
          send_email(generate_admin_message(),@opts[:admin_email]) 
          @opts[:admin_cc_list].each {|a| send_email(generate_admin_message,a)} unless @opts[:admin_cc_list].nil?
        end
        @terminated_servers = []
        clear_stopped_servers()
      end
      true
    end

    def clear_stopped_servers()
      stopped_servers = Server.find_all.select {|s| s.state == "stopped"}
      stopped_servers.select!{|s| ! s.params['current_instance_href'].nil?}
      logger(:info,"Found #{stopped_servers.count} stopped Server(s), checking for Terminator tags...")
      stopped_servers.each do |svr|
        if has_terminator_tag?(svr.current_tags)
          logger(:info,"Clearing tag on stopped Server: #{svr.nickname}")
          svr.remove_tags([has_terminator_tag?(svr.current_tags)])
        end
      end
     stopped_servers.count
    end
  end
end
