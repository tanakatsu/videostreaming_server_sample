class RemoveStatusFromVideos < ActiveRecord::Migration
  def change
    remove_column :videos, :status
  end
end
