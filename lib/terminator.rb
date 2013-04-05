#!/usr/bin/env ruby

# Terminator2, Ryan Cragun
# Inspired by the original Terminator by Rob Carr

require 'rubygems'
require 'rest_connection'
require 'time'
require 'mail'
require 'resolv'
require 'logger'
require 'json'
require 'yaml'
require 'highline/import'

module Terminator
  class Terminator
    def initialize(override={})
      @@logger = nil
      @opts = load_options()
      @opts.merge!(override) unless override.empty?
      validate_options(@opts)
      verify_email_server() unless @opts[:disable_user_email] == true && opts[:disable_admin_email] == true
    end
    
    def opts()
      @opts
    end

    def opts=(opt)
      @opts = opt if validate_options(opt, quiet=true)
    end

    def load_options()
      @config_yaml = File.join(File.expand_path("~"), ".rs_terminator", "rs_terminator.yaml")
      @etc_config = File.join("#{File::SEPARATOR}etc", "rs_terminator", "rs_terminator.yaml")
      if File.exists?(@config_yaml)
        return YAML::load(IO.read(@config_yaml))
      elsif File.exists?(@etc_config)
        return YAML::load(IO.read(@etc_config))
      else
       defaults = {:safe_words=>["save"], :user_email=>true, :disable_user_email=>false, :tag=>"terminator"} 
       con = RestConnection::Connection.new.settings
       defaults[:terminator_login], defaults[:admin_email] = con[:user], con[:user]
       defaults[:account_ids] = [con[:api_url].split('/').last.to_i] if con[:api_url]
       return defaults
      end
    end

    def validate_options(params, quiet=false) 
      required_params = [:account_ids, :admin_email]
      valid_params    = [:server_hours, :volume_hours, :snapshot_hours, :tag, :safe_words, 
                         :whitelist, :blacklist, :user_email, :admin_email, :disable_user_email, 
                         :account_ids, :terminator_login, :terminator_password, :array_hours,
                         :array_threshold, :disable_admin_email, :mail_server, :mail_server_location]    
      valid = params.keys.all? {|p| valid_params.include? p}
      required = required_params.all? {|p| params.key? p}
      boiler_plate = "Please pass an option hash or configure rs_terminator.yaml in #{@config_yaml} or #{@etc_config}.\n"
      boiler_plate += "See terminator/config/rs_terminator.yaml.example for example config."
      if valid && required
        logger("info","INPUTS VALIDATED") unless quiet
        params.each {|k,v| logger("info","#{k.to_s} => #{v.to_s}")} unless quiet
      elsif valid
        message = "You haven't passed the required :account_ids and/or :admin_email parameters\n" + boiler_plate
        logger("fatal", message)
        false
      elsif required
        message = "You've passed invalid parameters" + boiler_plate
        logger("fatal", message)
        false
      else
        message = "You haven't passed the required parameters or setup a configuration file\n" + boiler_plate
        logger("fatal", message)
      false
      end 
    end  
    
    def logger(level, message)
      init_message = "Initializing Logging using "
      if @@logger.nil?
        if ENV['TERMINATOR_LOG']
          @@logger = Logger.new(ENV['TERMINATOR_LOG'])
          init_message += ENV['TERMINATOR_LOG']
        else
          @@logger = Logger.new(STDOUT)
          init_message += "STDOUT"
        end
        @@logger.info(init_message)
      end
      
      case level
      when "fatal"
        @@logger.fatal("[Terminator] " + message)
      when "debug"
        @@logger.debug("[Terminator] " + message)
      when "info"
        @@logger.info("[Terminator] " + message)
      when "warn"
      @@logger.warn("[Terminator] " + message)
      when "error"
      @@logger.error("[Terminator] " + message)
      end 
    end
  
    # Validate email syntax and resolvability of domain
    def valid_email?(email)
      logger("debug","Validating email: #{email}") if @opts[:debug]
      domain = email.match(/\@(.+)/)[1]
      Resolv::DNS.open do |dns|
        @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
      end    
      valid = @mx.size > 0 ? true : false
      unless email =~ /^[a-zA-Z][\w\.-]*[a-zA-Z2-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/
        loggger("error","#{email} does not appear to be a valid email address")
        return false
      else
        logger("error","Unable to resolve #{domain} domain") unless valid
        return false unless valid
      end
      true
    end
  
    def change_account(account_id)
      logger("info","Changing account settings to account id to #{account_id}")
      Server.connection.settings[:api_url] = "https://my.rightscale.com/api/acct/#{opts[:account_id]}"
      Server.connection.refresh_cookie
    end

    def send_user_email(resource_name,recipient_email)
      if @opts[:disable_user_email]
        logger("debug","Sending email has been disabled")
        return true 
      end
      return false unless valid_email?(recipient_email)
      
      message = generate_message(resource_name,recipient_email) 
      logger("info","Sending email to #{recipient_email}")
      mail = Mail.new
      mail.from =  @opts[:terminator_login]
      mail.to = recipient_email
      mail.subject = message[:subject]
      mail.body = message[:body]
      if @opts[:mail_server] == :exim
        mail.delivery_method :exim, :location => @opts[:mail_server_location]
      else
        mail.delivery_method :sendmail
      end
      mail.deliver
    end

    def send_admin_email()
    end

    def verify_email_server()
      if system('which exim')
        @opts[:mail_server] = :exim
        @opts[:mail_server_location] = system('which exim')
      elsif system('which sendmail')
        @opts[:mail_server] = :sendmail
      else
        logger("error","No email delivery manager can be found, disabling email")
        @opts[:disable_admin_email], @opts[:disable_admin_email] = true, true
      end
    end
  end 

  class Server < Terminator
    def initialize(override={})
      super
      @opts[:server_hours]=24 unless @opts[:server_hours]
      @opts = @opts.merge!(override) unless override.empty? 
    end

    def generate_message(resource_name,recipient_email)
      logger("debug","Generating email message for Server \"#{resource_name}\" to be sent to #{recipient_email}") if @opts[:debug]
      subject="The \"#{resource_name}\" Server has been Terminated"
      body = "Date: #{Time.now.utc}\n\n"
      body += "The \"#{resource_name}\" Server has been terminated by the Terminator. To prevent future termination you have a few options:\n"
      body += "* Lock the Server\n"
      body += "* Put valid keywords somewhere in the Server nickname.  Valid keyword(s) are: #{@opts[:safe_words].join(", ")}\n"
      body += "* Tag the Server with the following tag(s):\n" 
      @opts[:safe_words].each {|w| body += "  #{@opts[:tag]}:#{w}=true\n"} 
      body += "If you have questions please contact your Terminator admin: #{@opts[:admin_email]}"
      return {:subject => subject, :body => body} 
    end
  end

  class Volume < Terminator
    def initialize(override={})
      super
      @opts[:volume_hours] = 168 unless @opts[:volume_hours]
      @opts = @opts.merge!(override) unless override.empty? 
    end

  end
  
  class Snapshot < Terminator
    def initialize(override={})
      super
      @opts[:snapshot_hours] = 672 unless @opts[:snapshot_hours]
      @opts = @opts.merge!(override) unless override.empty? 
    end
  end

  class ServerArray < Terminator
    def initialize(override={})
      super
      @opts[:array_threshold] = '50%' unless @opts[:array_threshold]
      @opts[:array_hours] = 168 unless @opts[:array_hours]
      @opts = @opts.merge!(override) unless override.empty? 
    end

    def generate_message(resource_name,recipient_email)
      logger("debug","Generating email message for ServerArray \"#{resource_name}\" to be sent to #{recipient_email}") if @opts[:debug]
      subject="The \"#{resource_name}\" ServerArray has been Terminated"
      body = "Date: #{Time.now.utc}\n\n"
      body += "The \"#{resource_name}\" ServerArray has been disabled and all instances were terminated because at least"
      body += "#{@opts[:array_threshold]} of the instances were at least #{@opts[:hours]} hours old. To prevent future termination you have a few options:\n"
      body += "* Lock the ServerArray\n"
      body += "* Put valid keywords somewhere in the ServerArray nickname.  Valid keyword(s) are: #{@opts[:safe_words].join(", ")}\n"
      body += "* Tag the ServerArray with the following tag(s):\n" 
      @opts[:safe_words].each {|w| body += "  #{@opts[:tag]}:#{w}=true\n"} 
      body += "If you have questions please contact your Terminator admin: #{@opts[:admin_email]}"
      return {:subject => subject, :body => body} 
    end
  end
end

=begin
# Terminate Snapshots
#
#
#

# Terminate Volumes
def terminate_ebs_volumes
  save_tag = "#{@opts[:tag]}:#{@opts[:safe_word]}"
  terminator_tag = "#{@opts[:tag]}:discovery_time"
  @volumes = Ec2EbsVolume.find_all.select { |v| v.aws_status == "available"}
  @volumes.each do |vol|
    next if vol.nickname.include?(@opts[:safe_word])
    vol.tags.each do |tag|
      @save = tag.include?(save_tag) ? true : false
      @matched_tag = tag.include?(terminator_tag) ? tag : false
      break if @matched_tag or @save
    end
    next if @save
    if @matched_tag
      life_time = (Time.parse(@matched_tag.split("=")[1]) + (@opts[:hours].to_i * 60 * 60)) 
      vol.destroy unless lifetime > Time.now
    else
      vol.add_tags(["#{termianator_tag}=#{Time.now}"])
    end
  end
end

# Terminate Servers
def terminate_servers
  @servers = Server.find_all #.select { |x| x.state != "booting"}
    @servers.each do |svr|
      next if ( svr.nickname.downcase.include?(@opts[:safe_word]) || svr.href.split("/").last.to_i < @opts[:min_id].to_i )
      settings = svr.settings
      next if ( settings['locked'].to_s == "true" || (start_time.year != Time.parse(settings['updated_at'].to_s).year) )
      current_href = svr.current_instance_href
      launched_by = ( settings['launched-by'] && @opts[:user_email] && valid_email?(settings['launched-by']) ) ? settings['launched-by'] : nil
      matched_tag = false
      tag_timestamp = nil

      if svr.state.to_s == "stopped"
        next_tags = Tag.search_by_href(svr.href)
        next_tags.each do |tag|
          if tag['name'].include?("#{@opts[:tag]}:discovery_time") && svr.state.to_s == "stopped"
            Tag.unset(svr.href,[tag['name'].to_s])
            log.debug("Deleting tag: \"#{tag['name'].to_s}\" on stopped server")
          end
        end
      else
        current_tags = Tag.search_by_href(current_href)
        current_tags.each do |tag|
          if svr.state.to_s == "operational" && tag['name'].to_s.include?("#{@opts[:tag]}:discovery_time")
            tag_timestamp = Time.parse(tag['name'].split("=")[1])
            matched_tag = true
            log.debug("Found matching tag: \"#{tag['name'].to_s} on #{svr.nickname.to_s}")
            break
          end
        end
      end 
          
      unless matched_tag || svr.state.to_s == "stopped"
        tag_contents = ["#{@opts[:tag]}:discovery_time=#{current_time.to_s}"]
        log.debug("No tag found for: \"#{svr.nickname.to_s}\", setting tag now...")
        Tag.set(current_href, tag_contents)
      end

      if matched_tag
        life_time = tag_timestamp + (@opts[:hours].to_i * 60 * 60) 
        current_time = Time.now
        if (current_time > life_time)
          log.info("Tag found on #{svr.nickname} is older than the allowable time..")
          log.info("Terminating => #{svr.nickname}..\n")
          svr.stop
          send_email(:resource_type => "server", :resource_name => svr.nickname, :launched_by => launched_by)
        else
          log.debug("Tag found is within allowable range, skipping server..")
        end
      end
    end
end

def terminate_ec2_arrays 
  @arrays = Ec2ServerArray.find_all.select { |a| a.active_instances_count != 0 }
  @arrays.each do |ary|
    next if ary.nickname.downcase.include?(@opts[:safe_word]) || ary.cloud_id != nil # We don't want to operate on non-ec2 clouds with API 1.0
    @flagged_instances = 0
    instances = ary.instances
    instances.each do |inst|
      #discover instance tags
      matched_tag = nil
      local_tags = Tag.search_by_href(inst['href'])
      #check for a match
      local_tags.each do |tag|
        if tag['name'].include?("#{@opts[:tag]}:discovery_time")
          matched_tag = tag['name'].to_s
          log.debug("Found matching tag #{matched_tag} on #{inst['nickname']}")
        end
      end
      #set terminator tag if no match exists
      if matched_tag == nil
        tag_contents = ["#{@opts[:tag]}:discovery_time=#{current_time.to_s}"]
        Tag.set(inst['href'], tag_contents)
        log.debug("No tag found for instance #{inst['nickname']}, setting tag now...")
      end
      #compare timestammps for a match and flag the server if it's too old
      if matched_tag != nil
        tag_timestamp = Time.parse(matched_tag.split("=").last)
        life_time = tag_timestamp + (@opts[:hours].to_i * 60 * 60) 
        if (current_time > life_time)
          @flagged_instances += 1
          log.debug("Instance #{inst['nickname']} flagged for age..")
        end
      end 
    end
    log.debug("Flagged instance count: #{@flagged_instances}")
    log.debug("Active instance count: #{ary.active_instances_count.to_s}")
    if (@flagged_instances >= (ary.active_instances_count.to_f / 2))
      log.info("Terminatation of array \"#{ary.nickname}\" initiated..")
      ary.active = false
      ary.save
      ary.terminate_all
      log.info("Terminating #{ary.nickname}\n")
      send_email(:resource_type => "array", :resource_name => ary.nickname)
    end
  end
end



#main
start_time = Time.now

if @opts[:account_id]
  log.info("Accounts to process: #{@opts[:account_id].inspect}")
  @opts[:account_id].each do |id|
    change_account(:account_id => id)
    terminate_servers
    termiante_ec2_arrays
  end
else
  terminate_servers
  terminate_ec2_arrays  
end


time_taken = ((Time.now - start_time)/60)
log.info("Total time taken was: #{time_taken} minutes")

=end
