#!/usr/bin/ruby

#a Job object is created for each job in the XML query list
class Job
  attr_accessor :name,:url,:urllatest,:userid,:number,:timestamp,:changeNumber,:stableBuild
  def initialize(name,url,urllatest,userid,number,timestamp,changeNumber,stableBuild)
    @name = name
    @url = url
    @urllatest = urllatest
    @userid = userid
    @number = number
    @timestamp = timestamp
    @changeNumber = changeNumber
    @stableBuild = stableBuild
  end
end

#an XML object contains the XML response from a Jenkins query
class XML
  attr_accessor :httpresponse, :httpresponsereturn, :xmlresponse, :xmlresponsereturn
  def initialize(url,authentication)
    uri = URI.parse(url)
    request = Net::HTTP::Get.new(uri.path)
    request.basic_auth(authentication[:username],authentication[:password])
    connection = Net::HTTP.new(uri.host, uri.port)
    @httpresponse = connection.start {|http| http.request(request) }
    case @httpresponse
    when Net::HTTPSuccess
      @xmlresponse = REXML::Document.new(@httpresponse.body)
    else
      @httpresponsereturn = 'fail'
      @xmlresponsereturn = 'fail'
    end
  end
end

#an Output object is created and is used to output a list of Job objects stored in the job_collection hash
class Output
  def initialize(job_collection,output)
    case output
    when 'screen'
      job_collection.each do |jobkey,jobvalue|
        if jobvalue.stableBuild = 'true'
          print 'Name,',jobvalue.name,',UserId,',jobvalue.userid,',Number,',jobvalue.number,',changeNumber,',jobvalue.changeNumber,"\n"
        end
      end
    when 'table'
      puts 'Table Output'
      table_rows = Array.new
      job_collection.each do |jobkey,jobvalue|
        table_rows << [jobvalue.name,jobvalue.userid,jobvalue.number,jobvalue.changeNumber]
      end
      #prints to table
      table = Terminal::Table.new :headings => ['Name', 'UserID','Number','ChangeList'] , :rows => table_rows
      table.align_column(5, :right)
      puts table
    end
  end
end

require 'optparse'
require 'net/http' #require 'uri' is included by net/http automatically
require 'rexml/document'
require 'rubygems'
require 'terminal-table'

program_name = File.basename($PROGRAM_NAME)

options = {:output => "table"}
jenkins_authentication = {:username => '', :password => ''};
jenkins_url_array = {:protocol => 'http', :hostname => '', :port => '8080', :path => '/jenkins/'};
job_collection = {};

optparse = OptionParser.new do |opts|
  #sets options banner
  opts.banner = "Usage: #{program_name} [options]"
  #options processing: output
  opts.on("-o","--output OUTPUT","Output method. Accepts values \"screen\" or \"table.\" Default value is \"table\".") do |output|
    #forces option to lowercase - easier to evaluate variables when always lowercase
    output.downcase!
    if (output == "screen" || output == "table")
      options[:output] = output
    else
      $stderr.print "You must specify an output method such as \"screen\" or \"table\". You specified \"", output, ".\"\n"
      exit 64
    end
  end
  opts.on("-u","--username USERNAME","Username to be utilized when connecting to the Jenkins API.") do |username|
    jenkins_authentication[:username] = username
  end
  opts.on("-p","--password PASSWORD","Password or Token to be utilized when connecting to the Jenkins API.") do |password|
    jenkins_authentication[:password] = password
  end
  opts.on("-h","--hostname HOSTNAME","Hostname to be utilized when connecting to the Jenkins API.") do |hostname|
    jenkins_url_array[:hostname] = hostname
  end
  opts.on("--protocol PROTOCOL","Protocol to be utilized when connecting to the Jenkins API. Defaults to http.") do |protocol|
    jenkins_url_array[:protocol] = protocol
  end
  opts.on("--port PORT","Port to be utilized when connecting to the Jenkins API. Defaults to 8080.") do |port|
    jenkins_url_array[:port] = port
  end
  opts.on("--path PATH","Path to be utilized when connecting to the Jenkins API. defaults to /jenkins/.") do |path|
    jenkins_url_array[:path] = path
  end
end
optparse.parse!

#validation of options - any options here are required
if jenkins_authentication[:username].empty?
  $stderr.print "You must specifiy a Username to be utilized with connecting to the Jenkins API. You can specify a Username using either -u <myusername> or --username <myusername>.""\n"
  exit 64
end
if jenkins_authentication[:password].empty?
  $stderr.print "You must specifiy a Password or API token to be utilized with connecting to the Jenkins API. You can specify a Password using either -p <mypassword> or --password <password>.""\n"
  exit 64
end
if jenkins_url_array[:hostname].empty?
  $stderr.print "You must specifiy a Hostname to be utilized with connecting to the Jenkins API. You can specify a Hostname using either -h <hostname> or --hostname <hostname>.""\n"
  exit 64
end

#creates a single object to be provided to methods that use the Jenkins API
jenkins_url = jenkins_url_array[:protocol] + '://' + jenkins_url_array[:hostname] + ':' + jenkins_url_array[:port] + jenkins_url_array[:path]
#jobslist is a list of jobs returned from polling the Jenkins API
jobslist = XML.new( jenkins_url + '/api/xml',jenkins_authentication)

#shortcut - if XML response is nil, exit
if jobslist.xmlresponse.nil?
  $stderr.print "There was an error retreiving data from the Jenkins instance at " , jenkins_url , ".\n"
  exit 64
end

jobslist.xmlresponse.each_element('hudson/job') do |jobelement|
  jobname = jobelement.elements['name'].text
  joburl = jobelement.elements['url'].text
  joburllateststable = jobelement.elements['url'].text + 'lastStableBuild/api/xml/'
  jobxml = XML.new(joburllateststable,jenkins_authentication)
  #jobxml can either be nil, in which can a success
  if jobxml.xmlresponse.nil?
    joburllastbuild = jobelement.elements['url'].text + 'lastBuild/api/xml/'
    jobxml = XML.new(joburllastbuild,jenkins_authentication)
    if jobxml.xmlresponse.nil?
      jobstableBuild = 'false'
    else
      print 'failed to retreive data for', jobname, ' at ', joburl, "\n"
    end
  else
    jobstableBuild = 'true'
    unless jobxml.xmlresponse.elements['freeStyleBuild/action/cause/userId'].nil?
      jobuserid = jobxml.xmlresponse.elements['freeStyleBuild/action/cause/userId'].text
    end
    unless jobxml.xmlresponse.elements['freeStyleBuild/number'].nil?
      jobnumber = jobxml.xmlresponse.elements['freeStyleBuild/number'].text
    end
    unless jobxml.xmlresponse.elements['freeStyleBuild/timestamp'].nil?
      jobtimestamp = jobxml.xmlresponse.elements['freeStyleBuild/timestamp'].text
    end
    unless jobxml.xmlresponse.elements['freeStyleBuild/changeSet/item/changeNumber'].nil?
      jobchangeNumber = jobxml.xmlresponse.elements['freeStyleBuild/changeSet/item/changeNumber'].text
    end
  end
  #puts jobname,joburl,joburllateststable
  jobobject = Job.new(jobname,joburl,joburllateststable,jobuserid,jobnumber,jobtimestamp,jobchangeNumber,jobstableBuild)
  job_collection[jobobject.name] = jobobject
end

output = Output.new(job_collection,options[:output])