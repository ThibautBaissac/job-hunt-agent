class AddKeywordsToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :keywords, :jsonb, null: false, default: []
  end
end
