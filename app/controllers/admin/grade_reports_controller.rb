class Admin::GradeReportsController < AdminController
  def index
    @report = grade_report
    @rows = @report.rows
    @groups = @report.semester_groups
    @summary = @report.summary
    @semesters = Semester.where(school_id: Current.school.id).order(seq: :desc)
  end

  def export
    report = grade_report

    send_data GradeReportSheet.new(
      rows: report.rows,
      summary: report.summary,
      campuse: Current.campuse,
      filter_summary:
    ).to_xlsx,
      filename: "年级报表-#{Current.campuse.name}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  private
    def grade_report
      GradeReport.new(campuse: Current.campuse, grade_ids: allowed_grade_ids,
        semester_id: params[:semester_id].presence)
    end

    def filter_summary
      semester = Current.school.semesters.find_by(id: params[:semester_id])
      semester ? "学期：#{semester.name}" : "全部学期"
    end
end
