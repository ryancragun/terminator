module Terminator
  class SnapshotTerminator < Terminator
    attr_accessor :terminated_snapshots

    def initialize(override={})
      super
      @terminated_snapshots = []
      @opts[:snapshot_hours] ||= 672 
      @opts = @opts.merge!(override) unless override.empty? 
    end

    def generate_message()
      subject="Terminator EBS Snapshot Report"
      body = "Date: #{Time.now.utc}\n"
      body += "Terminator Snapshot lifetime: #{@opts[:snapshot_hours].to_f/24} days\n"
      body += "Total terminated: #{@terminated_snapshots.count}\n\n" 
      body += "The following snapshot(s) have been terminated by the Terminator:\n"
      @terminated_snapshots.each {|v| body += "  #{v.aws_id} : #{v.href}\n"}
      body += "\nTo prevent future destruction please tag the Snapshot with one the following tag(s):\n" 
      @opts[:safe_words].each {|w| body += "  #{@opts[:tag]}:#{w}=true\n"} 
      body += "\nYou can also put a valid keyword somewhere in the Snapshot nickname.  Valid keyword(s) are:\n" 
      body += "  #{@opts[:safe_words].join("\n  ")}\n"
      body += "\nIf you have questions please contact your Terminator admin: #{@opts[:admin_email]}"
      return {:subject => subject, :body => body}
    end
   
    def snap_is_imported?(tags)
      import_tag, ret  = "#{@opts[:tag]}:imported_snap", false
      tags.each { |tag| tag.include?(import_tag) ? ret = tag : false}
      ret
    end

    def terminate()
      @opts[:account_ids].each do |account|
        change_account(account)
        logger(:info,"Terminating Snapshots in account #{account}")
        snapshots = Ec2EbsSnapshot.find_all
        snapshots.each do |snap|
          tags = snap.tags
          next if has_safe_word_in_name?(snap.params['nickname']) ||
                  has_safe_tag?(tags) ||
                  snap_is_imported?(tags)
          lifetime = (Time.parse(snap.params['aws_started_at']) + (@opts[:snapshot_hours] * 60 * 60)) 
          if lifetime < Time.now
            begin
              logger(:info,"Deleting expired snapshot \"#{snap.aws_id}\"") 
              snap.destroy
              @terminated_snapshots << snap
            rescue
              logger(:warn,"Snapshot delete failed, it must be imported..")  
              snap.add_tags(["#{@opts[:tag]}:imported_snap=true"])
            end
          end
        end
      end
      unless @opts[:disable_admin_email] || @terminated_snapshots.empty?
        send_email(generate_message(),@opts[:admin_email]) 
        @opts[:admin_cc_list].each {|a| send_email(generate_message,a)} unless @opts[:admin_cc_list].nil? 
      end
      @terminated_snapshots = []
      true
    end
  end
end
