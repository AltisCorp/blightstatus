# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130118012054) do

  create_table "addresses", :force => true do |t|
    t.integer  "geopin"
    t.integer  "address_id"
    t.integer  "street_id"
    t.string   "house_num"
    t.string   "street_name"
    t.string   "street_type"
    t.string   "address_long"
    t.string   "case_district"
    t.float    "x"
    t.float    "y"
    t.string   "status"
    t.datetime "created_at",                                                 :null => false
    t.datetime "updated_at",                                                 :null => false
    t.string   "parcel_id"
    t.boolean  "official"
    t.string   "street_full_name"
    t.string   "assessor_url"
    t.integer  "neighborhood_id"
    t.string   "latest_type"
    t.integer  "latest_id"
    t.integer  "double_id"
    t.spatial  "point",            :limit => {:srid=>-1, :type=>"geometry"}
  end

  add_index "addresses", ["address_long"], :name => "index_addresses_on_address_long"
  add_index "addresses", ["house_num", "street_name"], :name => "index_addresses_on_house_num_and_street_name"

  create_table "case_managers", :force => true do |t|
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "case_number"
    t.string   "name"
  end

  create_table "cases", :force => true do |t|
    t.string   "case_number"
    t.integer  "geopin"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "address_id"
    t.string   "state"
    t.integer  "status_id"
    t.string   "status_type"
    t.text     "dhash"
    t.hstore   "dstore"
    t.datetime "filed"
  end

  add_index "cases", ["address_id"], :name => "index_cases_on_address_id"
  add_index "cases", ["case_number"], :name => "index_cases_on_case_number"
  add_index "cases", ["dstore"], :name => "cases_gin_dstore"

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "events", :force => true do |t|
    t.string   "name"
    t.datetime "date"
    t.string   "status"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "case_number"
    t.text     "dhash"
    t.hstore   "dstore"
    t.string   "step"
  end

  add_index "events", ["dstore"], :name => "events_gin_dstore"

  create_table "inspection_findings", :force => true do |t|
    t.integer  "inspection_id"
    t.text     "finding"
    t.string   "label"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
  end

  create_table "inspectors", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "neighborhoods", :force => true do |t|
    t.string   "name"
    t.float    "x_min"
    t.float    "y_min"
    t.float    "x_max"
    t.float    "y_max"
    t.float    "area"
    t.datetime "created_at",                                           :null => false
    t.datetime "updated_at",                                           :null => false
    t.spatial  "the_geom",   :limit => {:srid=>-1, :type=>"geometry"}
  end

  create_table "pages", :force => true do |t|
    t.integer  "site_id"
    t.string   "slug"
    t.string   "title"
    t.string   "template"
    t.text     "body"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "parcels", :force => true do |t|
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "properties", :force => true do |t|
    t.string   "street"
    t.integer  "number"
    t.integer  "zip_code"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "searches", :force => true do |t|
    t.text     "term"
    t.string   "ip"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "streets", :force => true do |t|
    t.string   "prefix"
    t.string   "prefix_type"
    t.string   "name"
    t.string   "suffix"
    t.string   "suffix_type"
    t.string   "full_name"
    t.integer  "length_numberic"
    t.integer  "shape_len"
    t.datetime "created_at",                                                 :null => false
    t.datetime "updated_at",                                                 :null => false
    t.string   "prefix_direction"
    t.string   "suffix_direction"
    t.spatial  "the_geom",         :limit => {:srid=>-1, :type=>"geometry"}
  end

  create_table "subscriptions", :force => true do |t|
    t.integer  "address_id"
    t.integer  "user_id"
    t.string   "notes"
    t.datetime "created_at",                                              :null => false
    t.datetime "updated_at",                                              :null => false
    t.datetime "date_notified"
    t.spatial  "thegeom",       :limit => {:srid=>-1, :type=>"geometry"}
  end

  create_table "users", :force => true do |t|
    t.string   "email",                  :default => "",   :null => false
    t.string   "encrypted_password",     :default => "",   :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                               :null => false
    t.datetime "updated_at",                               :null => false
    t.boolean  "send_notifications",     :default => true
    t.string   "role"
  end

  add_index "users", ["email"], :name => "index_accounts_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_accounts_on_reset_password_token", :unique => true

end
