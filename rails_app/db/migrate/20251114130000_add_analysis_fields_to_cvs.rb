class AddAnalysisFieldsToCvs < ActiveRecord::Migration[7.1]
  def change
    add_column :cvs, :title, :string
    add_column :cvs, :analysis_summary, :text
    add_column :cvs, :analysis_forces, :jsonb, default: [], null: false
    add_column :cvs, :analysis_weaknesses, :jsonb, default: [], null: false
    add_column :cvs, :analysis_suggestions, :jsonb, default: [], null: false
    add_column :cvs, :analyzed_at, :datetime
  end
end
