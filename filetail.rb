#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'net/smtp'

$counterthreshold = 24 #168 #hours in intervals, 168 being 1 week

if !ARGV[0]
  path = "#{File.expand_path(File.dirname(__FILE__))}/../solr/solr.log"     #path to Solr's log
else
  path = ARGV[0]
end

class String
   def clear
     replace ""
   end
end

def sendnotifications(notification)



  #Email configuration
  recipients = ["xxx@xxx.com"]  #as an array to allow for multiple recipients
  mailuser = 'xxx@xxx.com'
  mailsmtp = 'xxx.xxx.xxx.xxx'




  Net::SMTP.start(mailsmtp, 25) do |smtp|
    message = ''
    message = <<EOF
From: Noc <#{mailuser}>
To: #{recipients.join(", ")}
Subject: #{`hostname`} Top Querytime Log 

Debug information:


#{notification}
EOF
smtp.send_message(message, mailuser, recipients)
  end
end

def sec2hour(seconds)
  seconds*3600
end

def watch_for(file)
  resultdata = Hash.new
  cleanup = Hash.new
  arry = []
  endofday = []
  searchrecord = []
  logrecord = []
  time_counter = 0
  Thread.new {
    while true
      if time_counter == sec2hour($counterthreshold)
        endofday.clear
        endofday = resultdata.keys
        endofday.each do |keys|
          cleanup["#{keys}"] = resultdata["#{keys}"]["hitstoday"].to_i
        end
        searchrecord.clear
        logrecord.clear
        logrecord = searchrecord = cleanup.sort_by {|k,v| -v }.map(&:first) #sort by the number of hits for logging
        lognotification = ''
        searchrecord = cleanup.sort_by {|k,v| -v }[0..19].map(&:first) #sort by the number of hits by top 20 for email
        delivernotification = ''
        searchrecord.each do |eachrecord|
          delivernotification << "
          CoreName     #{resultdata["#{eachrecord}"]["corename"]}
          WebApp       #{resultdata["#{eachrecord}"]["webapp"]}
          Path         #{resultdata["#{eachrecord}"]["path"]}
          Params       #{resultdata["#{eachrecord}"]["params"]}
          Hits         #{resultdata["#{eachrecord}"]["hits"]}
          Status       #{resultdata["#{eachrecord}"]["status"]}
          QueryTime    #{resultdata["#{eachrecord}"]["querytime"]}
          NumQueries   #{resultdata["#{eachrecord}"]["hitstoday"]}
          LogTimes     #{resultdata["#{eachrecord}"]["logtimes"]}\n\n\n\n"
        end
        logrecord.each do |eachrecord|
          lognotification << "
          CoreName     #{resultdata["#{eachrecord}"]["corename"]}
          WebApp       #{resultdata["#{eachrecord}"]["webapp"]}
          Path         #{resultdata["#{eachrecord}"]["path"]}
          Params       #{resultdata["#{eachrecord}"]["params"]}
          Hits         #{resultdata["#{eachrecord}"]["hits"]}
          Status       #{resultdata["#{eachrecord}"]["status"]}
          QueryTime    #{resultdata["#{eachrecord}"]["querytime"]}
          NumQueries   #{resultdata["#{eachrecord}"]["hitstoday"]}
          LogTimes     #{resultdata["#{eachrecord}"]["logtimes"]}\n\n\n\n"
        end
        `cat /dev/null > #{file}`
        if !searchrecord[0].nil?  #only send/write/clear notifications if there are new log records in the buffer
          sendnotifications(delivernotification)
          File.open('solr-slowquery.log', 'w') { |logfile| logfile.write(lognotification) }
        end
        resultdata.clear
        cleanup.clear
        time_counter = 0
      end
      time_counter += 1
      sleep 1
    end
  }
  f = File.open(file,"r")
  f.seek(0,IO::SEEK_END)
  while true do
    select([f])
    line = f.gets
    if /QTime=[0-9][0-9]{4,}/ =~ line
      arry = line.split
      begin
        corename = arry[1].tr("[","").tr("]","")
      rescue
        corename = arry[1]
      end
      begin
        hitstoday = resultdata["#{"#{arry[4]}"[7..-1]}"]['hitstoday'] + 1
        logtimes  = resultdata["#{"#{arry[4]}"[7..-1]}"]['logtimes'] + " #{"#{Time.now}".split[3]}"
      rescue
        hitstoday = 1
        logtimes  = "#{"#{Time.now}".split[3]}"
      end
      resultdata["#{"#{arry[4]}"[7..-1]}"] = {
          'corename'  => corename,
          'webapp'    => "#{arry[2]}"[7..-1],
          'path'      => "#{arry[3]}"[5..-1],
          'params'    => "#{arry[4]}"[7..-1],
          'hits'      => "#{arry[5]}"[5..-1].to_i,
          'status'    => "#{arry[6]}"[7..-1].to_i,
          'querytime' => "#{arry[7]}"[6..-1].to_i,
          'hitstoday' => hitstoday,
          'logtimes'  => "#{logtimes}",
      }
      logtimes.clear
      arry.clear
    end
    sleep 0.01
  end
end

begin
  watch_for(path)
rescue
  puts "Must add a valid filepath to argument!"

