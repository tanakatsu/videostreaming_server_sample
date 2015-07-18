class AddContentTypeToVideos < ActiveRecord::Migration
  def change
    add_column :videos, :content_type, :string
  end
end
