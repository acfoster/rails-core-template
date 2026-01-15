class AddStatusAndErrorMessageToEvaluations < ActiveRecord::Migration[7.0]
  def up
    unless column_exists?(:evaluations, :status)
      add_column :evaluations, :status, :string
    end
    unless column_exists?(:evaluations, :error_message)
      add_column :evaluations, :error_message, :text
    end
  end

  def down
    if column_exists?(:evaluations, :status)
      remove_column :evaluations, :status
    end
    if column_exists?(:evaluations, :error_message)
      remove_column :evaluations, :error_message
    end
  end
end
