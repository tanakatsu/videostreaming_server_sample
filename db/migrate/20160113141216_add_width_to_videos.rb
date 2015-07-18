class AddWidthToVideos < ActiveRecord::Migration
  def change
    add_column :videos, :width, :integer
    add_column :videos, :height, :integer
    add_column :videos, :duration, :integer
  end
end
