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
        address = addresses.first# if addresses
        division = get_incident_division_by_location(l,address.address_long,case_number) if address
        division = get_incident_division_by_location(l,location,case_number) if division.nil? || division.strip.length == 0
        division = incident.Division if division.nil? || division.strip.length == 0
        return unless division == 'CE'
        
        case_state = 'Open'
        case_state = 'Closed' if incident.IsClosed =~/true/
        filed = incident.DateFiled
        kase = Case.find_or_create_by_case_number(:case_number => case_number, :state => case_state, :filed => filed, :address => address)
        
        puts "case => #{case_number}   status => #{incident.CurrentStatus}    date => #{incident.CurrentStatusDate}"
        # orig_outcome = kase.outcome
        incident_full = l.incident(case_number)
        
        spawn_hash = Hash.new
        #Go through all data points and pull out relevant things here
        #Inspections
        inspections = incident_full.Inspections
        if inspections
          if inspections.class == Hashie::Mash
            inspections = inspections.Inspection
            if inspections.class == Array
              inspections.each do |inspection|
                i = parseInspection(case_number,inspection)
                spawn_hash[i[:dhash][:spawn_id]] = i if i
              end
            else
              i = parseInspection(case_number,inspections)
              spawn_hash[i[:dhash][:spawn_id]] = i if i
            end
          end
        end

        judgements = incident_full.Judgments
        if judgements
          if judgements.class == Hashie::Mash
            judgements = judgements.Judgment
            if judgements.class == Array
              judgements.each do |judgement|
                j = parseJudgement(kase,judgement)
                spawn_hash[j[:dhash][:spawn_id]] = j if j
              end
            else
              j = parseJudgement(kase,judgements)
              spawn_hash[j[:dhash][:spawn_id]] = j if j
            end
          end
        end


        #Actions
        actions = []
        if incident_full.Actions && incident_full.Actions.CodeAction
          actions = incident_full.Actions.CodeAction
          if actions
            if actions.class == Array
              actions.each do |action|
                a = parseAction(kase, action)
                spawn_hash[a[:dhash][:spawn_id]] = a if a
              end
            else
              a = parseAction(kase, actions)
              spawn_hash[a[:dhash][:spawn_id]] = a if a
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
              parseEvent(kase,event, spawn_hash)          
            end
          else
            parseEvent(kase,events, spawn_hash)
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

  def parseEvent(kase,event,spawn_hash)
    case_number = kase.case_number
    if event.class == Hashie::Mash && event.IsComplete =~ /true/
      # j_status = nil
      if ((event.Type =~ /Notice/ || event.Name =~ /Notice/) && (event.Type =~ /Hearing/ || event.Name =~ /Hearing/)) || (event.Type == 'Notice' || event.Name == 'Notice')
        if spawn_hash[event.ID]
          spawn = spawn_hash.delete(event.ID)
          Event.create(:name => event.Name, :step => 'Notification', :case_number => kase.case_number, :date => spawn[:date], :status => event.Status, :dhash => spawn[:dhash])
        else
          Event.create(:name => event.Name, :step => 'Notification', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
        end
      elsif event.Type =~ /Administrative Hearing/
        if spawn_hash[event.ID]
          spawn = spawn_hash.delete(event.ID)
          # unless Event.where("step = 'Hearing' and case_number = '#{kase.case_number}' and (date >= '#{Date.parse(event.DateEvent).beginning_of_day.to_formatted_s(:db)}' and date <= '#{Date.parse(event.DateEvent).end_of_day.to_formatted_s(:db)}')").exists?
              Event.create(:name => event.Name, :step => 'Hearing', :case_number => kase.case_number, :date => spawn[:date], :status => event.Status, :dhash => spawn[:dhash])
          # end
        else
          # unless Event.where("step = 'Hearing' and case_number = '#{kase.case_number}' and (date >= '#{Date.parse(event.DateEvent).beginning_of_day.to_formatted_s(:db)}' and date <= '#{Date.parse(event.DateEvent).end_of_day.to_formatted_s(:db)}')").exists?
              Event.create(:name => event.Name, :step => 'Hearing', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
          # end
        end
      elsif ((event.Type =~ /Notice/ || event.Name =~ /Notice/) && (event.Type =~ /Reset/ || event.Name =~ /Reset/))
        if spawn_hash[event.ID]
          spawn = spawn_hash.delete(event.ID)
          Event.create(:name => event.Name, :step => 'Reset', :case_number => kase.case_number, :date => spawn[:date], :status => event.Status, :dhash => spawn[:dhash])
        else
          Event.create(:name => event.Name, :step => 'Reset', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
        end
      elsif event.Type =~ /Input Hearing Results/
       if event.Items != nil and event.IncidEventItem != nil
         event.IncidEventItem.each do |item|
           if item.class == Hashie::Mash
             if (item.Title =~ /Reset Notice/ || item.Title =~ /Reset Hearing/) && item.IsComplete == "true"
              if spawn_hash[event.ID]
                spawn = spawn_hash.delete(event.ID)
                Event.create(:name => event.Name, :step => 'Reset',:case_number => kase.case_number, :date => spawn[:date], :status => event.Status, :dhash => spawn[:dhash])
              else
                Event.create(:name => event.Name, :step => 'Reset',:case_number => kase.case_number, :date => item.DateCompleted, :status => event.Status)
              end
             end
           end
         end
       end
      elsif event.Type =~ /Inspection/ || event.Name =~ /Inspection/ || event.Type =~ /Reinspection/ || event.Name =~ /Reinspection/
        unless Event.where("name = '#{event.Name}' and case_number = '#{kase.case_number}' and (date >= '#{Date.parse(event.DateEvent).beginning_of_day.to_formatted_s(:db)}' and date <= '#{Date.parse(event.DateEvent).end_of_day.to_formatted_s(:db)}')").exists?
          if spawn_hash[event.ID]
            spawn = spawn_hash.delete(event.ID)
            Event.create(:name => event.Name, :step => 'Inspection', :case_number => kase.case_number, :date => spawn[:date], :status => event.Status, :dhash => spawn[:dhash])
          else
            Event.create(:name => event.Name, :step => 'Inspection', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
          end
        end
      elsif event.Type =~ /Complaint Received/ || event.Name =~ /Complaint Received/
        if spawn_hash[event.ID]
          spawn = spawn_hash.delete(event.ID)
          Event.create(:name => event.Name, :step => 'Intake', :case_number => kase.case_number, :date => spawn[:date], :status => event.Status, :dhash => spawn[:dhash])
        else
          Event.create(:name => event.Name, :step => 'Intake', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
        end
      elsif event.Type =~ /Research Property Record/
        if spawn_hash[event.ID]
          spawn = spawn_hash.delete(event.ID)
          Event.create(:name => event.Name, :step => 'ResearchPropertyRecord', :date => spawn[:date], :status => event.Status, :case_number => kase.case_number, :dhash => spawn[:dhash])  
        else
          Event.create(:name => event.Name, :step => 'ResearchPropertyRecord', :date => event.DateEvent, :status => event.Status, :case_number => kase.case_number)  
        end
      elsif (event.Name =~ /Judgment/ && (event.Name =~ /Posting/ || event.Name =~ /Notice/ || event.Name =~ /Recordation/))
        if spawn_hash[event.ID]
          spawn = spawn_hash.delete(event.ID)
          Event.create(:name => event.Name, :step => 'Judgment', :case_number => kase.case_number, :status => event.Status, :dhash => {:type => event.Type}, :date => spawn[:dhash])
        else
          Event.create(:name => event.Name, :step => 'Judgment', :case_number => kase.case_number, :status => event.Status, :dhash => {:type => event.Type}, :date => event.DateEvent)
        end
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
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Dismiss/) || (event.Name =~ /Hearing/ && (event.Status =~ /Dismiss/ || event.Status =~ /dismiss/))
        if event.Name =~ /Dismiss/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Closed'
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Compliance/) || (event.Name =~ /Hearing/ && event.Status =~ /Compliance/)
        if event.Name =~ /Compliance/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Closed'
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Closed/) || (event.Name =~ /Hearing/ && event.Status =~ /Closed/)
        if event.Name =~ /Closed/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Closed'
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Judgment rescinded/) || (event.Name =~ /Hearing/ && event.Status =~ /Judgment rescinded/)
        if event.Name =~ /rescinded/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Rescinded'
      end
      
      if j_status
        if spawn_hash[event.ID]
          spawn = spawn_hash.delete(event.ID)
          unless Event.where("name = '#{event.Name}' and case_number = '#{kase.case_number}' and (date >= '#{Date.parse(event.DateEvent).beginning_of_day.to_formatted_s(:db)}' and date <= '#{Date.parse(event.DateEvent).end_of_day.to_formatted_s(:db)}')").exists?
            Event.create(:name => event.Name, :step => 'Hearing', :case_number => kase.case_number, :dhash => spawn[:dhash], :status => j_status, :date => spawn[:date])
          end
        else
          unless Event.where("name = '#{event.Name}' and case_number = '#{kase.case_number}' and (date >= '#{Date.parse(event.DateEvent).beginning_of_day.to_formatted_s(:db)}' and date <= '#{Date.parse(event.DateEvent).end_of_day.to_formatted_s(:db)}')").exists?
            Event.create(:name => event.Name, :step => 'Hearing', :case_number => kase.case_number, :dhash => {:notes => notes}, :status => j_status, :date => event.DateEvent)
          end
        end
      end
    # elsif event.class == Hashie::Mash && (event.Type =~ /Administrative Hearing/ || event.Name =~ /Administrative Hearing/)  && event.IsComplete =~ /false/ && kase.state == 'Open'
    #   last_notification = kase.last_notification
    #   last_hearing = kase.last_hearing
    #   h_date = DateTime.parse(event.EventDate)
    #   if kase.judgement.nil? && last_notification && h_date > last_notification.date && (last_hearing.nil? || ((last_hearing && h_date > last_hearing.date) && (last_notification > last_hearing.date)))         
    #     Event.create(:name => event.Name, :step => 'Hearing',:case_number => kase.case_number, :date => event.DateEvent, :status => 'Scheduled', :dhash => {:hearing_type => event.Type, :is_complete => false})
    #   end
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
      # Event.create(:name => 'Inspection', :step => 'Inspection', :case_number => case_number, :date => insp_date, :dhash => {:comment => inspection.Comment, :spawn_id => inspection.ID, :findings => findings})
      {:name => 'Inspection', :step => 'Inspection', :case_number => case_number, :date => insp_date, :dhash => {:comment => inspection.Comment, :spawn_id => inspection.ID, :findings => findings}}
    end
  end
  def parseAction(kase,action)
    action = nil
    if action.class == Hashie::Mash && action.IsComplete =~ /true/
      if (action.Type =~ /Notice/ && action.Type =~ /Hearing/) || action.Type == 'Notice'
        action = {:name => action.Type, :step => 'Notification', :case_number => kase.case_number, :date => action.Date, :status => action.Type, :dhash => {}}
      elsif action.Type =~ /Notice/ && action.Type =~ /Reset/
        action = {:name => action.Type, :step => 'Reset', :case_number => kase.case_number, :date => action.Date, :status => action.Type, :dhash => {}}
      elsif action.Type =~ /Notice/ && action.Type =~ /Compliance/
        action = {:name => action.Type, :step => 'Judgment', :case_number => kase.case_number, :date => action.Date, :status => 'Closed', :dhash => {:notes => action.Type, :spawn_id => action.ID}}
      elsif action.Type =~ /Judgment/ && (action.Type =~ /Posting/ || action.Type =~ /Recordation/ || action.Type =~ /Notice/)
        action = {:name => action.Type, :step => 'Judgment', :case_number => kase.case_number, :date => action.Date, :status => nil, :dhash => {}}
      elsif action.Type =~ /Administrative Hearing/
        unless action.Type =~ /Notice/
          action  = {:name => action.Type, :step => 'Hearing',:case_number => kase.case_number, :date => action.Date, :status => action.Type, :dhash => {}}
        end
      end
    end
    action
  end
  
  def parseStatus(kase,case_status,date)
    c_status = case_status.downcase
    if case_status =~ /omplaint/ && case_status =~ /eceived/
      Event.create(:name => event.Name, :step => 'Intake', :case_number => kase.case_number, :date => date, :status => case_status)
    else
      if c_status =~ /compliance/ || c_status =~  /dismiss/ || c_status =~  /closed/
        j_status = 'Closed'
      elsif c_status =~ /guilty/
        if c_status =~ /not guilty/
          j_status = 'Not Guilty'
        else
          j_status = 'Guilty'
        end
          # Event.find_or_create_case_number_and_name_and_status(:name => event.Name, :step => 'Judgment', :case_number => kase.case_number, :status => kase.outcome, :date => date, :dhash => {:notes => case_status})
      elsif case_status =~ /Judgment/ && (case_status =~ /Posting/ || case_status =~ /Notice/ || case_status =~ /Recordation/)
        j_status = ''
      elsif c_status =~ /judgment rescinded/
        j_status = 'Rescinded'
      end

      if j_status.length > 0
        Event.find_or_create_by_case_number_and_name_and_status(:name => event.Name, :step => 'Judgment',:case_number => kase.case_number, :status => j_status, :date => date, :dhash => {:notes => case_status})
      else
        Event.find_or_create_by_case_number_and_name(:name => event.Name, :step => 'Judgment',:case_number => kase.case_number, :status => j_status, :date => date, :dhash => {:notes => case_status})
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
        # Event.create(:name => event.Name, :step => 'Reset', :case_number => kase.case_number, :date => date, :status => judgement.Status)
        return {:name => event.Name, :step => 'Reset', :case_number => kase.case_number, :date => date, :status => judgement.Status, :dhash => {:spawn_id => id}}
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
        # Event.create(:name => 'Judgment', :step => 'Hearing', :case_number => kase.case_number, :status => j, :date => date, :dhash => {:notes => j_status, :id => id})
        return {:name => 'Judgment', :step => 'Hearing', :case_number => kase.case_number, :status => j, :date => date, :dhash => {:notes => j_status, :spawn_id => id}}
      end  
    end
    return nil
  end

  # def validateSchedHearings(kase,unsaved)
  #       last  = Event.where(:case_number => kase.case_number).last
  #       unsaved.save if unsaved.date > last.date && kase.state == 'Open' && !kase.judgement
        

  #       schedHearings = Event.where(:case_number => kase.case_number, :case_number => kase.case_number, :status => 'Scheduled')
  #       schedHearings.destroy_all if kase.isClosed || kase.judgement
  # end
  # def remainingSpawns(kase,spawnHash)
  #   puts "Remaining SpawnHash => #{spawnHash.inspect}"
  #   spawnHash.each do |spawn_id,spawn|
  #     puts "spawn => #{spawn.inspect}"
  #     if spawn[:step] == Judgement.to_s
  #       unless Judgement.where("case_number = '#{kase.case_number}' and (judgement_date >= '#{DateTime.parse(spawn[:date]).beginning_of_day.to_formatted_s(:db)}' and judgement_date <= '#{DateTime.parse(spawn[:date]).end_of_day.to_formatted_s(:db)}')").exists?
  #         Hearing.create(:case_number => kase.case_number, :hearing_date => spawn[:date], :hearing_status => spawn[:status], :hearing_type => spawn[:notes], :is_complete => true) unless Hearing.where("case_number = '#{kase.case_number}' and (hearing_date >= '#{DateTime.parse(spawn[:date]).beginning_of_day.to_formatted_s(:db)}' and hearing_date <= '#{DateTime.parse(spawn[:date]).end_of_day.to_formatted_s(:db)}')").exists?
  #         Judgement.create(:case_number => kase.case_number, :notes => spawn[:notes], :judgement_date => spawn[:date], :status => spawn[:status])# unless Judgement.where("case_number = '#{kase.case_number}' and (judgement_date >= '#{DateTime.parse(spawn[:date]).beginning_of_day.to_formatted_s(:db)}' and judgement_date <= '#{DateTime.parse(spawn[:date]).end_of_day.to_formatted_s(:db)}')").exists?
  #       end
  #     elsif spawn[:step] == Inspection.to_s
  #       Inspection.create(:case_number => kase.case_number, :inspection_date => spawn[:date], :notes => spawn[:notes]) unless Inspection.where("case_number = '#{kase.case_number}' and (inspection_date >= '#{DateTime.parse(spawn[:date]).beginning_of_day.to_formatted_s(:db)}' and inspection_date <= '#{DateTime.parse(spawn[:date]).end_of_day.to_formatted_s(:db)}')").exists?
  #     elsif spawn[:step] == Notification.to_s
  #       Notification.create(:case_number => kase.case_number, :notified => spawn[:date], :notification_type => spawn[:notes]) unless Notification.where("case_number = '#{kase.case_number}' and (notified >= '#{DateTime.parse(spawn[:date]).beginning_of_day.to_formatted_s(:db)}' and notified <= '#{DateTime.parse(spawn[:date]).end_of_day.to_formatted_s(:db)}')").exists?
  #     elsif spawn[:step] == Complaint.to_s
  #       Complaint.create(:case_number => kase.case_number, :date_received => spawn[:date], :status => spawn[:notes]) unless Complaint.where("case_number = '#{kase.case_number}' and (date_received >= '#{DateTime.parse(spawn[:date]).beginning_of_day.to_formatted_s(:db)}' and date_received <= '#{DateTime.parse(spawn[:date]).end_of_day.to_formatted_s(:db)}')").exists?
  #     elsif spawn[:step] == Reset.to_s
  #       Reset.create(:case_number => kase.case_number, :reset_date => spawn[:date]) unless Reset.where("case_number = '#{kase.case_number}' and (reset_date >= '#{DateTime.parse(spawn[:date]).beginning_of_day.to_formatted_s(:db)}' and reset_date <= '#{DateTime.parse(spawn[:date]).end_of_day.to_formatted_s(:db)}')").exists?
  #     elsif spawn[:step] == 'Research Property Record'
  #       Case.find(kase.id).ordered_case_steps.each do |step|
  #         step.date <= DateTime.parse(spawn[:date]) ? (step.destroy unless step.class == Inspection) : break
  #       end
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
