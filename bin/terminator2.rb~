#!/usr/bin/env ruby

# Terminator2, Ryan Cragun
# Inspired by the original Terminator by Rob Carr
# Finds and terminates servers and server arrays within a RightScale account based on passed parameters.
# Should be run as a cron daemon at least hourly.
# Requires rest_connection gem to be pre-configured with RightScale credentials.

require 'rubygems'
require 'rest_connection'
require 'time'
require 'trollop'
require 'net/smtp'
require 'resolv'
require 'logger'

# Parse options
@opts = Trollop::options do
  version = "2.5"
  banner <<-EOS
  Terminator is a command line utility for scraping RightScale accounts and terminating servers that is written and maintained by Ryan Cragun.
  Depends on rest_connection and trollop Rubygems
  If rest_connection hasn't been configured be sure to pass --login and --account-id params

  Usage:
 
  ./terminator [options]
  [options] are:
  EOS
  
  opt :hours, "Minimum number of hours server must have been running to qualify for termination", :default => 24, :short => "-h"
  opt :safe_word, "A safe word that prevents a server from being shut down. Must be included in the server nickname or as a terminator tag", :default => "save", :short => "-w"
  opt :debug, "true|false: enables or disable DEBUG logging", :default => false, :short => "-d"
  opt :min_id, "Sets the minimum server ID for server termination candidates", :type => :int, :short => "-i"
  opt :admin_email, "Email address to send all termination notifications", :type => :string, :short => "-m"
  opt :user_email, "true|false: enable or disable email notifcations to user who launched server.  Currently available on Ec2 Servers only", :default => true, :short => "-u"
  opt :disable_email, "true|false: enable or disable all email termination notification", :default => false
  opt :account_id, "Account ID(s) that you wish to parse.  Use a comma separated list if more than one, i.e.: -a 5679,1235", :type => :strings, :short => "-a"
  opt :tag, "Tag namespace and predicate for terminator to track servers", :default => "terminator", :short => "-t"
  opt :login, "RightScale account email address and password for API access. Usage: --login jane.doe@example.com:password", :type => :string, :short => "-l" 
  opt :terminator_login "Terminator account email address and password for termination emails. Usage: --terminator-login jane.doe@example.com:password", :default => "root@localhost"
  opt :terminator_smtp, "Terminator smtp server and port from which to send termination notifications. Usage: --terminator-smtp smtp.google.com:587", :default => "localhost:25"
  opt :terminate_servers, "true|false: enable or disable server termination", :default => true
  opt :terminate_arrays, "true|false: enable or disable server termination", :default => true
  opt :terminate_volumes, "true|false: enable or disable volume termination", :default => false
  opt :terminate_snapshots, "true|false: enable or disable snapshot termination", :default = false
end

# Setup our logging
log = Logger.new(STDOUT)
log.level = @opts[:debug] ? Logger::DEBUG : Logger::INFO

