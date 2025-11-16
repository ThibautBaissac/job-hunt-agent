class AddAnalysisBackendToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :analysis_backend, :string
  end
end
