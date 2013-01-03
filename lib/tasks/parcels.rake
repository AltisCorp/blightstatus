namespace :parcels do

  desc "Load addresses into database"
  task :load, [:shapefile] => :environment  do |t, args|
    puts args.shapefile
    parcels = get_geojson_from_shapefile(args.shapefile)
    p "File contains #{p parcels['features'].count} records"

    new_addresses_count = addresses_count = 0

    unless parcels['features'].empty?
      parcels['features'].each do |n|
        record = n['properties']
        geometry = n['geometry']
        st = Street.create( :prefix_direction => record["PREFIX_DIR"], :prefix_type => record["PREFIX_TYP"], :name => record["ST_NAME"], :suffix_direction => record["SUFFIX_DIR"], :suffix_type => record["SUFFIX_TYP"], :full_name => record["NAME"], :shape_len => record["SHAPE_LEN"], :the_geom => geometry)
        st.save
      end
    end
  end

end
