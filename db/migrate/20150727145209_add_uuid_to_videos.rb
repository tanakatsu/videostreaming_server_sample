class AddUuidToVideos < ActiveRecord::Migration
  def change
    add_column :videos, :uuid, :string, null: false, default: ""
  end
end
