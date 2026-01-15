class AddTradeContextFieldsToEvaluations < ActiveRecord::Migration[8.0]
  def change
    # Required fields with defaults for existing records
    add_column :evaluations, :asset_class, :string, null: false, default: "unknown"
    add_column :evaluations, :timeframe, :string, null: false, default: "unknown"
    add_column :evaluations, :holding_intent, :string, null: false, default: "unknown"
    add_column :evaluations, :session, :string, null: false, default: "unknown"
    add_column :evaluations, :direction, :string, null: false, default: "unknown"
    add_column :evaluations, :trade_stage, :string, null: false, default: "unknown"
    add_column :evaluations, :evaluation_focus, :string, null: false, default: "general_analysis"
    
    # Optional fields
    add_column :evaluations, :position_size, :string
    add_column :evaluations, :risk_management, :string
    
    # Remove defaults after setting values for existing records
    change_column_default :evaluations, :asset_class, from: "unknown", to: nil
    change_column_default :evaluations, :timeframe, from: "unknown", to: nil
    change_column_default :evaluations, :holding_intent, from: "unknown", to: nil
    change_column_default :evaluations, :session, from: "unknown", to: nil
    change_column_default :evaluations, :direction, from: "unknown", to: nil
    change_column_default :evaluations, :trade_stage, from: "unknown", to: nil
    change_column_default :evaluations, :evaluation_focus, from: "general_analysis", to: nil
  end
end
