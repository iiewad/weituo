class CreateStudentReferrals < ActiveRecord::Migration[8.1]
  def change
    create_table :student_referrals do |t|
      t.references :referrer, null: false, foreign_key: { to_table: :students }
      t.references :referred, null: false, foreign_key: { to_table: :students }, index: { unique: true }
      t.timestamps
    end
  end
end
