namespace :neworleans do


  desc "New Orleans: load addresses"
  task :geodata do

    # load addresses
    shapefile = 'https://data.nola.gov/api/file_data/Gn9aLqlGx_9jR-DzakSNiXu3Y5iO1YvL5O8XPgIj6no?filename=NOLA_Addresses_20121214.zip'
    # shapefile = '/Users/eddie/Desktop/grp36005.zip'
    put shapefile
    Rake::Task["addresses:load[#{shapefile}]"].invoke

    # load neighborhoods


    # load streets lines

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
