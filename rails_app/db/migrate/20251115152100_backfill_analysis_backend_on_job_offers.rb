class BackfillAnalysisBackendOnJobOffers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    say_with_time "Backfilling analysis backend for existing job offers" do
      execute <<~SQL.squish
        UPDATE job_offers
        SET analysis_backend = 'rails'
        WHERE analysis_backend IS NULL AND summary IS NOT NULL
      SQL
    end
  end

  def down
    # no-op
  end
end
