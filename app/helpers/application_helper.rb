module ApplicationHelper
  def pressure_class(pressure)
    return "" unless pressure

    if pressure < 1000
      "text-red-600 font-semibold"
    elsif pressure < 1010
      "text-amber-600"
    else
      ""
    end
  end

  def markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener" }
    )
    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      space_after_headers: true
    )
    markdown.render(text).html_safe
  end
end
