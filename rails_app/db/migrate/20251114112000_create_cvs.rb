class CreateCvs < ActiveRecord::Migration[7.1]
  def change
    create_table :cvs do |t|
      t.references :user, null: false, foreign_key: true
      t.text :body_text, null: false
      t.boolean :active, null: false, default: false
      t.string :import_method, null: false
      t.string :source_filename

      t.timestamps
    end

    add_index :cvs, [ :user_id, :active ], unique: true, where: "active"
  end
end
