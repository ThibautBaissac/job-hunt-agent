class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.string :full_name
      t.string :title
      t.string :city
      t.string :github_url
      t.string :linkedin_url
      t.text :default_signature
      t.string :language, null: false, default: "fr"
      t.string :ai_tone, null: false, default: "neutral"
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
