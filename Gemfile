source 'https://rubygems.org'

gem 'rails', '~> 3.2'
gem 'bundler', '~> 1.2' 


platforms :jruby do
  ruby '1.9.3', engine: 'jruby', engine_version: '1.7.2'
  gem 'jruby-openssl'
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'activerecord-postgis-adapter'
  gem 'puma'
end


platforms :ruby do
  ruby '1.9.3'
  gem 'pg' 
  gem 'activerecord-postgis-adapter'
  gem 'thin'
end



# Storage
gem 'foreigner'
gem 'aws-s3'
gem 'roo' #excel parser
gem 'docsplit'
gem 'rubyXL'
gem 'devise'
gem 'devise-async'
gem "friendly_id", "~> 4.0.9" # Note: You MUST use 4.0.9 or greater for Rails 3.2.10+

# Network
gem 'savon'
gem 'httpclient', "~> 2.3"
gem 'lama', :git => 'https://github.com/gangleton/lama.git'
gem 'redirect_follower'
gem "rest-client", :git => 'git://github.com/rest-client/rest-client.git'
# gem 'mechanize'

gem 'delayed_job_active_record'
gem 'json-schema'

# GIS 
gem 'rgeo'
gem 'rgeo-geojson'
gem 'rgeo-shapefile'

# Templates
gem 'haml'
gem 'jquery-rails'
gem 'rails3-jquery-autocomplete'
gem 'kaminari'


gem 'newrelic_rpm', '~> 3.5'

# gem 'debugger', '~> 1.2'

gem 'activerecord-postgres-hstore', git: 'git://github.com/engageis/activerecord-postgres-hstore.git'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2'
  gem 'coffee-rails', '~> 3.2'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer'

  gem 'uglifier', '~> 1.3'
end


# Testing
group :test, :development do
  gem 'test-unit'
	gem 'rspec-rails', '~> 2.12' 
	gem 'shoulda'

	gem 'capybara', '~> 2.0'
	
	gem 'factory_girl_rails'
  gem 'faker'

  gem 'simplecov'
end

# group :development do
#   gem 'awesome_print'
#   gem "better_errors"
#   gem "binding_of_caller"
# end

group :test do
  gem 'rake'
end

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the app server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'
