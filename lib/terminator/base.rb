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
      @opts = opt if validate_options(opt)
    end

    def load_options()
      config_yaml = File.join(File.expand_path("~"), ".rs_terminator", "rs_terminator.yaml")
      etc_config = File.join("#{File::SEPARATOR}etc", "rs_terminator", "rs_terminator.yaml")
      if File.exists?(config_yaml)
        logger(:info,"Loading options from #{config_yaml}")
        return YAML::load(IO.read(config_yaml))
      elsif File.exists?(etc_config)
        logger(:info,"Loading options from #{etc_config}")
        return YAML::load(IO.read(etc_config))
      else
       logger(:info,"No configuration file found.  Generating default options for you...")
       defaults = {:safe_words=>["save"], :disable_user_email=>false, :tag=>"terminator"} 
       con = RestConnection::Connection.new.settings
       defaults[:terminator_email], defaults[:admin_email] = con[:user], con[:user]
       defaults[:account_ids] = [con[:api_url].split('/').last.to_i] if con[:api_url]
       return defaults
      end
    end

    def validate_options(params) 
      required_params = [:account_ids, :admin_email]
      valid_params    = [:server_hours, :volume_hours, :snapshot_hours, :tag, :safe_words, 
                         :whitelist, :blacklist, :admin_email, :disable_user_email, 
                         :account_ids, :terminator_email, :array_hours, :admin_cc_list,
                         :array_threshold, :disable_admin_email, :mail_server, :mail_server_location]
      valid = params.keys.all? {|p| valid_params.include? p}
      required = required_params.all? {|p| params.key? p}
      boiler_plate = "Please pass an option hash or configure rs_terminator.yaml in #{@config_yaml} or #{@etc_config}.\n"
      boiler_plate += "See terminator/config/rs_terminator.yaml.example for example config."
      if valid && required
        logger(:info,"Options validated...")
      elsif valid
        message = "You haven't passed the required :account_ids and/or :admin_email parameters\n" + boiler_plate
        logger(:fatal, message)
        false
      elsif required
        message = "You've passed invalid parameters" + boiler_plate
        logger(:fatal, message)
        false
      else
        message = "You haven't passed the required parameters or setup a configuration file\n" + boiler_plate
        logger(:fatal, message)
      false
      end 
    end  
    
    def logger(level, message)
      init_message = "[Terminator] Initializing Logging using "
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
      when :fatal
        @@logger.fatal("[Terminator] " + message)
      when :debug
        @@logger.debug("[Terminator] " + message)
      when :info
        @@logger.info("[Terminator] " + message)
      when :warn
      @@logger.warn("[Terminator] " + message)
      when :error
      @@logger.error("[Terminator] " + message)
      end 
    end
  
    def valid_email?(email)
      logger(:debug,"Validating email: #{email}") if @opts[:debug]
      domain = email.match(/\@(.+)/)[1]
      Resolv::DNS.open do |dns|
        @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
      end    
      valid = @mx.size > 0 ? true : false
      unless email =~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/
        logger(:error,"#{email} does not appear to be a valid email address")
        return false
      else
        logger(:error,"Unable to resolve #{domain} domain") unless valid
        return false unless valid
      end
      true
    end
  
    def change_account(account_id)
      return true if Server.connection.settings[:api_url].split('/').last.to_i == account_id
      logger(:info,"Changing account settings to account id to #{account_id}")
      Server.connection.settings[:api_href] = "https://my.rightscale.com/api/acct/#{account_id}"
      Server.connection.settings[:api_url] = "https://my.rightscale.com/api/acct/#{account_id}"
      Server.connection.refresh_cookie
      ServerInternal.connection.settings[:api_href] = "https://my.rightscale.com/api/acct/#{account_id}"
      ServerInternal.connection.settings[:api_url] = "https://my.rightscale.com/api/acct/#{account_id}"
      ServerInternal.connection.cookie = nil
    end

    def send_email(message,recipient_emails)
      recipient_emails = [recipient_emails] if recipient_emails.is_a?(String)
      recipient_emails.each do |m| 
        ( logger(:info,"#{m} seems to be an invalid address, skipping") && next ) unless valid_email?(m)
        logger(:info,"Sending email to #{m}")
        mail = Mail.new
        mail.from =  @opts[:terminator_email]
        mail.to = m
        mail.subject = message[:subject]
        mail.body = message[:body]
        mail.delivery_method @opts[:mail_server]
        mail.deliver
      end
    end 

    def verify_email_server()
      if system('which sendmail > /dev/null')
        @opts[:mail_server] = :sendmail
        @opts[:terminator_email] = @opts[:admin_email] unless @opts[:terminator_email]
      else
        logger(:error,"No email delivery manager can be found, disabling email")
        @opts[:disable_admin_email], @opts[:disable_admin_email] = true, true
      end
    end

    def has_safe_word_in_name?(nickname)
      ret=false
      return ret if nickname.nil?
      @opts[:safe_words].each {|w| nickname.downcase.include?(w.downcase) ? ret = true : false}
      ret
    end

    def has_safe_tag?(tags)
      safe_tags = [] 
      @opts[:safe_words].each {|w| safe_tags << "#{@opts[:tag]}:#{w}=true"} 
      matches = safe_tags & tags
      matches.empty? ? false : true
    end

    def has_terminator_tag?(tags)
      terminator_tag, ret  = "#{@opts[:tag]}:discovery_time", false
      tags.each { |tag| tag.include?(terminator_tag) ? ret = tag : false}
      ret
    end
    
    def get_discovery_time(tags)
      tag = has_terminator_tag?(tags)
      Time.parse(tag.split("=")[1])
    end
  end
end
