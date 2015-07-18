class CreateTranscoderJobs < ActiveRecord::Migration
  def change
    create_table :transcoder_jobs do |t|
      t.string :job_id, null: false
      t.string :job_type, null: false
      t.string :state, null: false
      t.integer :video_id, null: false

      t.timestamps null: false
    end
  end
end
