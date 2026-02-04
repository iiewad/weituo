class AdminController < ApplicationController
  before_action :set_thread_current, if: :authenticated?
  private
    def set_thread_current
      session[:current_campuse_id] ||= Current.user.campuses.first.id
      Thread.current[:campuse] = Current.user.campuses.find(session[:current_campuse_id])
      session[:current_semester_id] ||= Thread.current[:campuse].school.semesters.current.id
      Thread.current[:semester] = Thread.current[:campuse].school.semesters.find(session[:current_semester_id])
    end
end
