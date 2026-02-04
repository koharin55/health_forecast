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
end
