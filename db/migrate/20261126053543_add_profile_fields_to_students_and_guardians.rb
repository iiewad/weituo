class AddProfileFieldsToStudentsAndGuardians < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :address, :string
    add_column :guardians, :occupation, :string
    # 监护人姓名改为选填，只有电话也能建档
    change_column_null :guardians, :name, true
  end
end
