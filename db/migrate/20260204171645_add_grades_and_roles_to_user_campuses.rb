class AddGradesAndRolesToUserCampuses < ActiveRecord::Migration[8.1]
  def change
    add_column :user_campuses, :grade_ids, :json
    add_column :user_campuses, :role, :string, default: ""
  end
end
