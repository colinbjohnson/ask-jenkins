#!/usr/bin/ruby

#a Job object is created for each job in the XML query list
class Job
  attr_accessor :name,:url,:urllatest,:userid,:number,:timestamp,:changeNumber,:stableBuild
  attr_accessor :lastChangeNumber
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
  def getLastChangeNumber(url,changenumber,buildnumber,jenkins_authentication)
    unless buildnumber.nil?
      buildnumber = buildnumber.to_i
      #would prefer while changeNumber.nil? or buildnumber > 0 but this did not work
      #if changeNumber is nil, iterate backward until a valid change number is found or exit if build number reaches 0
      #ideal would be that valid build numbers are pulled from API
      while changeNumber.nil?
        #url_iterator is url to be queried, iterates backward
        url_cursor = url + buildnumber.to_s + '/api/xml'
        jobxml = XML.new(url_cursor,jenkins_authentication)
        if jobxml.xmlresponse.nil?
          #jobxml could not get a response - for instance, the url_cursor is invalid
        else
          unless jobxml.xmlresponse.elements['freeStyleBuild/changeSet/item/changeNumber'].nil?
            @lastChangeNumber = jobxml.xmlresponse.elements['freeStyleBuild/changeSet/item/changeNumber'].text
          end
        end
        if buildnumber == 0
          break
        else
          buildnumber -= 1
        end
      end
    end
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
          print 'Name,',jobvalue.name,',UserId,',jobvalue.userid,',Number,',jobvalue.number,',changeNumber,',jobvalue.changeNumber,',lastChangeNumber,',jobvalue.lastChangeNumber,"\n"
        end
      end
    when 'table'
      puts 'Table Output'
      table_rows = Array.new
      job_collection.each do |jobkey,jobvalue|
        table_rows << [jobvalue.name,jobvalue.userid,jobvalue.number,jobvalue.changeNumber,jobvalue.lastChangeNumber]
      end
      #prints to table
      table = Terminal::Table.new :headings => ['Name', 'UserID','Number','ChangeList','lastChangeList'] , :rows => table_rows.sort
      table.align_column(5, :right)
      puts table
    end
  end
end