# Validate email syntax and resolvability of domain
def valid_email?(email)
  log.debug("Validating email: #{email}")
  domain = email.match(/\@(.+)/)[1]
  Resolv::DNS.open do |dns|
    @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
  end    
  valid = @mx.size > 0 ? true : false
  unless email =~ /^[a-zA-Z][\w\.-]*[a-zA-Z2-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/
    log.error("#{email} does not appear to be a valid email address")
    return false
  else
    log.error("Unable to resolve #{domain} domain") unless valid
    return false unless valid
  end
  true
end

# validate admin email
if @opts[:admin_email] 
    Trollop::die :admin_email, "parameter --admin-email does not meet required criteria" unless valid_email?(@opts[:admin_email])
end 

# Change RightScale account and refresh rest_connection cookie
def change_account(opts={})
  log.debug("Changing account settings to account id to #{opts[:account_id]}")
  log.debug("Changing account settings user/password to #{@opts[:login]}") if @opts[:login]
  Server.connection.settings[:api_url] = "https://my.rightscale.com/api/acct/#{opts[:account_id]}"
  Server.connection.settings[:user] = @opts[:login].split(":")[0] if @opts[:login]
  Server.connection.settings[:pass] = @opts[:login].split(":")[1] if @opts[:login]
  Server.connection.refresh_cookie
end

# Generate Terminator email message 
# generate_message(:resource_name => "nickname", :resource_type => "array", :recipient_email => "recipient@email.com")
def generate_message(opts={})
  valid = opts[:resource_name] && opts[:recipient_email] && opts[:resource_type] ? true : false
  log.debug("Generating email message for a #{opts[:resource_type]} named #{opts[:resource_name]} to be sent to #{opts[:recipient_email]}")
  message = <<END_OF_MESSAGE
From: The Terminator
To: @@RECIPIENT@@
Subject: @@SUBJECT@@
Date: #{Time.now}

@@MESSAGE@@
END_OF_MESSAGE
  
  server_subject="The \"#{opts[:resource_name]}\" Server has been terminated by the Terminator"
  server_message="The \"#{opts[:resource_name]}\" Server has been terminated by the Terminator. Be sure to lock the Server, put \"#{@opts[:safe_word]}\" somewhere in the Server nickname or tag it with \"#{@opts[:tag]}:#{@opts[:safe_word]}=true\" to prevent pwnage from the Terminator." 
  server_message << " If you have questions please contact your admin. #{@opts[:admin_email]}"
  array_subject="The \"#{opts[:resource_name]}\" ServerArray has been disabled by the Terminator"
  array_message="The \"#{opts[:resource_name]}\" ServerArray has been disabled and all instances terminated because at least 50% of the instances were at least #{@opts[:hours]} hours old. Make sure you have \"#{@opts[:safe_word]}\" somewhere in the Array nickname or it's tagged with \"#{@opts[:tag]}:#{@opts[:safe_word]}=true\" to prevent pwnage from the Terminator." 
  array_message << " If you have questions please contact your admin. #{@opts[:admin_email]}"
  
  message.gsub!(/@@RECIPIENT@@/,opts[:recipient_email])
  if opts[:resource_type] == "server"
    message.gsub!(/@@SUBJECT@@/,server_subject)
    message.gsub!(/@@MESSAGE@@/,server_message)
  elsif opts[:resource_type] == "array"
    message.gsub!(/@@SUBJECT@@/,array_subject)
    message.gsub!(/@@MESSAGE@@/,array_message)
  end
  
  if valid 
    return message 
  else
    log.error("Unable to generate email, invalid or insufficeint paramaters")  
    return false 
  end
end

#send_email(:resource_type => "server", :resource_name => "nickname", :launched_by => "launcher@email.com")
# Send termination email
def send_email(opts={})
  log.debug("Sending email has been disabled") && return true if @opts[:disable_email]
  recipients = Array.new
  recipients.push(opts[:launched_by]) if opts[:launched_by]
  recipients.push(@opts[:admin_email]) if @opts[:admin_email]
  recipients.each do |recipient|
    message = generate_message(:resource_name => opts[:resource_name], :resource_type => opts[:resource_type], :recipient_email => recipient)
    sender = @opts[:terminator_login].split(":")[0]
    pass = @opts[:terminator_login].split(":")[1]
    domain = @opts[:terminator_smtp].match(/smtp.google.com/) ? sender : sender.split("@")[0]
    mail_server = @opts[:terminator_smtp].split(":")[0]
    port = @opts[:terminator_smtp].split(":")[1]
    smtp = Net::SMTP.new(mail_server, port)
    smtp.enable_starttls_auto if smtp.respond_to?(:enable_starttls_auto)
    log.debug("Sending email from #{sender} to #{recipient}")
    log.debug("Using domain: #{domain}, server: #{server}, port: #{port}")
    if pass 
      smtp.start(domain, sender, pass, :plain) do |smtp|
        res = smtp.send_message(message, sender, recipient)
      end
    else
      smtp.start(domain, sender, :plain) do |smtp|
        res = smtp.send_message(message, sender, recipient)
      end
    end
    res.success? log.debug("Response: #{res.message}") : log.error("Error: #{res.message}")
  end
end

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
