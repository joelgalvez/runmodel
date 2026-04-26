module ApplicationHelper
  def status_badge_class(status)
    case status
    when "unprocessed" then "bg-gray-100 text-gray-600"
    when "pending"     then "bg-yellow-100 text-yellow-700"
    when "processed"   then "bg-green-100 text-green-700"
    when "error"       then "bg-red-100 text-red-700"
    else                    "bg-gray-100 text-gray-600"
    end
  end
end
