module LAMAHelpers
  def import_incidents_to_database(incidents, client=nil)
    return if incidents.nil?
    incidents.each do |incident|
      import_incident_to_database(incident,client) if incident
    end
  end
  def import_incident_to_database(incident, client=nil)
    
    return if incident.nil?
    
    l = client || LAMA.new({ :login => ENV['LAMA_EMAIL'], :pass => ENV['LAMA_PASSWORD']})
    
    #incidents.each do |incident|
      begin
        case_number = incident.Number
        return if case_number.nil? || case_number.length == 0 # need to find a better way to deal with this ... revisit post LAMA data cleanup
        return unless incident.Type == 'Public Nuisance and Blight'
        location = incident.Location
        addresses = AddressHelpers.find_address(location)
        address = addresses.first if addresses
        division = get_incident_division_by_location(l,address.address_long,case_number) if address
        division = get_incident_division_by_location(l,location,case_number) if division.nil? || division.strip.length == 0
        division = incident.Division if division.nil? || division.strip.length == 0
        return unless division == 'CE'
        
        kase = Case.find_or_create_by_case_number(:case_number => case_number, :state => 'Open')
        kase.update_attribute(:address, address) if address && (!kase.address || address != kase.address)
        kase.update_attribute(:state, 'Closed') if incident.IsClosed =~/true/ && kase.state != 'Closed' 

        puts "case => #{case_number}   status => #{incident.CurrentStatus}    date => #{incident.CurrentStatusDate}"
        # orig_outcome = kase.outcome
        incident_full = l.incident(case_number)
        
        #Go through all data points and pull out relevant things here
        #Inspections
        inspections = incident_full.Inspections
        if inspections
          if inspections.class == Hashie::Mash
            inspections = inspections.Inspection
            if inspections.class == Array
              inspections.each do |inspection|
                parseInspection(case_number,inspection)          
              end
            else
              parseInspection(case_number,inspections)
            end
          end
        end

        judgements = incident_full.Judgments
        if judgements
          if judgements.class == Hashie::Mash
            judgements = judgements.Judgment
            if judgements.class == Array
              judgements.each do |judgement|
                parseJudgement(kase,judgement)
              end
            else
              parseJudgement(kase,judgements)
            end
          end
        end

        #Events
        events = []
        if incident_full.Events && incident_full.Events.IncidEvent
          events = incident_full.Events.IncidEvent
        end
        if events
          if events.class == Array
            events.each do |event|
              parseEvent(kase,event)#,spawn_hash)          
            end
          else
            parseEvent(kase,events)#,spawn_hash)
          end
        end

        #Actions
        actions = []
        if incident_full.Actions && incident_full.Actions.CodeAction
          actions = incident_full.Actions.CodeAction
          if actions
            if actions.class == Array
              actions.each do |action|
                parseAction(kase, action)
              end
            else
              parseAction(kase, actions)
            end     
          end      
        end


        # Violations
        # TODO: add violations table and create front end for this 
        # Judgments - Closed
        case_status = incident_full.Description
        if (case_status =~ /Status:/ && case_status =~ /Status Date:/)
          case_status = case_status[((case_status =~ /Status:/) + "Status:".length) ... case_status =~ /Status Date:/].strip

          d = incident_full.Description
          d = d[d.index('Status Date:') .. -1].split(' ')
          d = d[2].split('/')
          d = DateTime.new(d[2].to_i,d[0].to_i,d[1].to_i)

          parseStatus(kase,case_status,d)
        end
        
        # validateSchedHearings(kase)

      rescue StandardError => ex
        puts "THERE WAS AN EXCEPTION OF TYPE #{ex.class}, which told us that #{ex.message}"
        puts "Backtrace => #{ex.backtrace}"
      end
    #end
  end

  # def validateSchedHearings(kase)
  #   #is scheduled hearing valid?
  #       schedHearings = Hearing.where("case_number = '#{kase.case_number}' and is_complete = false")
  #       return if schedHearings.count == 0

  #       h = kase.last_hearing
  #       s = kase.last_status

  #       if kase.judgement || (h && h.is_complete )|| (h && s && h != s)
  #         schedHearings.destroy_all
  #         return
  #       end
  # end

  def parseEvent(kase,event)#,spawn_hash)
    case_number = kase.case_number
    if event.class == Hashie::Mash && event.IsComplete =~ /true/
      j_status = nil
      if ((event.Type =~ /Notice/ || event.Name =~ /Notice/) && (event.Type =~ /Hearing/ || event.Name =~ /Hearing/)) || (event.Type == 'Notice' || event.Name == 'Notice')
        Event.create(:name => 'Notification', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
      elsif event.Type =~ /Administrative Hearing/
        Event.create(:name => 'Hearing', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
      elsif ((event.Type =~ /Notice/ || event.Name =~ /Notice/) && (event.Type =~ /Reset/ || event.Name =~ /Reset/))
        Event.create(:name => 'Reset', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
      elsif event.Type =~ /Input Hearing Results/
       if event.Items != nil and event.IncidEventItem != nil
         event.IncidEventItem.each do |item|
           if item.class == Hashie::Mash
             if (item.Title =~ /Reset Notice/ || item.Title =~ /Reset Hearing/) && item.IsComplete == "true"
                Event.create(:name => 'Reset',:case_number => kase.case_number, :date => item.DateCompleted, :status => event.Status)
             end
           end
         end
       end
      elsif event.Type =~ /Inspection/ || event.Name =~ /Inspection/ || event.Type =~ /Reinspection/ || event.Name =~ /Reinspection/
        unless Event.where("name = 'Inspection' and case_number = '#{kase.case_number}' and (hearing_date >= '#{j.date.beginning_of_day.to_formatted_s(:db)}' and hearing_date <= '#{j.date.end_of_day.to_formatted_s(:db)}')").exists?
          Event.create(:name => 'Inspection', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
        end
      elsif event.Type =~ /Complaint Received/ || event.Name =~ /Complaint Received/
        Event.create(:name => 'Complaint', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
      elsif event.Type =~ /Research Property Record/
        Event.create(:name => 'Research Property Record', :date => event.DateEvent, :status => event.Status)  
      elsif (event.Name =~ /Guilty/ || event.Status =~ /Guilty/ || event.Type =~ /Guilty/) && (event.Name =~ /Hearing/ || event.Status =~ /Hearing/ || event.Type =~ /Hearing/)#event.Name =~ /Hearing/
        if event.Name =~ /Guilty/
          notes = event.Name.strip
        elsif event.Type =~ /Guilty/
          notes = event.Type.strip
        else
          notes = event.Status.strip
        end
        
        if notes =~ /Not Guilty/
          j_status = 'Not Guilty'
        else
          j_status = 'Guilty'
        end
        # kase.outcome = j_status
      elsif (event.Name =~ /Judgment/ && (event.Name =~ /Posting/ || event.Name =~ /Notice/ || event.Name =~ /Recordation/))
        j_status = ''
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Dismiss/) || (event.Name =~ /Hearing/ && (event.Status =~ /Dismiss/ || event.Status =~ /dismiss/))
        if event.Name =~ /Dismiss/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Closed'
        # kase.outcome = 'Closed: Dismissed'
      # elsif event.Name =~ /Dismiss/
      #   kase.outcome = 'Closed: Dismissed'
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Compliance/) || (event.Name =~ /Hearing/ && event.Status =~ /Compliance/)
        if event.Name =~ /Compliance/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Closed'
        # kase.outcome = 'Closed: In Compliance'
      # elsif event.Name =~ /Compliance/
      #   kase.outcome = "Closed: In Compliance"
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Closed/) || (event.Name =~ /Hearing/ && event.Status =~ /Closed/)
        if event.Name =~ /Closed/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Closed'
      #   kase.outcome = 'Closed'
      # elsif event.Name =~ /Closed New Owner/
      #   kase.outcome = 'Closed: New Owner'
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Judgment rescinded/) || (event.Name =~ /Hearing/ && event.Status =~ /Judgment rescinded/)
        if event.Name =~ /rescinded/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Rescinded'
        # kase.outcome = 'Judgment Rescinded'
      # elsif event.Name =~ /Closed/# || event.Name == 'Closed - Closed'
      #   kase.outcome = "Closed"
      # elsif event.Name =~ /Judgment rescinded/
      #   kase.outcome = 'Judgment Rescinded'
      end
      
      if j_status
        if j_status.length > 0
          Event.create(:name => 'Judgment', :case_number => kase.case_number, :dhash => {:notes => notes}, :status => j_status, :date => event.DateEvent)
        else
          # kase.outcome = 'Judgment'
          Event.find_or_create_by_case_number_and_name(:name => 'Judgment', :case_number => kase.case_number, :dhash => {:notes => notes, :type => event.Type}, :date => event.DateEvent)
          Event.create(:name => 'Hearing', :case_number => kase.case_number, :date => event.DateEvent, :dhash => {:notes => notes, :type => event.Type}) #unless Hearing.where("case_number = '#{kase.case_number}' and (hearing_date >= '#{j.date.beginning_of_day.to_formatted_s(:db)}' and hearing_date <= '#{j.date.end_of_day.to_formatted_s(:db)}')").exists?
        end
      end
    elsif event.class == Hashie::Mash && (event.Type =~ /Administrative Hearing/ || event.Name =~ /Administrative Hearing/)  && event.IsComplete =~ /false/ && kase.state == 'Open'
      last_notification = kase.last_notification
      last_hearing = kase.last_hearing
      h_date = DateTime.parse(event.EventDate)
      if kase.judgement.nil? && last_notification && h_date > last_notification.date && (last_hearing.nil? || ((last_hearing && h_date > last_hearing.date) && (last_notification > last_hearing.date)))         
        Event.create(:name => 'Hearing',:case_number => kase.case_number, :date => event.DateEvent, :status => 'Scheduled', :dhash => {:hearing_type => event.Type, :is_complete => false})
      end
    end
  end
  def parseInspection(case_number,inspection)
    if inspection.class == Hashie::Mash && inspection.IsComplete =~ /true/
      insp_date = DateTime.parse(inspection.InspectionDate)
      
      findings = {}
      if inspection.Findings && inspection.Findings.InspectionFinding != nil
        inspection.Findings.InspectionFinding.each do |finding|
          if finding.class == Hashie::Mash
            if finding.Finding && finding.Finding.length > 0
              findings[finding.ID] = finding.Label
            end
          end
        end
      end
      
      Event.create(:name => 'Inspection', :case_number => case_number, :date => insp_date, :dhash => {:comment => inspection.Comment, :spawn_id => inspection.ID, :findings => findings})
    end
  end
  def parseAction(kase,action)
    if action.class == Hashie::Mash && action.IsComplete =~ /true/
      if (action.Type =~ /Notice/ && action.Type =~ /Hearing/) || action.Type == 'Notice'
        Event.create(:name => 'Notification', :case_number => kase.case_number, :date => action.Date, :status => action.Type)
      elsif action.Type =~ /Notice/ && action.Type =~ /Reset/
        Event.create(:name => 'Reset', :case_number => kase.case_number, :date => action.Date, :status => action.Type)
      elsif action.Type =~ /Notice/ && action.Type =~ /Compliance/
        Event.find_or_create_by_case_number_and_name_and_status(:name => 'Judgment', :case_number => kase.case_number, :date => action.Date, :status => 'Closed', :dhash => {:notes => action.Type, :spawn_id => action.ID})
      elsif action.Type =~ /Judgment/ && (action.Type =~ /Posting/ || action.Type =~ /Recordation/ || action.Type =~ /Notice/)
        Event.find_or_create_by_case_number_and_name(:name => 'Judgment', :case_number => kase.case_number, :date => action.Date, :status => nil)
      elsif action.Type =~ /Administrative Hearing/
        unless action.Type =~ /Notice/
          Event.create(:name => 'Hearing',:case_number => kase.case_number, :date => action.Date, :status => action.Type)
        end
      end
    end
  end
  
  def parseStatus(kase,case_status,date)
    c_status = case_status.downcase
    if case_status =~ /omplaint/ && case_status =~ /eceived/
      Event.create(:name => 'Intake', :case_number => kase.case_number, :date => date, :status => case_status)
    else
      if c_status =~ /compliance/ || c_status =~  /dismiss/ || c_status =~  /closed/
        j_status = 'Closed'
      elsif c_status =~ /guilty/
        if c_status =~ /not guilty/
          j_status = 'Not Guilty'
        else
          j_status = 'Guilty'
        end
          # Event.find_or_create_case_number_and_name_and_status(:name => 'Judgment', :case_number => kase.case_number, :status => kase.outcome, :date => date, :dhash => {:notes => case_status})
      elsif case_status =~ /Judgment/ && (case_status =~ /Posting/ || case_status =~ /Notice/ || case_status =~ /Recordation/)
        j_status = ''
      elsif c_status =~ /judgment rescinded/
        j_status = 'Rescinded'
      end

      if j_status.length > 0
        Event.find_or_create_by_case_number_and_name_and_status(:name => 'Judgment',:case_number => kase.case_number, :status => j_status, :date => date, :dhash => {:notes => case_status})
      else
        Event.find_or_create_by_case_number_and_name(:name => 'Judgment',:case_number => kase.case_number, :status => j_status, :date => date, :dhash => {:notes => case_status})
      end
    end
  end

  def import_by_location(address,lama=nil)
    begin
      lama = LAMA.new({ :login => ENV['LAMA_EMAIL'], :pass => ENV['LAMA_PASSWORD']}) if lama.nil?
    
      incidents = incidents_by_location(address,lama)
                
      incidents.nil? ? incid_num = 0 :incid_num = incidents.length
      p "There are #{incid_num} incidents for #{address}"
      if incid_num >= 1000
        p "LAMA can only return 1000 incidents at once- please try a smaller date range"
        return
      end

      import_incidents_to_database(incidents, lama)
    rescue StandardError => ex
      puts "There was an error of type #{ex.class}, with a message of #{ex.message}"
      puts "Backtrace => #{ex.backtrace}"
    end
  end

  def incidents_by_location(location,lama)
    incidents = lama.incidents_by_location(location,lama)
    if incidents.class == Hashie::Mash
      incident = incidents
      incidents = []
      incidents << incident
    end
    incidents
  end
  def unsaved_incidents_by_location(location,lama)
    cases = []
    incidents = incidents_by_location(location,lama)
    return if incidents.nil?
    incidents.each do |incident|
      cases << incident unless Case.where(:case_number => incident.Number).exists?
    end
    cases
  end
  
  def import_unsaved_cases_by_location(address,lama=nil)
    begin
      lama = LAMA.new({ :login => ENV['LAMA_EMAIL'], :pass => ENV['LAMA_PASSWORD']}) if lama.nil?
    
      incidents = unsaved_incidents_by_location(address,lama)
                
      incidents.nil? ? incid_num = 0 :incid_num = incidents.length
      p "There are #{incid_num} incidents for #{address}"
      if incid_num >= 1000
        p "LAMA can only return 1000 incidents at once- please try a smaller date range"
        return
      end

      import_incidents_to_database(incidents, lama)
    rescue StandardError => ex
      puts "There was an error of type #{ex.class}, with a message of #{ex.message}"
      puts "Backtrace => #{ex.backtrace}"
    end
  end

  def get_incident_division_by_location(lama,location,case_number)
    begin
      incidents = incidents_by_location(location,lama)
      incidents.each do |incident|
          return incident.Division if incident.Number == case_number
      end
    rescue StandardError => ex
      puts "There was an error of type #{ex.class}, with a message of #{ex.message}"
      puts "Backtrace => #{ex.backtrace}"
    end
    nil
  end

  def parseJudgement(kase,judgement)
    if judgement.class == Hashie::Mash   
      j_status = judgement.Status.downcase if judgement.Status
      date = judgement.D_Court if judgement.D_Court
      id = judgement.ID if judgement.ID
      
      return if j_status =~ /pending/

      j = nil
      
      if j_status =~ /reset/
        Event.create(:name => 'Reset', :case_number => kase.case_number, :date => date, :status => judgement.Status)
        return
      elsif j_status =~ /dismiss/
        j = 'Dismissed'
      elsif j_status =~ /closed/
        j = 'Closed'
      elsif j_status =~ /guilty/
        if j_status =~ /not guilty/
          j = 'Not Guilty'
        else
          j = 'Guilty'
        end
      elsif j_status =~ /rescinded/
          j = 'Rescinded'
      end
            
      if j
        j_status = judgement.Status
        Event.create(:name => 'Judgment', :case_number => kase.case_number, :status => j, :date => date, :dhash => {:notes => j_status})
      end  
    end
  end

  def validateSchedHearings(kase,unsaved)
    #is scheduled hearing valid?


        # saved = Event.where(:name => 'Hearing', :case_number = kase.case_number, :status => 'Scheduled')
        last  = Event.where(:case_number => kase.case_number).last
        unsaved.save if unsaved.date > last.date && kase.state == 'Open' && !kase.judgement
        

        schedHearings = Event.where(:case_number => kase.case_number, :case_number => kase.case_number, :status => 'Scheduled')
        schedHearings.destroy_all if kase.isClosed || kase.judgement

        # Event.create(:name => 'Hearing', :case_number => kase.case_number, :date => date, :status => 'Scheduled')
        # h.destroy if h && !h.is_complete && kase.judgement && h != kase.last_status
  end
  # def remainingSpawns(kase,spawnHash)
  #   puts "Remaining SpawnHash => #{spawnHash.inspect}"
  #   spawnHash.each do |spawn_id,spawn|
  #     puts "spawn => #{spawn.inspect}"
  #     if 'Notification|Complaint|Reset' =~ /#{spawn[:step]}/
  #       Event.create(:name => spawn[:step], :case_number => kase.case_number, :date => spawn[:date], :status => spawn[:notes])
  #     end
  #   end
  #   spawnHash.clear
  # end

  def reloadCase(case_number, client=nil)
    client = LAMA.new({:login => ENV['LAMA_EMAIL'], :pass => ENV['LAMA_PASSWORD']}) unless client
    reloaded = nil
    kase = Case.where(:case_number => case_number).first
    if kase
      puts "destroying => #{case_number}"
      kase.events.destroy_all
      kase.destroy
    end        
    incident = client.incident(case_number)
    if incident && incident.Type == 'Public Nuisance and Blight' 
      import_incident_to_database(incident,client)
      reloaded = true if Case.where(:case_number => case_number).any?
    else
      reloaded = false
    end
  end
end
