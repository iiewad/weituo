class Teacher < ApplicationRecord
  belongs_to :subject
  belongs_to :campuse

  def name_with_subject
    "#{subject.name} #{name}"
  end
end
