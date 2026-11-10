class AdminController < ApplicationController
  before_action :set_thread_current, if: :authenticated?
  def index;end
  private
    def set_thread_current
      session[:current_campuse_id] ||= Current.user.campuses.first.id
      Thread.current[:campuse] = Campuse.find(session[:current_campuse_id])
      session[:current_school_id] ||= Thread.current[:campuse].school.id
      Thread.current[:school] = Thread.current[:campuse].school
      semesters = Thread.current[:school].semesters
      semester = semesters.find_by(id: session[:current_semester_id])
      unless semester
        semester = Semester.current(Thread.current[:school].id) || semesters.order(:seq).last
        session[:current_semester_id] = semester&.id
      end
      Thread.current[:semester] = semester
    end
end
