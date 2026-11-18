class AdminController < ApplicationController
  before_action :set_current_context, if: :authenticated?
  before_action :require_campuse_access, if: :authenticated?

  def index;end

  private
    def require_admin
      return if Current.user&.has_role_by_campuse_id(Current.campuse&.id, "admin")

      redirect_to root_path, alert: "只有超级管理员可以执行此操作"
    end

    def allowed_grade_ids
      @allowed_grade_ids ||= Current.user.grades_by_campuse(Current.campuse.id).ids
    end

    def campuse_semester_klasses
      Current.campuse.semester_klasses.where(grade_id: allowed_grade_ids)
    end

    def set_current_context
      Current.campuse = Current.school = Current.semester = nil

      campuse = Current.user.campuses.find_by(id: session[:current_campuse_id]) ||
                Current.user.campuses.order(:id).first
      return unless campuse

      session[:current_campuse_id] = campuse.id
      Current.campuse = campuse
      Current.school = campuse.school
      session[:current_school_id] = campuse.school_id

      semesters = campuse.school.semesters
      semester = semesters.find_by(id: session[:current_semester_id])
      unless semester
        semester = Semester.current(campuse.school.id) || semesters.order(:seq).last
        session[:current_semester_id] = semester&.id
      end
      Current.semester = semester
    end

    def require_campuse_access
      return if Current.campuse

      terminate_session
      redirect_to new_session_path, alert: "该账号尚未分配校区，请联系超级管理员"
    end
end
