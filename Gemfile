source 'https://rubygems.org'
ruby '1.9.3', engine: 'jruby', engine_version: '1.7.0'

gem 'rails', '3.2.9'


# ENABLE WHEN USING JRUBY - DISABLE BELOW
gem 'jdbc-postgres'
gem 'activerecord-postgis-adapter'
gem 'activerecord-jdbc-adapter'
gem 'activerecord-jdbcpostgresql-adapter'
gem 'puma'

# ENABLE WHEN USING MRI RUBY - DISABLE ABOVE
# gem 'pg' 
# gem 'activerecord-postgis-adapter'
# gem 'thin'


# Storage

gem 'foreigner'
gem 'aws-s3'
gem 'roo' #excel parser
gem 'docsplit'
gem 'rubyXL'
gem 'devise'
gem 'devise-async'

gem 'lama', :git => 'https://github.com/gangleton/lama.git'
gem 'savon'
gem 'httpclient', "~> 2.3.0"
# gem 'mechanize'

gem 'delayed_job_active_record'

# GIS 
gem 'rgeo'
gem 'rgeo-geojson'
gem 'rgeo-shapefile'

# Templates
gem 'haml'
gem 'jquery-rails'
gem 'rails3-jquery-autocomplete'
gem 'kaminari'


gem 'newrelic_rpm', '3.5.3.25'

# gem 'debugger', '1.2.2'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer'

  gem 'uglifier', '>= 1.0.3'
end


# Testing
group :test, :development do
  gem 'test-unit'
	gem 'rspec-rails', '>= 2.9.0' 
	gem 'shoulda'

	gem 'capybara'
	
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
