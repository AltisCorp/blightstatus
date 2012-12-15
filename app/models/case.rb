class Case < ActiveRecord::Base
  serialize :dhash, Hash
  serialize :dstore, ActiveRecord::Coders::Hstore
  
  attr_protected :dstore
  
  before_save :update_dstore
  # after_initialize :filter_events

  belongs_to :address
  has_many :events, :foreign_key => :case_number, :primary_key => :case_number

  validates_presence_of :case_number
  validates_uniqueness_of :case_number
  
  def set_details
    self.dstore = @dhash
  end

  def ordered_events
    self.events.sort{|a,b| a.date <=> b.date}
  end

  def events_grouped_by_step
    events_hash = {}
    ordered_events.each do |event|
      events_hash[event.step.to_sym] = [] unless events_hash[event.step.to_sym]
      events_hash[event.step.to_sym] << event

    end
    events_hash
  end

  def events_cleansed
    steps = ordered_events
    reset = reset_step
    reset_found = false
    if reset
      detail = []
      steps = steps.reverse
      steps.each do |last|
        reset_found = true if last == reset
        next if reset_found && last.step != 'Inspection'
        detail.insert(0, last)
      end
      steps = detail
    end
    steps
  end

  def events_by_step(step)
    events_grouped_by_step[step.to_sym]# || []
  end

  def missing_event?(step)
    false
  end

  def reset_step
    reset = nil
    steps = events_by_step('ResearchPropertyRecord')
    reset = steps.last if steps
    reset
  end  

  def self.events_seq(flow)
    events_seq = {}
    events_seq[:NOLA_BLIGHT] = [:Inspection, :Notification, :Hearing, :Judgment, :Resolution]
    events_seq[flow.to_sym]
  end

  def data_error?
    Case.events_seq(:NOLA_BLIGHT).each do |step|
      return true if missing_event?(step)
    end
    false
  end

  def update_dstore
    self.dstore = self.dhash
  end

  def self.match_resolution(resolution)
    address_long = resolution.dhash[:address_long]
    if address_long
      address = AddressHelpers.find_address(address_long)
      address = address.first
      case_num = nil
    
      if address
        case_dhash = resolution.dhash
        case_dhash[:address_id ] = address.id
        resolution.update_attribute(:dhash, case_dhash)
        address.sorted_cases.each do |kase|
          resolution.date > kase.ordered_case_steps.last.date ? case_num = kase.case_number : break
        end
        resolution.update_attribute(:case_number, case_number) if case_num
      end
    end
  end
  
def status
  self.ordered_events.last.name
end

  
  def missing_event?(step)
    unless events_by_step(step)
      steps = Case.events_seq(:NOLA_BLIGHT)
      i = steps.index(step.to_sym)
      (i...(steps.size-1)).each do |j|
        return true if events_by_step(steps[j+1])
      end
    end
    false
  end


end
