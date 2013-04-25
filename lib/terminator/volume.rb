module Terminator
  class VolumeTerminator < Terminator
    attr_accessor :terminated_volumes

    def initialize(override={})
      super
      @terminated_volumes = []
      @opts[:volume_hours] ||= 168 
      @opts = @opts.merge!(override) unless override.empty? 
    end

    def generate_message()
      subject="Terminator EBS Volume Report"
      body = "Date: #{Time.now.utc}\n"
      body += "Terminator Volume lifetime: #{@opts[:volume_hours].to_f/24} days\n"
      body += "Total terminated: #{@terminated_volumes.count}\n\n" 
      body += "The following volume(s) have been terminated by the Terminator:\n"
      @terminated_volumes.each {|v| body += "  #{v.aws_id} : #{v.href}\n"}
      body += "\nTo prevent future destruction please tag the Volume with one the following tag(s):\n" 
      @opts[:safe_words].each {|w| body += "  #{@opts[:tag]}:#{w}=true\n"} 
      body += "\nYou can also put a valid keyword somewhere in the Volume nickname.  Valid keyword(s) are:\n" 
      body += "  #{@opts[:safe_words].join("\n  ")}\n"
      body += "\nIf you have questions please contact your Terminator admin: #{@opts[:admin_email]}"
      return {:subject => subject, :body => body}
    end

    def terminate()
      @opts[:account_ids].each do |account|
        change_account(account)
        logger(:info,"Terminating Volumes in account #{account}")
        volumes = Ec2EbsVolume.find_all.select { |v| v.aws_status == "available"}
        volumes.each do |vol|
          tags = vol.tags
          next if has_safe_word_in_name?(vol.nickname) ||
                  has_safe_tag?(tags)
          if has_terminator_tag?(tags)
            lifetime = (get_discovery_time(tags) + (@opts[:volume_hours] * 60 * 60)) 
            if lifetime < Time.now
              logger(:info,"Deleting expired volume \"#{vol.aws_id}\"")
              @terminated_volumes << vol
              vol.destroy
            end
          else
            vol.add_tags(["#{@opts[:tag]}:discovery_time=#{Time.now}"])
            logger(:info,"Tagging newly discovered volume \"#{vol.nickname}\"")
          end
        end
      end
      unless @opts[:disable_admin_email] || @terminated_volumes.empty?
        send_email(generate_message(),@opts[:admin_email])
        @opts[:admin_cc_list].each {|a| send_email(generate_message(),a)} unless @opts[:admin_cc_list].nil?
      end
      @terminated_volumes = []
      true
    end
  end
end
