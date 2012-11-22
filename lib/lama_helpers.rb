module LAMAHelpers
  def import_to_database(incidents, client=nil)
    l = client || LAMA.new({ :login => ENV['LAMA_EMAIL'], :pass => ENV['LAMA_PASSWORD']})

    incidents.each do |incident|
      begin
        case_number = incident.Number
        next unless case_number # need to find a better way to deal with this ... revisit post LAMA data cleanup
        location = incident.Location
        addresses = AddressHelpers.find_address(location)
        address = addresses.first if addresses
        division = get_incident_division_by_location(l,address.address_long,case_number) if address
        division = get_incident_division_by_location(l,location,case_number) if division.nil? || division.strip.length == 0
        division = incident.Division if division.nil? || division.strip.length == 0
        
        next unless division == 'CE'
        case_state = 'Open'
        case_state = 'Closed' if incident.IsClosed =~/true/
        kase = Case.find_or_create_by_case_number(:case_number => case_number, :state => case_state)
        
        puts "case => #{case_number}   status => #{incident.CurrentStatus}    date => #{incident.CurrentStatusDate}"
        orig_state = kase.state
        orig_outcome = kase.outcome
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
              parseEvent(kase,event)          
            end
          else
            parseEvent(kase,events)
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

        #Violations
        #TODO: add violations table and create front end for this 
        #Judgments - Closed
        case_status = incident_full.Description
        if (case_status =~ /Status:/ && case_status =~ /Status Date:/)
          case_status = case_status[((case_status =~ /Status:/) + "Status:".length) ... case_status =~ /Status Date:/].strip

          d = incident_full.Description
          d = d[d.index('Status Date:') .. -1].split(' ')
          d = d[2].split('/')
          d = DateTime.new(d[2].to_i,d[0].to_i,d[1].to_i)

          parseStatus(kase,case_status,d)
        end
        
        if kase.address.nil?
          if address
            kase.address = address
          end
        end
        if !kase.accela_steps.nil? || kase.state != orig_state || kase.outcome != orig_outcome
          invalidate_steps(kase)
          k = kase.save
        end
      rescue StandardError => ex
        puts "THERE WAS AN EXCEPTION OF TYPE #{ex.class}, which told us that #{ex.message}"
        puts "Backtrace => #{ex.backtrace}"
      end
    end
  end

  def parseEvent(kase,event)
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
        i = Event.create(:name => 'Inspection', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
      elsif event.Type =~ /Complaint Received/ || event.Name =~ /Complaint Received/
       Event.create(:name => 'Complaint', :case_number => kase.case_number, :date => event.DateEvent, :status => event.Status)
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
        kase.outcome = j_status
      elsif (event.Name =~ /Judgment/ && (event.Name =~ /Posting/ || event.Name =~ /Notice/ || event.Name =~ /Recordation/))
        j_status = ''
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Dismiss/) || (event.Name =~ /Hearing/ && (event.Status =~ /Dismiss/ || event.Status =~ /dismiss/))
        if event.Name =~ /Dismiss/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Closed'
        kase.outcome = 'Closed: Dismissed'
      elsif event.Name =~ /Dismiss/
        kase.outcome = 'Dismissed'
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Compliance/) || (event.Name =~ /Hearing/ && event.Status =~ /Compliance/)
        if event.Name =~ /Compliance/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Closed'
        kase.outcome = 'Closed: In Compliance'
      elsif event.Name =~ /Compliance/
        kase.outcome = "Closed: In Compliance"
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Closed/) || (event.Name =~ /Hearing/ && event.Status =~ /Closed/)
        if event.Name =~ /Closed/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Closed'
        kase.outcome = 'Closed'
      elsif event.Name =~ /Closed New Owner/
        kase.outcome = 'Closed: New Owner'
      elsif (event.Name =~ /Hearing/ && event.Name =~ /Judgment rescinded/) || (event.Name =~ /Hearing/ && event.Status =~ /Judgment rescinded/)
        if event.Name =~ /rescinded/
          notes = event.Name.strip
        else
          notes = event.Status.strip
        end
        j_status = 'Judgment Rescinded'
        kase.outcome = j_status
      elsif event.Name =~ /Closed/# || event.Name == 'Closed - Closed'
        kase.outcome = "Closed"
      elsif event.Name =~ /Judgment rescinded/
        kase.outcome = 'Judgment Rescinded'
      end
      
      if j_status
        if j_status.length > 0
          # Event.create(:name => 'Hearing', :case_number => kase.case_number, :date => event.DateEvent, :hearing_status => j_status)

          Event.create(:name => 'Judgment', :case_number => kase.case_number, :notes => notes, :status => j_status, :date => event.DateEvent)
          
          kase.outcome = j_status
        else
          kase.outcome = 'Judgment'
          Event.find_or_create_by_case_number_and_date(:name => 'Judgment',:case_number => kase.case_number, :notes => notes, :date => event.DateEvent)
        end
      end
    end
  end
  def parseInspection(case_number,inspection)
    if inspection.class == Hashie::Mash && inspection.IsComplete =~ /true/
      #i = Event.find_or_create_by_name_and_case_number_and_date(:name => 'Inspection', :case_number => case_number, :date => inspection.InspectionDate, :details => {:comment => inspection.Comment,:findings => {}})
      insp_date = DateTime.parse(inspection.InspectionDate)
      i = Event.where("name = ? AND case_number = ? and date = ?", 'Inspection', case_number, insp_date).first
      i = Event.create(:name => 'Inspection', :case_number => case_number, :date => insp_date, :details => {:comment => inspection.Comment,:findings => {}}) unless i
      
      if inspection.Findings != nil && inspection.Findings.InspectionFinding != nil
        inspection.Findings.InspectionFinding.each do |finding|
          if finding.class == Hashie::Mash
            if finding.Finding && finding.Finding.length > 0
              i.details[:findings][finding.ID] = finding.Finding
            end
          end
        end
      end
      i.save if i.details[:findings.to_s].any?
    end
  end
  def parseAction(kase,action)
    if action.class == Hashie::Mash && action.IsComplete =~ /true/
      if (action.Type =~ /Notice/ && action.Type =~ /Hearing/) || action.Type == 'Notice'
        Event.create(:name => 'Notification', :case_number => kase.case_number, :date => action.Date, :status => action.Type)
      elsif action.Type =~ /Notice/ && action.Type =~ /Reset/
        Event.create(:name => Reset, :case_number => kase.case_number, :date => action.Date, :status => action.Type)
      elsif action.Type =~ /Notice/ && action.Type =~ /Compliance/
        kase.outcome = 'Closed: In Compliance'
      elsif action.Type =~ /Judgment/ && (action.Type =~ /Posting/ || action.Type =~ /Recordation/ || action.Type =~ /Notice/)
        Event.create(:name => 'Judgment', :case_number => kase.case_number, :date => action.Date, :status => nil).delete_all
      elsif action.Type =~ /Administrative Hearing/
        unless action.Type =~ /Notice/
          Event.create(:name => 'Hearing',:case_number => kase.case_number, :date => action.Date, :status => action.Type)
        end
      end
    end
  end
  def parseStatus(kase,case_status,date)
    if case_status =~ /Compliance/ 
      kase.outcome = "Closed: In Compliance"
    elsif case_status =~ /Dismiss/ || case_status =~ /dismiss/
      kase.outcome = 'Closed: Dismissed'
    elsif case_status =~ /Closed/ 
      kase.outcome = 'Closed'
    elsif case_status =~ /Guilty/
      if case_status =~ /Not Guilty/
        kase.outcome = 'Not Guilty'
      else
        kase.outcome = 'Guilty'
      end
        Event.create(:name => 'Judgment', :case_number => kase.case_number, :status => kase.outcome, :date => date, :status => case_status)
    elsif case_status =~ /Judgment/ && (case_status =~ /Posting/ || case_status =~ /Notice/ || case_status =~ /Recordation/)
      Event.create(:name => 'Judgment', :case_number => kase.case_number, :date => date, :status => case_status)
      unless j.status
        kase.outcome = 'Judgment' if kase.outcome != 'Judgment'
      end
    elsif case_status =~ /Judgment rescinded/
      kase.outcome = 'Judgment Rescinded' 
    elsif case_status =~ /omplaint/ && case_status =~ /eceived/
      Event.create(:name => 'Intake', :case_number => kase.case_number, :date => date, :status => case_status)
    end
  end

  # def invalidate_steps(kase)
  #   latest = kase.most_recent_status
    
  #   j = Judgement.where(:case_number => kase.case_number, :status => nil).last
  #   if  j && latest && j != latest && (j.status.nil? || j.status.length == 0)
  #     kase.adjudication_steps.each do |s|
  #       s.destroy if s.date < j.date
  #     end
  #     j.destroy
  #   end

  #   j = kase.judgement
  #   if  j && latest && j != latest && !j.status.nil? && (j.status =~ /Rescinded/).nil?
  #     kase.adjudication_steps.each do |s|
  #       if s.date > j.date
  #         s.destroy
  #       end
  #     end
  #   end
  #   kase.save
  # end
  def import_by_location(address,lama=nil)
    begin
      lama = LAMA.new({ :login => ENV['LAMA_EMAIL'], :pass => ENV['LAMA_PASSWORD']}) if lama.nil?
    
      incidents = incidents_by_location(address,lama)
      #import_to_database(incidents, lama)

      incid_num = incidents.length
      p "There are #{incid_num} incidents for #{address}"
      if incid_num >= 1000
        p "LAMA can only return 1000 incidents at once- please try a smaller date range"
        return
      end

      import_to_database(incidents, lama)
    rescue StandardError => ex
      puts "There was an error of type #{ex.class}, with a message of #{ex.message}"
    end
  end

  def incidents_by_location(location,lama)
    lama.incidents_by_location(location,lama)
  end

  def get_incident_division_by_location(lama,location,case_number)
    division = nil
    begin
      incidents = lama.incidents_by_location(location)
      if incidents.class == Hashie::Mash
        division = incidents.Division if incidents.Number == case_number
      elsif incidents.class == Array
        incidents.each do |incident|
          division = incident.Division if incident.Number == case_number
        end
      end
    rescue StandardError => ex
      puts "There was an error of type #{ex.class}, with a message of #{ex.message}"
    end
    division
  end

  def parseJudgement(kase,judgement)
    if judgement.class == Hashie::Mash
      j_status = judgement.Status.downcase unless judgement.Status.nil?
      date = judgement.D_Court unless judgement.D_Court.nil?
    
      j = nil
      return if j_status =~ /pending/
      if j_status =~ /reset/
        Event.create(:name => 'Reset', :case_number => kase.case_number, :date => date, :status => judgement.Status)
        puts "reset imported from judgements"
        kase.outcome = "Reset"
      elsif j_status =~ /dismiss/
        j = 'Dismissed'
        kase.outcome = "Closed: Dismissed"
      elsif j_status =~ /closed/
        j = 'Closed'
        kase.outcome = "Closed"
      elsif j_status =~ /guilty/
        if j_status =~ /not guilty/
          j = 'Not Guilty'
        else
          j = 'Guilty'
        end
        kase.outcome = j        
      elsif j_status =~ /rescinded/
          j = 'Rescinded'
          kase.outcome = 'Judgment Rescinded' 
      end
      j_status = judgement.Status unless judgement.Status.nil?  
      Event.create(:name => 'Judgment', :case_number => kase.case_number, :status => j, :date => date, :status => j_status) if j
    end
  end
end
