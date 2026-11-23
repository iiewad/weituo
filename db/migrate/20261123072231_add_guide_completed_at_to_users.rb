class AddGuideCompletedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :guide_completed_at, :datetime
  end
end
