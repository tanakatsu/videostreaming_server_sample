class AddUuidIndexToVideos < ActiveRecord::Migration
  def change
    add_index :videos, :uuid, unique: true
  end
end
