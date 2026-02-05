class Klass < ApplicationRecord
  belongs_to :campuse
  belongs_to :semester
  belongs_to :grade
  belongs_to :subject
  belongs_to :teacher

  GENRE_MAP = {
    "提高班" => "TG",
    "精英班" => "JY",
    "创新班" => "XZ",
    "兴趣班" => "XQ",
    "超常班" => "CC"
  }

  GENRE_MAP_REVERSE = GENRE_MAP.invert

  def name
    "#{grade.level}#{subject.name[0]}#{GENRE_MAP_REVERSE[genre][0]}#{seq}"
  end

  def students_text
    ""
  end
end
