#!/usr/bin/env ruby

require 'net/imap'
require 'yaml'
require 'optparse'
require 'rubygems'
require 'highline/import'
require 'date'

#nothing is perfect in this go-damn imperfect world :-)
#so, should u hv the fun to extend this, pse also consider using 
#the RFC specification of the IMAP Protocol here : http://tools.ietf.org/html/rfc1730
#otherwise, have fun... or contact me (nemesisfixxed@gmail.com)

options = {}

def get_password()
    password = ask("Password:  ") { |q| q.echo = "*" }
end

optparse = OptionParser.new do |opts|
    opts.banner = "climail : simple,direct mail access via command line\r\nUsage : climail [options]"

    options[:verbose] = false
    opts.on( '-v', '--verbose', 'Spit more information') do
        options[:verbose] = true
    end

    options[:config_node] = 'gmail'
    opts.on('-n','--config_node NODE','Configuration Node to use') do |node|
        options[:config_node] = node
    end


    options[:folder] = 'INBOX'
    options[:override_folder] = false
    opts.on('-f','--imap_folder FOLDER','The IMAP folder to read mail from') do |folder|
        options[:folder] = folder
        options[:override_folder] = true 
    end

    options[:config_file] = 'conf.yaml'
    opts.on('-c','--config_file FILE','Configuration file to use') do |file|
        options[:config_file] = file
    end

    options[:password] = nil
    opts.on('-p','--password PASS','Password to use') do |password|
        options[:password] = password
    end

    options[:user] = nil
    opts.on('-u','--username USER','User to use') do |user|
        options[:user] = user
    end

    #options[:show_body] = false
    #opts.on('-b','--show_body','Show Email Body') do
    #    options[:show_body] = true
    #end

    opts.on('-h','--help','Get an S.O.S!') do
        puts opts
        exit
    end
end


#parse commandline options...
optparse.parse!

#shit might go wrong!
#programming is not an 'exact' science :-)
begin
    puts "Using configuration file '#{options[:config_file]}'" if options[:verbose]
    config = YAML.load(File.open(options[:config_file]))

    c = config[options[:config_node]]
    puts "Using configuration node '#{options[:config_node]}'" if options[:verbose]

    cred = c['credentials']

    #if we still didn't get a password, prompt the user for one
    if options[:password].nil?:
            options[:password] = get_password 
    end

    user = nil

    if options[:user].nil?
        if cred['username'].nil?
            print "\r\nUsername : "
            user = gets.chomp
        else
            user = cred['username']
        end
    else
        user = options[:user]
    end


    folder = c['folder'] || options[:folder]
    folder = options[:folder] if options[:override_folder]

    imap = Net::IMAP.new(c['imap_server'],c['imap_port'],true)
    puts "Connected to server '#{c['imap_server']}:#{c['imap_port']}'" if options[:verbose]

    imap.login(user, options[:password])
    puts "Logged in as  '#{user}'" if options[:verbose]

    imap.select(folder) #specify mail folder to read from
    puts "Reading from IMAP folder  '#{folder}'" if options[:verbose]

    puts "Checking out all new mail..." if options[:verbose]
    #we shall only read new mail...
    subject_key = "BODY[HEADER.FIELDS (SUBJECT)]"
    from_key = "BODY[HEADER.FIELDS (FROM)]"
    date_key = "INTERNALDATE"
    #body_key = "RFC822.TEXT"
    imap.search(["UNSEEN"]).each do |message_id|
      sub = imap.fetch(message_id, subject_key)[0]
      date = imap.fetch(message_id, date_key)[0]
      from = imap.fetch(message_id, from_key)[0]
      #now format our output nicely...
      #but, apparently, gmail's internal dates are not ok for my time-zone
      #so some time tweaking is necessary too
      date = DateTime.parse(date.attr[date_key]).strftime("%d %b,%Y %H:%M %p")
      subject = /Subject:(.*)$/.match(sub.attr[subject_key]).captures[0].strip
      from = /From:([^<]*)[^<]/.match(from.attr[from_key]).captures[0].strip
      puts "#{date} | #{from} |  #{subject}"

      #incase user wants to see the body too
      #if options[:show_body]:
      #    body = imap.fetch(message_id, body_key)[0]
      #    puts body
      #end

      #ensure the message is still 'unseen' on the server
      imap.store(message_id,'-FLAGS',[:Seen])
    end

    puts "Done checking mail.Closing down..." if options[:verbose]
    imap.logout()
    imap.disconnect() 

    puts "Disconnected from server. Bye" if options[:verbose]
rescue
    #who is to blame?
    puts "-- ERROR --"
end
#wasn't it nice?
