class AdminController < ApplicationController
  before_action :set_current_context, if: :authenticated?
  before_action :require_campuse_access, if: :authenticated?

  def index;end

  private
    def require_admin
      return if bootstrap_mode?
      return if Current.user&.has_role_by_campuse_id(Current.campuse&.id, "admin")

      redirect_to root_path, alert: "只有超级管理员可以执行此操作"
    end

    def allowed_grade_ids
      @allowed_grade_ids ||= Current.user.grades_by_campuse(Current.campuse.id).ids
    end

    # 当前校区、当前学期、授权年级内的班级；与页面展示范围保持一致，避免跨学期改数据
    def campuse_semester_klasses
      scope = Current.campuse.semester_klasses.where(grade_id: allowed_grade_ids)
      scope = scope.where(semester_id: Current.semester.id) if Current.semester
      scope
    end

    # 切换学期 / 校区后回到班级详情等带 id 的页面会跨上下文 RecordNotFound，这类页面改回班级列表
    def redirect_after_context_switch(notice)
      if class_scoped_referer?
        redirect_to admin_semester_klasses_path, notice: notice
      else
        redirect_back fallback_location: root_path, notice: notice
      end
    end

    # referer 指向某个具体班级（show / edit / 导出，或嵌套的课次·考勤页）时为 true；
    # 班级列表、statement 等不带 id 的集合页为 false——它们切换后能在新上下文正常渲染，回退原页即可。
    # 用路由识别而非字面路径，路由改名时不会静默失效。
    def class_scoped_referer?
      path = begin
        URI.parse(request.referer.to_s).path
      rescue URI::InvalidURIError
        ""
      end
      return false if path.blank?

      params = Rails.application.routes.recognize_path(path)
      params[:semester_klass_id].present? ||
        (params[:controller] == "admin/semester_klasses" && params[:id].present?)
    rescue ActionController::RoutingError
      false
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

      unless bootstrap_mode?
        terminate_session
        redirect_to new_session_path, alert: "该账号尚未分配校区，请联系超级管理员"
        return
      end

      # 引导模式：只放行学校管理，其余页面一律引导去创建校区
      return if controller_path == "admin/schools"

      redirect_to admin_schools_path, alert: "系统尚未配置校区，请先在学校管理中创建校区"
    end
end
