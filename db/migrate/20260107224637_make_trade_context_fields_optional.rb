class MakeTradeContextFieldsOptional < ActiveRecord::Migration[8.0]
  def change
    # Make complex trade context fields optional to support simplified form
    change_column_null :evaluations, :asset_class, true
    change_column_null :evaluations, :timeframe, true
    change_column_null :evaluations, :holding_intent, true
    change_column_null :evaluations, :session, true
    change_column_null :evaluations, :direction, true
    change_column_null :evaluations, :trade_stage, true
    change_column_null :evaluations, :evaluation_focus, true
    change_column_null :evaluations, :exchange, true
    change_column_null :evaluations, :position_size, true
    change_column_null :evaluations, :risk_management, true
  end
end
