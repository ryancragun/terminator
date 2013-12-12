module Terminator
  class ServerArrayTerminator < Terminator
    def initialize(override={})
      super
      @opts[:array_threshold] = '50%' unless @opts[:array_threshold]
      @opts[:array_hours] = 24 unless @opts[:array_hours]
      @opts = @opts.merge!(override) unless override.empty?
      @terminated_arrays, @flagged_instances = [], []
    end

    def generate_message()
      subject="Terminator ServerArray Report"
      body = "Date: #{Time.now.utc}\n"
      body += "Terminator ServerArray lifetime: #{@opts[:array_hours].to_f/24} days\n"
      body += "Total terminated: #{@terminated_arrays.count}\n\n" 
      body += "The following ServerArrays(s) have been terminated by the Terminator:\n"
      @terminated_arrays.each {|a| body += "  #{a.nickname} : #{a.href}\n"}
      body += "\nTo prevent future destruction please tag the ServerArray with one the following tag(s):\n" 
      @opts[:safe_words].each {|w| body += "  #{@opts[:tag]}:#{w}=true\n"} 
      body += "\nYou can also put a valid keyword somewhere in the ServerArray nickname.  Valid keyword(s) are:\n" 
      body += "  #{@opts[:safe_words].join("\n  ")}\n"
      body += "\nIf you have questions please contact your Terminator admin: #{@opts[:admin_email]}"
      return {:subject => subject, :body => body}
    end
  
    def percentage_to_f(string) # 50% => .50
      return string.gsub(/%/,'').to_f * 0.01 if string.match(/\d+%/)
      logger(:error,"Invalid ServerArray Threshold parameter")
      false
    end 
        
    def terminate()
      @opts[:account_ids].each do |account|
        change_account(account)
        logger(:info,"Terminating ServerArrays in account #{account}")
        arrays = Ec2ServerArray.find_all.select { |a| a.active_instances_count != 0 }
        arrays.each do |ary|
          tags = ary.tags
          next if has_safe_word_in_name?(ary.nickname) ||
                  has_safe_tag?(tags)
          ary.instances.each do |inst|
            inst_tags = Tag.search_by_href(inst['href']).map! {|tag| tag['name']}
            if has_safe_tag?(inst_tags)
              logger :info, "Instance has safe tag, skipping..."
            elsif has_terminator_tag?(inst_tags)
              lifetime = (get_discovery_time(inst_tags) + (@opts[:array_hours] * 60 * 60)) 
              if lifetime < Time.now
                logger(:info,"Flagging expired instance in ServerArray: \"#{ary.nickname}\"")
                @flagged_instances << inst
              end
            else
              logger(:info,"Tagging newly discovered instance in ServerArray \"#{ary.nickname}\"")
              Tag.set(inst['href'],["#{@opts[:tag]}:discovery_time=#{Time.now}"])
            end
          end
          if (@flagged_instances.count.to_f >= (ary.active_instances_count.to_f * percentage_to_f(@opts[:array_threshold])))
            logger(:info,"Terminating ServerArray: #{ary.nickname}\n")
            ary.active = false
            ary.save
            ary.terminate_all
            @terminated_arrays << ary
          end
          @flagged_instances = []
        end
      end
      unless @opts[:disable_admin_email] || @terminated_arrays.empty?
        send_email(generate_message(),@opts[:admin_email]) 
        @opts[:admin_cc_list].each {|a| send_email(generate_admin_message,a)} unless @opts[:admin_cc_list].nil?
      end
      @terminated_servers = []
      true
    end
  end
end
