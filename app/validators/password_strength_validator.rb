class PasswordStrengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    if value.length >= 16
      return
    end

    if value.length >= 12 && meets_complexity?(value)
      return
    end

    record.errors.add(attribute, "must be at least 16 characters, or at least 12 characters with a mix of upper, lower, number, and symbol")
  end

  private

  def meets_complexity?(value)
    categories = 0
    categories += 1 if value.match?(/[a-z]/)
    categories += 1 if value.match?(/[A-Z]/)
    categories += 1 if value.match?(/\d/)
    categories += 1 if value.match?(/[^A-Za-z0-9]/)
    categories >= 3
  end
end
