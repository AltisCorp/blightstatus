namespace :neworleans do
  desc "New Orleans: load addresses"
  task :fullsync do

    puts "*WARNING* This will take many many many hours to run."
    # load addresses
    shapefile = 'https://data.nola.gov/download/div8-5v7i/application/zip'
    Rake::Task['addresses:load'].invoke(shapefile)


    # load neighborhoods
    # shapefile = 'https://data.nola.gov/download/xy5r-5rjk/application/zip'
    # Rake::Task['neighborhoods:load'].invoke(shapefile)


    # load parcels
    # shapefile = 'https://data.nola.gov/download/xy5r-5rjk/application/zip'
    # Rake::Task['parcels:load'].invoke(shapefile)


    # load streets lines

  end

  desc "New Orleans: tasks that run daily"
  task :daily do

  end

  desc "New Orleans: tasks that run weekly"
  task :weekly do

  end


  desc "New Orleans: tasks that run monthly"
  task :monthly do

  end

end


