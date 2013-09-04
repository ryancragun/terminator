# RightScale Terminator

A Ruby library that parses given RightScale accounts and terminates/destroys/disables resources depending on given parameters.  It's built on the 'rest\_connection' gem that support RightScale API 0.1, 1.0, 1.5.  This gem will likely be updated to depend on right\_api\_client when unified clusters are standard.

Written and maintained by Ryan Cragun /ryan at rightscale dot com/

## Installation
  "git clone git://github.com/ryancragun/terminator.git"
  
## Configuration
  Configure '~/.rest\_connection/rest\_api\_config.yaml' or '/etc/rest\_connection/rest\_api\_config.yaml' with API credentials
  
  Configure '~/.rs\_terminator/rs\_terminator.yaml' or '/etc/rs\_terminator/rs\_terminator.yaml' with config options.
  
  You can optionally supply parameter values from the command line or when initializing a specific class.
    
    /bin/terminator --server-hours 24
    Terminator::ServerTerminator.new(:server_hours => 24)

  See /config/rs\_terminator.yaml.example for an example config

## Usage
    /bin/terminator [options]
    [options] are:
    --server-hours, -s, Minimum number of hours server must have been running to qualify for termination
    --volume-hours, -v, Minimum number of hours volume must have been unattached to qualify for termination
    --snapshot-hours, -n, Minimum number of hours snapshot must be to qualify for termination
    --array-hours, -a, Minimum number of hours array instances must have been running to qualify for termination
    --array-threshold, -r, Percentage of instances flagged to disable array, eg: 50%
    --safe-words, -w, An array of safe words that prevents a server from being shut down. Must be included in the server nickname or as a terminator tag
    --admin-email, -m, Email address to send all termination notifications
    --disable-user-email, -d, true|false: enable or disable email notifcations to user who launched server.  Currently available on Ec2 Servers only
    --disable-admin-email, -b, true|false: enable or disable all email termination notification
    --account-ids, -i, An array of Account ID(s) that you wish to parse.
    --tag, -t, Tag namespace for terminator to track servers
    --terminator-email, -e, Email address that will send notification emails
    --admin-cc-list, -c, An array of email addresses to CC the Admin reports to
    --mail-server, -l, Local mail server to use, eg :sendmail
    --terminate-servers, --no-terminate-servers, true|false: enable or disable server termination (default: true)
    --terminate-arrays, --no-terminate-arrays, -y, true|false: enable or disable server termination (default: true)
    --terminate-volumes, --no-terminate-volumes, -o, true|false: enable or disable volume termination (default: true)
    --terminate-snapshots, --no-terminate-snapshots, -p, true|false: enable or disable snapshot termination (default: true)
    --help, -h, Show this message    
