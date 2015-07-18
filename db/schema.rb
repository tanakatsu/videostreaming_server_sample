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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160113141216) do

  create_table "transcoder_jobs", force: :cascade do |t|
    t.string   "job_id",     null: false
    t.string   "job_type",   null: false
    t.string   "state",      null: false
    t.integer  "video_id",   null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "videos", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "uuid",         default: "", null: false
    t.string   "content_type"
    t.integer  "width"
    t.integer  "height"
    t.integer  "duration"
  end

  add_index "videos", ["uuid"], name: "index_videos_on_uuid", unique: true

end
