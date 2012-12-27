namespace :new_orleans do


  desc "New Orleans: load addresses"
  task :load_addresses do

    # load addresses
    address_shapefile_url = 'https://data.nola.gov/api/file_data/Gn9aLqlGx_9jR-DzakSNiXu3Y5iO1YvL5O8XPgIj6no?filename=NOLA_Addresses_20121214.zip'
    Rake::Task["addresses:load shapefile=#{address_shapefile_url}"].invoke

    # load neighborhoods

  end

  desc "New Orleans: tasks that run daily"
  task :scheduled_daily do

  end

  desc "New Orleans: tasks that run weekly"
  task :scheduled_weekly do

  end


  desc "New Orleans: tasks that run monthly"
  task :scheduled_monthly do

  end



end
