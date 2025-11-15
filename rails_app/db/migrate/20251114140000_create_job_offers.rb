class CreateJobOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :job_offers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source, null: false, default: "other"
      t.string :source_url
      t.string :title, null: false
      t.string :company_name, null: false
      t.string :location
      t.string :contract_type
      t.string :seniority_level
      t.text :raw_description, null: false
      t.text :summary
      t.jsonb :tech_stack, null: false, default: []
      t.datetime :analyzed_at

      t.timestamps
    end

    add_index :job_offers, :source
    add_index :job_offers, :created_at
  end
end
