FactoryGirl.define do
  factory :address do
    # address_id        { 424704 }
    # parcel_id         { 1 + rand(20000) }
    # geopin            { 1 + rand(30000) }
    address_long      { "1019 CHARBONNET ST" }
    street_type       { "St" }
  end

  factory :case do
    case_number       { "CEHB " + rand(1000).to_s()}
  end

  factory :demolition do
  end

  factory :foreclosure do
  end

  factory :hearing do
    hearing_date      { Time.now }
  end

  factory :inspection do
    inspection_type   { "Violation Posted No WIP" }
  end

  factory :notification do
    #are there any fields to require?
  end
  
  
end
