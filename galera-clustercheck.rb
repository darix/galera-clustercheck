#!/usr/bin/ruby
# vim: set sw=2 sts=2 et tw=80 :
require 'unicorn'
require 'mysql2'

config = {
  available_when_donor: false,
  disable_when_readonly: true,
  cache: 1,
  port: 8000,
  ipv6: true,
  check_user:     'clustercheck',
  check_password: 'foobar',
  check_host:     'localhost',
  check_port:     3306,
}
 
app=Proc.new { |env|
  current_time=Time.now
  read_only=false
  results=[]
  begin
    client = Mysql2::Client.new(host: config[:check_host], port: config[:check_port], username: config[:check_user], password: config[:check_password])
    # TODO: implement timeout
    if client
      results = client.query("SHOW STATUS LIKE 'wsrep_local_state'")
      if config[:disable_when_readonly]
        ro=client.query("SHOW VARIABLES LIKE 'read_only'").first
       if ro and ro['Value'] and %w{on 1}.include?(ro['Value'].downcase)
        read_only=true
       end
      end
    end
    if results.count < 1 
      ['520', {'Content-Type' => 'text/html'}, ["Percona XtraDB Cluster Node state could not be retrieved."]]
    elsif results.first and (results.first['Value'] == '4' or (config[:available_when_donor] and results.first['Value'] == '2'))
      ['200', {'Content-Type' => 'text/html'}, ["Percona XtraDB Cluster Node is synced."]]
    else  
      ['503', {'Content-Type' => 'text/html'}, ["Percona XtraDB Cluster Node is not synced."]]
    end
  rescue Exception => ex
    ['500', {'Content-Type' => 'text/html'}, ["woopsie daisy\n"]]
    p ex 
  ensure
    client.close
  end
}

Unicorn::HttpServer.new(app, {}).start.join
