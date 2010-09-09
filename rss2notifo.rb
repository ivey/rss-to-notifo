#!/usr/bin/ruby

require "rubygems"
require "bundler/setup"
Bundler.require(:default)
require 'optparse'
require 'cgi'
require 'open-uri'

@options = {
  :user  => ENV["NOTIFO_USER"],
  :key   => ENV["NOTIFO_KEY"],
  :title => "RSS Notification",
  :db    => File.dirname(__FILE__) + "/seen.db"
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: rss2notifo.rb [@options] FEED_URL"
  
  opts.on("-u", "--user USER", "Notifo username") do |u|
    @options[:user] = u
  end

  opts.on("-k", "--key APIKEY", "Notifo API key") do |k|
    @options[:key] = k
  end

  opts.on("-l", "--label LABEL", "Application label") do |l|
    @options[:label] = l
  end

  opts.on("-t", "--title TITLE", "Event title") do |t|
    @options[:title] = t
  end

  opts.on("-d", "--db DATABASE", "Database file for seen items") do |d|
    @options[:db] = d
  end

  opts.on("-q", "--quiet", "Don't send, just update database") do
    @options[:quiet] = true
  end

  opts.on("-v", "--verbose", "Tell me what's going on") do
    @options[:verbose] = true
  end
end
parser.parse!

def msg(t)
  puts t if @options[:verbose]
end

feed = ARGV[0]
unless @options[:user] && @options[:key] && feed
  puts parser
  exit
end

msg "RSS->Notifo starting"

db = if File.exist?(@options[:db])
       msg "Using existing #{@options[:db]} as database"
       open(@options[:db]) { |f| Marshal.load(f) } || { }
     else
       msg "Creating new database at #{@options[:db]}"
       { }
     end

msg "Initialiing Notifo for user #{@options[:user]}"
notifo = Notifo.new(@options[:user],@options[:key])

msg "Fetching feed: #{feed}"
rss = SimpleRSS.parse(open(feed))

rss.entries.each do |entry|
  msg "Entry: #{entry.title}"
  unless db.keys.include? entry[:id]
    resp = notifo.post(@options[:user],entry.title,@options[:title],CGI.escape(entry.link),@options[:label]) unless @options[:quiet]
    msg "Sending notification: #{resp}"
  end
  db[entry[:id]] = entry.published
end

msg "Saving database"
open(@options[:db], "w") { |f| Marshal.dump(db,f) }

msg "All done. Bye bye."
