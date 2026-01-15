class AddExpandedInputsToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_column :evaluations, :symbol, :string
    add_column :evaluations, :asset_type, :string
    add_column :evaluations, :exchange, :string
    add_column :evaluations, :chart_datetime, :datetime
    add_column :evaluations, :timezone, :string
    add_column :evaluations, :higher_timeframe_bias, :string
    add_column :evaluations, :focus_areas, :text
    add_column :evaluations, :extra_context, :text
    add_column :evaluations, :market_verification, :jsonb
  end
end
