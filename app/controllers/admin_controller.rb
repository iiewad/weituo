class AdminController < ApplicationController
  before_action :set_thread_current, if: :authenticated?
  before_action :require_campuse_access, if: :authenticated?

  def index;end

  private
    def set_thread_current
      Thread.current[:campuse] = Thread.current[:school] = Thread.current[:semester] = nil

      campuse = Current.user.campuses.find_by(id: session[:current_campuse_id]) ||
                Current.user.campuses.order(:id).first
      return unless campuse

      session[:current_campuse_id] = campuse.id
      Thread.current[:campuse] = campuse
      Thread.current[:school] = campuse.school
      session[:current_school_id] = campuse.school_id

      semesters = campuse.school.semesters
      semester = semesters.find_by(id: session[:current_semester_id])
      unless semester
        semester = Semester.current(campuse.school.id) || semesters.order(:seq).last
        session[:current_semester_id] = semester&.id
      end
      Thread.current[:semester] = semester
    end

    def require_campuse_access
      return if Thread.current[:campuse]

      terminate_session
      redirect_to new_session_path, alert: "该账号尚未分配校区，请联系超级管理员"
    end
end
