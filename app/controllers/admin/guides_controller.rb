class Admin::GuidesController < AdminController
  def show
    markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(with_toc_data: false, hard_wrap: false),
      tables: true,
      autolink: true,
      fenced_code_blocks: true,
      strikethrough: true
    )
    html = markdown.render(File.read(Rails.root.join("docs/user_guide.md")))

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    fragment.at_css("h1")&.remove

    @toc = fragment.css("h2").each_with_index.map do |heading, index|
      id = "guide-section-#{index + 1}"
      heading["id"] = id
      [ heading.text, id ]
    end
    @guide_html = fragment.to_html.html_safe
  end
end
