class Admin::SemesterKlassesController < AdminController
  def show
    @sk = SemesterKlass.find(params[:id])
    @klass = @sk.klass
    @sks = SemesterKlass.includes(:klass).where(
      klasses: { campuse_id: Thread.current[:campuse].id },
      semester_id: Thread.current[:semester].id,
    )
    @klasses =  Klass.where(
      id: @sks.map(&:klass_id)
    )
    @grades = Current.user.grades_by_campuse(Thread.current[:campuse].id).includes(:subjects)
  end
end
