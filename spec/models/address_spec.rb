require 'spec_helper'
require 'rgeo'

describe Address do
  before(:each) do
    @address = FactoryGirl.create(:address)
  end

  it { should validate_uniqueness_of(:address_id) }
  #it { should validate_uniqueness_of(:parcel_id) }
  #it { should validate_uniqueness_of(:geopin) }

  describe "find_addresses_with_cases_by_street" do
   it "should return array of addreses that havee cases on a street" do
      c = FactoryGirl.create(:case, :address => @address)

      result = Address.find_addresses_with_cases_by_street("CHARBONNET")
      result.count.should > 0
    end
  end

  describe "#workflow_steps" do
    context "no associated workflow steps" do
      it "returns an empty array" do
       @address.workflow_steps.should eq([])
      end
    end

    context "associated workflow steps" do
      before do
        @demo = FactoryGirl.create(:demolition, :address => @address, :date_started => Time.now - 2.days )
        c = FactoryGirl.create(:case, :address => @address)
        @hearing = FactoryGirl.create(:hearing, :case => c, :hearing_date => Time.now - 1.day)
      end

      it "returns all steps" do
        @address.workflow_steps.should include(@demo)
        @address.workflow_steps.should include(@hearing)
      end
    end
  end

  describe "#most_recent_status" do
    context "no status found" do
      it "returns nil" do
        @address.most_recent_status.should eq(nil)
      end
    end

    context "associated workflow steps" do
      before do
        c = FactoryGirl.create(:case, :address => @address)
        @inspection = FactoryGirl.create(:inspection, :case => c)
        @demo = FactoryGirl.create(:demolition, :address => @address, :date_started => Time.now)
      end

      it "returns the last step from both cases and abatement" do
        @address.most_recent_status.should eq(@demo)
      end
    end
  end

  describe "#sorted cases" do
    context "no associated cases" do
      it "returns an empty array" do
        @address.sorted_cases.should eq []
      end
    end

    context "associated cases" do
      it "returns an array of all cases sorted by their last workflow step" do
        c1 = FactoryGirl.create(:case, :address => @address)
        inspection = FactoryGirl.create(:inspection, :case => c1, :inspection_date => Time.now)

        c2 = FactoryGirl.create(:case, :address => @address)
        inspection = FactoryGirl.create(:inspection, :case => c2, :inspection_date => Time.now)

        @address.sorted_cases.should eq([c1, c2])
      end
    end
  end

  describe "#cardinal" do
    context "address with a direction" do
      it "returns the cardinal direction" do
        @address.address_long = "1019 S CHARBONNET ST"
        @address.cardinal.should eq('S')

        @address.address_long = "1019 E CHARBONNET ST"
        @address.cardinal.should eq('E')
      end
    end
    context "address with no direction" do
      it "returns nil" do
        @address.cardinal.should be_nil
      end
    end
  end

  describe "#set_assessor_link" do
    it "sets the assessor url" do
      @address.update_attributes(:address_long => "520 N OLYMPIA ST", :street_name => "OLYMPIA", :house_num => "520", :street_type => "ST")
      @address.assessor_url.should be_nil

      @address.set_assessor_link
      @address.assessor_url.should eq("http://qpublic4.qpublic.net/la_orleans_display.php?KEY=520-NOLYMPIAST")
    end

    it "does not set the assessor url if an accurate page is not found" do
      @address.assessor_url.should be_nil

      @address.set_assessor_link
      @address.assessor_url.should be_nil
    end
  end

  describe "#most_recent_status_preview" do
    it "dispalys the most recent status class and time" do
      dt = DateTime.now
      FactoryGirl.create(:demolition, :address => @address, :date_started => dt)
      FactoryGirl.create(:maintenance, :address => @address, :date_completed => (DateTime.now - 2.days))
      FactoryGirl.create(:foreclosure, :address => @address, :sale_date => (DateTime.now - 3.days))
      c = FactoryGirl.create(:case, :address => @address)
      FactoryGirl.create(:hearing, :case => c, :hearing_date => (DateTime.now - 30.days))  
      
      @address.most_recent_status_preview.should == {:type => 'Demolition', :date => dt.strftime('%B %e, %Y')}
    end    
  end

  describe "#find_addresses_with_cases_by_cardinal_street" do
    it "display cases on a street with by cardinal_address" do
      a = FactoryGirl.create(:address, :address_long => '1 N CFA ST', :street_name => 'CFA')
      FactoryGirl.create(:case, :address => a)
      a = FactoryGirl.create(:address, :address_long => '2 N CFA ST', :street_name => 'CFA')
      FactoryGirl.create(:case, :address => a)
      a =FactoryGirl.create(:address, :address_long => '1 S CFA ST', :street_name => 'CFA')
      FactoryGirl.create(:case, :address => a)
      a = FactoryGirl.create(:address, :address_long => '2 E CFA ST', :street_name => 'CFA')
      FactoryGirl.create(:case, :address => a)
      result = Address.find_addresses_with_cases_by_cardinal_street('E','CFA')
      result.count.should < Address.find_addresses_with_cases_by_street('CFA').count
    end    
  end
  describe "#self.find_addresses_within_area(ne, sw)" do
    it "return # of cases at -90.04223467290467 29.975021724674335 should be 1" do
        FactoryGirl.create(:case, :address => @address)
        ne = {"lng" => -90.04223467290467, "lat" => 29.975021724674335}
        sw = {"lng" => -90.04223467290467, "lat" => 29.975021724674335}
        Address.find_addresses_with_cases_within_area(ne,sw).count.should eq(1)    
    end
  end
end
